defmodule Awrad.Fixtures.GoalModel.Encode do
  @moduledoc """
  Maps `Awrad.Goals` results back to the goal-model fixtures' `expect`
  shapes (the inverse of `Awrad.Fixtures.GoalModel`).
  """

  alias Awrad.Goals.ActivePeriod
  alias Awrad.Goals.Consistency
  alias Awrad.Goals.CountEntry
  alias Awrad.Goals.CountPolicy
  alias Awrad.Goals.DailyPace
  alias Awrad.Goals.DaysPerPeriodStanding
  alias Awrad.Goals.DayStatus
  alias Awrad.Goals.Goal
  alias Awrad.Goals.Placement
  alias Awrad.Goals.Ring
  alias Awrad.Goals.Session
  alias Awrad.Goals.SessionStanding
  alias Awrad.Goals.Settings
  alias Awrad.Goals.Standing
  alias Awrad.Goals.Streak
  alias Awrad.Goals.Version

  @spec result(struct()) :: map()
  def result(%Standing{} = standing) do
    %{
      "status" => name(standing.status),
      "window" => window(standing.window),
      "progress" => standing.progress,
      "target" => standing.target,
      "sessions" => Enum.map(standing.sessions, &session_standing/1)
    }
  end

  def result(%DaysPerPeriodStanding{} = standing) do
    %{
      "status" => name(standing.status),
      "window" => window(standing.window),
      "qualifying_days" => standing.qualifying_days,
      "required_days" => standing.required_days
    }
  end

  def result(%Streak{} = streak) do
    %{
      "current" => streak.current,
      "unit" => name(streak.unit),
      "weekday" => name(streak.weekday),
      "pending_make_up" => Enum.map(streak.pending_make_up, &Date.to_iso8601/1)
    }
  end

  def result(%Consistency{} = consistency) do
    %{
      "basis" => name(consistency.basis),
      "met" => consistency.met,
      "out_of" => consistency.out_of,
      "tag" => name(consistency.tag),
      "show" => name(consistency.show)
    }
  end

  def result(%DailyPace{} = pace),
    do: %{
      "pace" => pace.pace,
      "remaining" => pace.remaining,
      "due_days_left" => pace.due_days_left
    }

  def result(%Ring{} = ring),
    do: %{"ring" => name(ring.ring), "progress" => ring.progress, "goal" => ring.goal}

  def result(%Placement{} = placement) do
    %{
      "today" => placement.today,
      "upcoming" =>
        Enum.map(placement.upcoming, &%{"id" => &1.id, "next_due" => optional_date(&1.next_due)}),
      "tracking" => placement.tracking,
      "paused" => placement.paused,
      "history" =>
        Enum.map(
          placement.history,
          &%{"id" => &1.id, "finished" => name(&1.finished), "on" => Date.to_iso8601(&1.on)}
        )
    }
  end

  @doc "`Goal.new/1` or `Timeline.new/1` results as the `goal_validity` expect shape."
  @spec validity({:ok, term()} | {:error, [atom()]}) :: map()
  def validity({:ok, _valid}), do: %{"valid" => true, "errors" => []}

  def validity({:error, errors}),
    do: %{"valid" => false, "errors" => Enum.map(errors, &Atom.to_string/1)}

  @spec day_status(DayStatus.t()) :: map()
  def day_status(%DayStatus{} = day) do
    %{
      "date" => Date.to_iso8601(day.date),
      "count" => day.count,
      "filled" => day.filled,
      "status" => name(day.status)
    }
  end

  @spec count_entry(CountEntry.t()) :: map()
  def count_entry(%CountEntry{} = entry),
    do: %{
      "date" => Date.to_iso8601(entry.date),
      "session" => entry.session,
      "count" => entry.count
    }

  @spec goal(Goal.t()) :: map()
  def goal(%Goal{} = goal) do
    goal
    |> Goal.settings()
    |> settings()
    |> Map.merge(%{
      "paused" =>
        Enum.map(
          goal.paused,
          &%{"from" => Date.to_iso8601(&1.from), "to" => optional_date(&1.to)}
        ),
      "excused" => Enum.map(goal.excused, &Date.to_iso8601/1)
    })
  end

  @spec version(Version.t()) :: map()
  def version(%Version{from: from, settings: settings}),
    do: Map.put(settings(settings), "from", Date.to_iso8601(from))

  defp settings(%Settings{} = settings) do
    %{
      "schedule" => schedule(settings.schedule),
      "active_period" => active_period(settings.active_period),
      "count_policy" => count_policy(settings.count_policy),
      "sessions" => Enum.map(settings.sessions, &session/1),
      "requirement" => requirement(settings.requirement),
      "completion" => name(settings.completion),
      "make_up" => %{
        "window" => name(settings.make_up.window),
        "fill" => name(settings.make_up.fill)
      }
    }
  end

  defp schedule(kind) when kind in [:every_day, :one_time], do: %{"kind" => name(kind)}

  defp schedule({:weekdays, days}),
    do: %{"kind" => "weekdays", "weekdays" => Enum.map(days, &name/1)}

  defp schedule({:every_n_days, every, anchor}),
    do: %{"kind" => "every_n_days", "every" => every, "anchor_date" => optional_date(anchor)}

  defp schedule({:specific_dates, dates}),
    do: %{"kind" => "specific_dates", "dates" => Enum.map(dates, &Date.to_iso8601/1)}

  defp schedule({:yearly, calendar, ranges}) do
    %{
      "kind" => "yearly",
      "calendar" => name(calendar),
      "ranges" =>
        Enum.map(ranges, fn {from, to} ->
          %{"start" => month_day(from), "end" => month_day(to)}
        end)
    }
  end

  defp schedule({kind, days}) when kind in [:month_days, :hijri_month_days],
    do: %{"kind" => name(kind), "days" => days}

  defp month_day({month, day}), do: %{"month" => month, "day" => day}

  defp active_period(%ActivePeriod{} = period) do
    %{
      "start_date" => Date.to_iso8601(period.start_date),
      "end_date" => optional_date(period.end_date),
      "duration_days" => period.duration_days
    }
  end

  defp count_policy(%CountPolicy{} = policy) do
    %{
      "minimum" => policy.minimum,
      "target" => policy.target,
      "maximum" => policy.maximum,
      "streak_threshold" => streak_threshold(policy.streak_threshold)
    }
  end

  defp streak_threshold({:amount, amount}), do: %{"amount" => amount}
  defp streak_threshold(threshold), do: name(threshold)

  defp session(%Session{id: id, kind: kind, target: target}),
    do: Map.merge(%{"id" => id, "target" => target}, session_kind(kind))

  defp session_kind(:anytime), do: %{"kind" => "anytime"}

  defp session_kind({kind, prayer}) when kind in [:before_prayer, :after_prayer],
    do: %{"kind" => name(kind), "prayer" => name(prayer)}

  defp session_kind({:at_time, time}), do: %{"kind" => "at_time", "time" => hh_mm(time)}

  defp session_kind({:between, from, to}),
    do: %{"kind" => "between", "from" => hh_mm(from), "to" => hh_mm(to)}

  defp hh_mm(time), do: Calendar.strftime(time, "%H:%M")

  defp requirement({:period_total, period}),
    do: %{"type" => "period_total", "period" => name(period)}

  defp requirement({:days_per_period, period, days}),
    do: %{"type" => "days_per_period", "period" => name(period), "days" => days}

  defp requirement(type), do: %{"type" => name(type)}

  defp session_standing(%SessionStanding{} = session) do
    %{
      "id" => session.id,
      "progress" => session.progress,
      "target" => session.target,
      "status" => name(session.status)
    }
  end

  defp window(%Date.Range{first: first, last: last}),
    do: %{"from" => Date.to_iso8601(first), "to" => Date.to_iso8601(last)}

  defp optional_date(nil), do: nil
  defp optional_date(date), do: Date.to_iso8601(date)

  # Every enum in the schema is its atom's name.
  defp name(nil), do: nil
  defp name(atom) when is_atom(atom), do: Atom.to_string(atom)
end
