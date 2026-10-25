defmodule Awrad.Goals.DaysPerPeriodStanding do
  @moduledoc """
  A days-per-period goal's week or month: the due days up to the evaluated
  date that met the daily target, against the required days (capped by the
  due days the window actually has).
  """

  @enforce_keys [:status, :window, :qualifying_days, :required_days]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          status: :met | :not_met | :not_due,
          window: Date.Range.t(),
          qualifying_days: non_neg_integer(),
          required_days: non_neg_integer()
        }
end
