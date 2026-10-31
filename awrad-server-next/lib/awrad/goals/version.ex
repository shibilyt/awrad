defmodule Awrad.Goals.Version do
  @moduledoc """
  A dated version of a goal: its settings from the practice day `from`
  onwards, until the next version's `from` (decision 23). Editing never
  rewrites the past.
  """

  alias Awrad.Goals.Settings

  @enforce_keys [:from, :settings]
  defstruct @enforce_keys

  @type t :: %__MODULE__{from: Date.t(), settings: Settings.t()}
end
