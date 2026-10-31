defmodule Awrad.Sync.GoalVersion do
  @moduledoc """
  The parser of one dated version of a goal document
  (`urn:awrad:goal-model:1#/$defs/version_shape`) into an
  `Awrad.Goals.Version`, by hand (`Awrad.Sync.Shape`). The goal rules a
  schema can't express are `Awrad.Goals.Timeline.validate/1`'s.
  """

  alias Awrad.Goals.ActivePeriod
  alias Awrad.Goals.CountPolicy
  alias Awrad.Goals.MakeUp
  alias Awrad.Goals.Session
  alias Awrad.Goals.Settings
  alias Awrad.Goals.Version
  alias Awrad.Sync.Shape

  @max_int 9_007_199_254_740_991

  @weekdays Map.new(
              ~w(monday tuesday wednesday thursday friday saturday sunday)a,
              &{Atom.to_string(&1), &1}
            )
  @prayers Map.new(~w(fajr dhuhr asr maghrib isha)a, &{Atom.to_string(&1), &1})
  @periods %{"week" => :week, "month" => :month, "hijri_month" => :hijri_month}
  @thresholds Map.new(
                ~w(any_count minimum target maximum daily_pace)a,
                &{Atom.to_string(&1), &1}
              )
  @completions Map.new(
                 ~w(never when_target_reached when_duration_ended)a,
                 &{Atom.to_string(&1), &1}
               )
  @windows Map.new(~w(off next_day within_3_days)a, &{Atom.to_string(&1), &1})
  @fills %{"streak" => :streak, "target" => :target}
  @plain_requirements Map.new(
                        ~w(per_due_date cumulative_total tracker)a,
                        &{Atom.to_string(&1), &1}
                      )
  @calendars %{"gregorian" => :gregorian, "hijri" => :hijri}
  # Gregorian months by their longest day (29 February falls on the 28th in
  # common years).
  @month_lengths %{
    1 => 31,
    2 => 29,
    3 => 31,
    4 => 30,
    5 => 31,
    6 => 30,
    7 => 31,
    8 => 31,
    9 => 30,
    10 => 31,
    11 => 30,
    12 => 31
  }
  @session_id ~r/\A[a-z][a-z0-9_]*\z/

  @doc "A version's parser."
  @spec parser() :: Shape.parser()
  def parser do
    Shape.object([
      {"from", Shape.date()},
      {"schedule", &schedule/2},
      {"active_period", active_period()},
      {"count_policy", count_policy()},
      {"sessions", Shape.list(session())},
      {"requirement", requirement()},
      {"completion", Shape.enum(@completions)},
      {"make_up", make_up()}
    ])
    |> Shape.map(fn version ->
      %Version{
        from: version["from"],
        settings: %Settings{
          schedule: version["schedule"],
          active_period: version["active_period"],
          count_policy: version["count_policy"],
          sessions: version["sessions"],
          requirement: version["requirement"],
          completion: version["completion"],
          make_up: version["make_up"]
        }
      }
    end)
  end

  # A yearly range's month days must exist in its calendar (the schema's
  # gregorian_month_day: no 31 April or 30 February; Hijri days go to 30).
  defp schedule(value, path) do
    case tagged_schedule().(value, path) do
      {:ok, %{"kind" => "yearly", "calendar" => calendar, "ranges" => ranges} = yearly} ->
        case missing_days(calendar, ranges, path) do
          [] -> {:ok, to_schedule(yearly)}
          errors -> {:error, errors}
        end

      {:ok, schedule} ->
        {:ok, to_schedule(schedule)}

      error ->
        error
    end
  end

  defp tagged_schedule do
    Shape.tagged("kind", %{
      "every_day" => [],
      "one_time" => [],
      "weekdays" => [{"weekdays", unique_list(Shape.enum(@weekdays))}],
      "every_n_days" => [
        {"every", Shape.integer(1, 366)},
        {"anchor_date", Shape.nullable(Shape.date())}
      ],
      "month_days" => [{"days", unique_list(Shape.integer(1, 31))}],
      "specific_dates" => [{"dates", unique_list(Shape.date())}],
      "hijri_month_days" => [{"days", unique_list(Shape.integer(1, 30))}],
      "yearly" => [
        {"calendar", Shape.enum(@calendars)},
        {"ranges", Shape.list(range(), min: 1)}
      ]
    })
  end

  defp unique_list(item), do: Shape.list(item, min: 1, unique?: true)

  defp missing_days(calendar, ranges, path) do
    for {{from, to}, i} <- Enum.with_index(ranges),
        {member, month_day} <- [{"start", from}, {"end", to}],
        not day_exists?(calendar, month_day),
        do: {Shape.pointer(path ++ ["ranges", i, member]), "invalid"}
  end

  defp day_exists?(:gregorian, {month, day}), do: day <= Map.fetch!(@month_lengths, month)
  defp day_exists?(:hijri, {_month, day}), do: day <= 30

  defp to_schedule(%{"kind" => "every_day"}), do: :every_day
  defp to_schedule(%{"kind" => "one_time"}), do: :one_time
  defp to_schedule(%{"kind" => "weekdays", "weekdays" => days}), do: {:weekdays, days}

  defp to_schedule(%{"kind" => "every_n_days", "every" => every, "anchor_date" => anchor}),
    do: {:every_n_days, every, anchor}

  defp to_schedule(%{"kind" => "month_days", "days" => days}), do: {:month_days, days}
  defp to_schedule(%{"kind" => "specific_dates", "dates" => dates}), do: {:specific_dates, dates}
  defp to_schedule(%{"kind" => "hijri_month_days", "days" => days}), do: {:hijri_month_days, days}

  defp to_schedule(%{"kind" => "yearly", "calendar" => calendar, "ranges" => ranges}),
    do: {:yearly, calendar, ranges}

  defp range do
    Shape.object([{"start", month_day()}, {"end", month_day()}])
    |> Shape.map(&{&1["start"], &1["end"]})
  end

  defp month_day do
    Shape.object([{"month", Shape.integer(1, 12)}, {"day", Shape.integer(1, 31)}])
    |> Shape.map(&{&1["month"], &1["day"]})
  end

  defp active_period do
    Shape.object([
      {"start_date", Shape.date()},
      {"end_date", Shape.nullable(Shape.date())},
      {"duration_days", Shape.nullable(Shape.integer(1, 36_600))}
    ])
    |> Shape.map(fn period ->
      %ActivePeriod{
        start_date: period["start_date"],
        end_date: period["end_date"],
        duration_days: period["duration_days"]
      }
    end)
  end

  defp count_policy do
    count = Shape.nullable(Shape.integer(0, @max_int))

    Shape.object([
      {"minimum", count},
      {"target", count},
      {"maximum", count},
      {"streak_threshold", &streak_threshold/2}
    ])
    |> Shape.map(fn policy ->
      %CountPolicy{
        minimum: policy["minimum"],
        target: policy["target"],
        maximum: policy["maximum"],
        streak_threshold: policy["streak_threshold"]
      }
    end)
  end

  # A named threshold, or `{"amount": N}`.
  defp streak_threshold(value, path) when is_map(value) do
    [{"amount", Shape.integer(1, @max_int)}]
    |> Shape.object()
    |> Shape.map(&{:amount, &1["amount"]})
    |> then(& &1.(value, path))
  end

  defp streak_threshold(value, path), do: Shape.enum(@thresholds).(value, path)

  defp session do
    common = [
      {"id", Shape.string(&Regex.match?(@session_id, &1))},
      {"target", Shape.nullable(Shape.integer(0, @max_int))}
    ]

    prayer = {"prayer", Shape.enum(@prayers)}

    Shape.tagged("kind", %{
      "anytime" => common,
      "before_prayer" => [prayer | common],
      "after_prayer" => [prayer | common],
      "at_time" => [{"time", Shape.time()} | common],
      "between" => [{"from", Shape.time()}, {"to", Shape.time()} | common]
    })
    |> Shape.map(&%Session{id: &1["id"], kind: session_kind(&1), target: &1["target"]})
  end

  defp session_kind(%{"kind" => "anytime"}), do: :anytime

  defp session_kind(%{"kind" => "before_prayer", "prayer" => prayer}),
    do: {:before_prayer, prayer}

  defp session_kind(%{"kind" => "after_prayer", "prayer" => prayer}), do: {:after_prayer, prayer}
  defp session_kind(%{"kind" => "at_time", "time" => time}), do: {:at_time, time}
  defp session_kind(%{"kind" => "between", "from" => from, "to" => to}), do: {:between, from, to}

  defp requirement do
    period = {"period", Shape.enum(@periods)}

    Shape.tagged("type", %{
      "per_due_date" => [],
      "cumulative_total" => [],
      "tracker" => [],
      "period_total" => [period],
      "days_per_period" => [period, {"days", Shape.integer(1, 31)}]
    })
    |> Shape.map(&to_requirement/1)
  end

  defp to_requirement(%{"type" => "period_total", "period" => period}),
    do: {:period_total, period}

  defp to_requirement(%{"type" => "days_per_period", "period" => period, "days" => days}),
    do: {:days_per_period, period, days}

  defp to_requirement(%{"type" => type}), do: Map.fetch!(@plain_requirements, type)

  defp make_up do
    Shape.object([{"window", Shape.enum(@windows)}, {"fill", Shape.enum(@fills)}])
    |> Shape.map(&%MakeUp{window: &1["window"], fill: &1["fill"]})
  end
end
