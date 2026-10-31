defmodule Awrad.Goals.Consistency do
  @moduledoc """
  The consistency tag (decisions 19, 21 and 32), and what a goal row shows.

  - `basis`: `:due_days` (units day, weekday, occasion: the last 30 settled
    due days) or `:periods` (weeks or months: the last 12 settled periods).
  - `met` of `out_of`: kept days, or met periods.
  - `tag`: `:devoted` (90% or more) or `:steady` (80% or more), never before
    7 due days or 4 periods.
  - `show`: `:streak` from 3, else `:consistency` with a tag, else `:streak`
    for 1 or 2, else `:none`.
  """

  @enforce_keys [:basis, :met, :out_of, :tag, :show]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          basis: :due_days | :periods,
          met: non_neg_integer(),
          out_of: non_neg_integer(),
          tag: :devoted | :steady | nil,
          show: :streak | :consistency | :none
        }
end
