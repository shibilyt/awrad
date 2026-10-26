defmodule Awrad.Hijri.HijriDate do
  @moduledoc """
  The Hijri date of an effective practice day (`CONTEXT.md`, Hijri date), with
  the length of its month (29 or 30 days), after the account's corrections.
  """

  @enforce_keys [:year, :month, :day, :month_length]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          year: 1400..1500,
          month: 1..12,
          day: 1..30,
          month_length: 29..30
        }
end
