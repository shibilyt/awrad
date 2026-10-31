defmodule Awrad.Goals.DailyPace do
  @moduledoc """
  Today's share of a total goal with an end (decision 28): what's left before
  the day, divided by the due days from the day to the last day, rounded up.

  - `pace`: `nil` without an end, or when the day isn't due;
  - `remaining`: the target less the counts before the day (at least 0);
    `nil` for goals that aren't cumulative totals, or have sessions;
  - `due_days_left`: from the day to the last day; `nil` without an end.
  """

  @enforce_keys [:pace, :remaining, :due_days_left]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          pace: non_neg_integer() | nil,
          remaining: non_neg_integer() | nil,
          due_days_left: non_neg_integer() | nil
        }
end
