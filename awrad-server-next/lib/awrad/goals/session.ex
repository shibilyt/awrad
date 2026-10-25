defmodule Awrad.Goals.Session do
  @moduledoc "A time-of-day opportunity with its own count policy. Each session must meet its own target."

  alias Awrad.Goals.CountPolicy

  @enforce_keys [:id, :count_policy]
  defstruct @enforce_keys

  @type t :: %__MODULE__{id: String.t(), count_policy: CountPolicy.t()}
end
