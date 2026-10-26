defmodule Awrad.Goals.CountEntry do
  @moduledoc """
  A day's count for the goal (`session: nil`) or for one session, already
  bucketed by effective practice day.
  """

  @enforce_keys [:date, :session, :count]
  defstruct @enforce_keys

  @type t :: %__MODULE__{date: Date.t(), session: String.t() | nil, count: non_neg_integer()}
end
