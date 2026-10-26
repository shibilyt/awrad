defmodule Awrad.Goals.PausedRange do
  @moduledoc "Days the goal is suspended, inclusive. `to` is `nil` while still paused."

  @enforce_keys [:from, :to]
  defstruct @enforce_keys

  @type t :: %__MODULE__{from: Date.t(), to: Date.t() | nil}
end
