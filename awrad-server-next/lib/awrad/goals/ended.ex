defmodule Awrad.Goals.Ended do
  @moduledoc """
  When and why a goal finished. `on` is its last day, inclusive.

  Reasons: `:user` (End goal), `:completed` (a total reached), `:date` (its
  active period ran out, or no scheduled day is left), `:structural_edit` and
  `:dhikr_deleted`. A finished goal is never reactivated.
  """

  @type reason :: :user | :completed | :date | :structural_edit | :dhikr_deleted

  @enforce_keys [:on, :reason]
  defstruct @enforce_keys

  @type t :: %__MODULE__{on: Date.t(), reason: reason()}
end
