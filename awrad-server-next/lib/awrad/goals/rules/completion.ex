defmodule Awrad.Goals.Rules.Completion do
  @moduledoc false
  # Rule: derived completion (fixtures/goal_completion.json). Never a stored
  # flag: a goal whose counts drop back below the target isn't completed.

  alias Awrad.Goals.Goal
  alias Awrad.Goals.Rules.Counts
  alias Awrad.Goals.Rules.Periods
  alias Awrad.Goals.Rules.Requirement

  @spec completed?(Goal.t(), Counts.index(), Date.t()) :: boolean()
  def completed?(%Goal{completion: :never}, _index, _date), do: false

  def completed?(%Goal{completion: :when_duration_ended, active_period: period}, _index, date) do
    case Periods.last_day(period) do
      nil -> false
      last -> Date.after?(date, last)
    end
  end

  # Only a cumulative goal has a final target: its total over the active
  # period, up to and including `date`.
  def completed?(
        %Goal{completion: :when_target_reached, requirement: :cumulative_total} = goal,
        index,
        date
      ) do
    start = goal.active_period.start_date

    not Date.before?(date, start) and
      Requirement.window_met?(goal, index, Date.range(start, date, 1), date)
  end

  def completed?(%Goal{completion: :when_target_reached}, _index, _date), do: false
end
