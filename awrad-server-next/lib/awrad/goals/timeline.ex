defmodule Awrad.Goals.Timeline do
  @moduledoc """
  Everything about a goal's days (`goal_timeline` in the schema): every dated
  version, oldest first, plus its pauses, excused days and how it ended. It's
  the goal document without its dhikr, name and shared or dedicated counts.

  Rules that look across days take a timeline or a single `Awrad.Goals.Goal`,
  and judge each day by the version in force that day (README "Dated
  versions"). A goal stands for a timeline with one version from its start
  date that has never ended.

  Build timelines with `new/1`, which rejects invalid ones (`goal_validity`
  documents).
  """

  alias Awrad.Goals.Ended
  alias Awrad.Goals.Goal
  alias Awrad.Goals.PausedRange
  alias Awrad.Goals.Rules.Validity
  alias Awrad.Goals.Version

  @enforce_keys [:created_on, :versions, :paused, :excused, :ended]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          created_on: Date.t(),
          versions: [Version.t(), ...],
          paused: [PausedRange.t()],
          excused: [Date.t()],
          ended: Ended.t() | nil
        }

  @typedoc """
  Why a timeline is invalid: any version's `t:Awrad.Goals.Goal.error/0`
  (with the timeline's pauses and excused days), or:

  - `:structural_change`: versions disagree on the schedule kind (or a yearly
    schedule's calendar), the requirement type (or its period), or the start
    date;
  - `:versions_out_of_order`: version `from` days not strictly increasing;
  - `:first_version_not_created_on`: the first version doesn't start on
    `created_on`.
  """
  @type error ::
          Goal.error()
          | :structural_change
          | :versions_out_of_order
          | :first_version_not_created_on

  @doc """
  Builds a valid timeline from all of its fields, or returns every reason
  it's invalid, sorted alphabetically. A missing or unknown field, or no
  versions, raises.
  """
  @spec new(Goal.attrs()) :: {:ok, t()} | {:error, [error(), ...]}
  def new(attrs) do
    case validate(attrs) do
      {:ok, timeline} ->
        {:ok, timeline}

      {:error, problems} ->
        {:error, problems |> Enum.map(&elem(&1, 0)) |> Enum.uniq() |> Enum.sort()}
    end
  end

  @typedoc "Where a problem is: a path into the goal document, in its member names and indexes."
  @type path :: [String.t() | non_neg_integer()]

  @doc """
  Like `new/1`, but an invalid timeline's errors say where each problem is
  (`{:session_id_mismatch, ["versions", 0, "sessions", 1, "id"]}`), for the
  change queue's field errors. In the order found, one per place.
  """
  @spec validate(Goal.attrs()) :: {:ok, t()} | {:error, [{error(), path()}, ...]}
  def validate(attrs) do
    case struct!(__MODULE__, attrs) do
      %__MODULE__{versions: [_ | _]} = timeline ->
        case Validity.timeline_problems(timeline) do
          [] -> {:ok, timeline}
          problems -> {:error, problems}
        end

      %__MODULE__{} ->
        raise ArgumentError, "a timeline needs at least one version"
    end
  end

  @doc "A single goal as a timeline: one version from its start date, never ended."
  @spec from_goal(Goal.t()) :: t()
  def from_goal(%Goal{active_period: %{start_date: start}} = goal) do
    %__MODULE__{
      created_on: start,
      versions: [%Version{from: start, settings: Goal.settings(goal)}],
      paused: goal.paused,
      excused: goal.excused,
      ended: nil
    }
  end
end
