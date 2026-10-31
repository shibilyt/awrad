defmodule Awrad.Sync.GoalDocument do
  @moduledoc """
  Checks the slice 4 documents by hand (`contracts/sync/v1/README.md`, rule 3):

    * `goal` (`urn:awrad:goal-model:1#/$defs/goal_document`): its schema
      (`Awrad.Sync.Shape`, `Awrad.Sync.GoalVersion`), then, once it has the
      schema's shape, the goal rules (`Awrad.Goals.Timeline.validate/1`) as
      the README's field errors ("Goal rules as field errors"):

      | Goal rule | Field | Code |
      |---|---|---|
      | `target_required` | `/versions/N/count_policy/target` | `required` |
      | `session_target_required` | `/versions/N/sessions/M/target` | `required` |
      | `streak_threshold_value_required`, `streak_pace_not_allowed` | `/versions/N/count_policy/streak_threshold` | `invalid` |
      | `end_date_and_duration` | `/versions/N/active_period/duration_days` | `not_allowed` |
      | `make_up_not_allowed` | `/versions/N/make_up/window` | `not_allowed` |
      | `sessions_with_minimum_or_cap` | `/versions/N/count_policy/minimum`, `…/maximum` | `not_allowed` |
      | `session_id_mismatch` | `/versions/N/sessions/M/id` | `mismatch` |
      | `session_duplicate` | `/versions/N/sessions/M/id`, each later one | `duplicate` |
      | `session_window_empty` | `/versions/N/sessions/M/to` | `range` |
      | `structural_change` | `/versions/N`, each differing from the first | `mismatch` |
      | `versions_out_of_order` | `/versions/N/from` | `range` |
      | `first_version_not_created_on` | `/versions/0/from` | `mismatch` |

    * `goal_order` (`$defs/goal_order_document`): `{goal_ids}`, at most 2,000
      UUIDs without repeats (`duplicate` on `/goal_ids`).

  Fields are JSON Pointers into the document (a receipt puts `/document` in
  front), sorted by field, then code.
  """

  alias Awrad.Goals.Ended
  alias Awrad.Goals.PausedRange
  alias Awrad.Goals.Timeline
  alias Awrad.Sync.GoalVersion
  alias Awrad.Sync.Shape

  @max_goal_ids 2_000

  @rule_codes %{
    target_required: "required",
    session_target_required: "required",
    streak_threshold_value_required: "invalid",
    streak_pace_not_allowed: "invalid",
    end_date_and_duration: "not_allowed",
    make_up_not_allowed: "not_allowed",
    sessions_with_minimum_or_cap: "not_allowed",
    session_id_mismatch: "mismatch",
    session_duplicate: "duplicate",
    session_window_empty: "range",
    structural_change: "mismatch",
    versions_out_of_order: "range",
    first_version_not_created_on: "mismatch"
  }
  @reasons Map.new(
             ~w(user completed date structural_edit dhikr_deleted)a,
             &{Atom.to_string(&1), &1}
           )
  @kinds Map.new(~w(quran dhikr dua salawat name_of_allah), &{&1, &1})

  @type error :: %{required(String.t()) => String.t()}

  @doc "The goal document's errors, sorted; `[]` when it's valid."
  @spec goal_errors(map()) :: [error()]
  def goal_errors(document) do
    case timeline(document) do
      {:ok, _timeline} -> []
      {:error, errors} -> errors
    end
  end

  @doc "A valid goal document's timeline, or its errors."
  @spec timeline(map()) :: {:ok, Timeline.t()} | {:error, [error(), ...]}
  def timeline(document) do
    with {:ok, parsed} <- Shape.run(document_parser(), document) do
      attrs = Map.take(parsed, [:created_on, :versions, :paused, :excused, :ended])

      case Timeline.validate(attrs) do
        {:ok, timeline} ->
          {:ok, timeline}

        {:error, problems} ->
          {:error,
           problems
           |> Enum.map(&rule_error/1)
           |> Enum.uniq()
           |> Enum.sort_by(&{&1["field"], &1["code"]})}
      end
    end
  end

  defp rule_error({code, path}),
    do: %{"field" => Shape.pointer(path), "code" => Map.fetch!(@rule_codes, code)}

  defp document_parser do
    label = Shape.text(120)

    Shape.object([
      {"dhikr_id", Shape.uuid()},
      {"dhikr_snapshot", snapshot()},
      {"name", Shape.nullable(label)},
      {"counts", Shape.enum(%{"shared" => :shared, "dedicated" => :dedicated})},
      {"created_on", Shape.date()},
      {"versions", Shape.list(GoalVersion.parser(), min: 1, max: 100)},
      {"paused", Shape.list(paused(), max: 500)},
      {"excused", Shape.list(Shape.date(), max: 1_000, unique?: true)},
      {"ended", Shape.nullable(ended())}
    ])
    |> Shape.map(fn document ->
      %{
        created_on: document["created_on"],
        versions: document["versions"],
        paused: document["paused"],
        excused: document["excused"],
        ended: document["ended"]
      }
    end)
  end

  # Every title language present, `null` when empty, and at least one text.
  defp snapshot do
    title = Shape.nullable(Shape.text(120))
    titles = Shape.object([{"en", title}, {"ar", title}, {"ml", title}])

    Shape.object([
      {"title", &snapshot_title(titles, &1, &2)},
      {"arabic", Shape.text(5_000)},
      {"kind", Shape.enum(@kinds)}
    ])
  end

  defp snapshot_title(parser, value, path) do
    case parser.(value, path) do
      {:ok, title} ->
        if Enum.any?(Map.values(title), &is_binary/1),
          do: {:ok, title},
          else: {:error, [{Shape.pointer(path), "required"}]}

      error ->
        error
    end
  end

  defp paused do
    Shape.object([{"from", Shape.date()}, {"to", Shape.nullable(Shape.date())}])
    |> Shape.map(&%PausedRange{from: &1["from"], to: &1["to"]})
  end

  defp ended do
    Shape.object([{"on", Shape.date()}, {"reason", Shape.enum(@reasons)}])
    |> Shape.map(&%Ended{on: &1["on"], reason: &1["reason"]})
  end

  @doc "The goal order document's errors, sorted; `[]` when it's valid."
  @spec goal_order_errors(map()) :: [error()]
  def goal_order_errors(document) do
    parser =
      Shape.object([
        {"goal_ids", Shape.list(Shape.uuid(), max: @max_goal_ids, unique?: true)}
      ])

    case Shape.run(parser, document) do
      {:ok, _order} -> []
      {:error, errors} -> errors
    end
  end
end
