defmodule Awrad.Goals.Standing do
  @moduledoc """
  Where a goal stands for a window: its status, the window, the progress up to
  and including the evaluated date, and the target.

  `target` is `nil` for trackers and for goals with sessions; then each
  session reports its own progress, target and status in `sessions`.
  """

  alias Awrad.Goals.SessionStanding

  @type status :: :met | :not_met | :not_due

  @enforce_keys [:status, :window, :progress, :target, :sessions]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          status: status(),
          window: Date.Range.t(),
          progress: non_neg_integer(),
          target: non_neg_integer() | nil,
          sessions: [SessionStanding.t()]
        }
end
