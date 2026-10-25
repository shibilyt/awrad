defmodule Awrad.Goals.ActivePeriod do
  @moduledoc """
  The span during which a goal can be due: from `start_date` until `end_date`
  or the last day of its duration (start + N − 1), whichever comes first. Both
  ends are inclusive; `nil` for both means open-ended.
  """

  @enforce_keys [:start_date, :end_date, :duration_days]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          start_date: Date.t(),
          end_date: Date.t() | nil,
          duration_days: pos_integer() | nil
        }
end
