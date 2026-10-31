defmodule Awrad.Goals.Ring do
  @moduledoc """
  What a My Goals ring fills toward today (decision 33):

  - `:target`: daily goals and N days a period, today's target (with
    sessions, their targets combined, each counting up to its own);
  - `:period_target`: period totals, the week or month so far;
  - `:pace`: totals streaking at `:daily_pace`, today's pace (at least 1);
  - `:streak_amount`: other totals, and trackers until their number is reached;
  - `:none`: not due today, or a tracker with any count or its number reached.
    `progress` is still today's count and `goal` is `nil`.
  """

  @enforce_keys [:ring, :progress, :goal]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          ring: :target | :period_target | :pace | :streak_amount | :none,
          progress: non_neg_integer(),
          goal: non_neg_integer() | nil
        }
end
