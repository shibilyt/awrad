defmodule Awrad.Goals.SessionStanding do
  @moduledoc "One session's progress against its own target, within a standing's window."

  @enforce_keys [:id, :progress, :target, :status]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          id: String.t(),
          progress: non_neg_integer(),
          target: non_neg_integer() | nil,
          status: :met | :not_met
        }
end
