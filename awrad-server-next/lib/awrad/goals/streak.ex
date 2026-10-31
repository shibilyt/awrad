defmodule Awrad.Goals.Streak do
  @moduledoc """
  A goal's current streak and its unit, from the version in force on the
  evaluated day (README "Streak units"):

  - `:week` or `:month`: period totals and days per period;
  - `:occasion`: yearly schedules;
  - `:weekday` (with `weekday`): a weekdays schedule of exactly one day;
  - `:day`: anything else.

  `pending_make_up` lists the missed due days whose make-up window is still
  open, oldest first ("🔥 15 · make up Mon").
  """

  alias Awrad.Goals.Goal

  @type unit :: :day | :weekday | :week | :month | :occasion

  @enforce_keys [:current, :unit, :weekday, :pending_make_up]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          current: non_neg_integer(),
          unit: unit(),
          weekday: Goal.weekday() | nil,
          pending_make_up: [Date.t()]
        }
end
