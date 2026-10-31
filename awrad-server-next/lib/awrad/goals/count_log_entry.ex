defmodule Awrad.Goals.CountLogEntry do
  @moduledoc """
  One entry of a profile's append-only count log (root ADR-2026-10-31: counts
  belong to the dhikr). `goal_id` is set only for a count made in a dedicated
  goal. `amount` is never 0, and negative for an adjustment or an undo.

  `Awrad.Goals.Rules.attribute_counts/2` turns the log into each goal's
  `Awrad.Goals.CountEntry` list.
  """

  @enforce_keys [:id, :dhikr_id, :practice_day, :session_id, :goal_id, :amount, :counted_at]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          id: String.t(),
          dhikr_id: String.t(),
          practice_day: Date.t(),
          session_id: String.t() | nil,
          goal_id: String.t() | nil,
          amount: integer(),
          counted_at: DateTime.t()
        }
end
