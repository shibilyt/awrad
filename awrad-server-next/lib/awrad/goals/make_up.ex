defmodule Awrad.Goals.MakeUp do
  @moduledoc """
  Make-up (qada, decisions 18, 31 and 48): counts past a later day's own needs
  fill a missed due day inside its window, up to the fill amount.

  - `window`: `:off`, `:next_day` or `:within_3_days`, in practice days.
  - `fill`: `:streak` fills to the streak amount; `:target` to the target, or
    the streak amount if higher. Kept when the window is off.

  Only per-due-date goals, and totals whose streak counts at `{:amount, n}`
  (filled to n, so `fill: :streak`), may have a window other than off.
  """

  @type window :: :off | :next_day | :within_3_days
  @type fill :: :streak | :target

  @enforce_keys [:window, :fill]
  defstruct @enforce_keys

  @type t :: %__MODULE__{window: window(), fill: fill()}

  @doc "How many practice days after a missed day can make it up."
  @spec window_days(t()) :: 0 | 1 | 3
  def window_days(%__MODULE__{window: :off}), do: 0
  def window_days(%__MODULE__{window: :next_day}), do: 1
  def window_days(%__MODULE__{window: :within_3_days}), do: 3
end
