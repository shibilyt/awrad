defmodule Awrad.Goals.DayStatus do
  @moduledoc """
  A due day's status with make-up (README "Make-up"): its own count, what
  later days filled it with, and the status. With sessions, both numbers sum
  the sessions, and the status is the worst session's.

  - `:met`: at least its target (if it has a daily target) and its streak amount;
  - `:made_up`: filled by make-up to its fill amount;
  - `:minimum_only`: at least the streak amount, below the target;
  - `:pending`: not kept, but its make-up window is still open and the goal running;
  - `:missed`; or `:in_progress` for the evaluated day.

  Met, minimum only and made up keep the streak; in progress and pending are
  open, neither breaking nor adding to it.
  """

  @type status :: :met | :made_up | :minimum_only | :pending | :missed | :in_progress

  @enforce_keys [:date, :count, :filled, :status]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          date: Date.t(),
          count: non_neg_integer(),
          filled: non_neg_integer(),
          status: status()
        }

  @doc "Whether the status keeps the streak."
  @spec kept?(status()) :: boolean()
  def kept?(status), do: status in [:met, :minimum_only, :made_up]

  @doc "Whether the status is still open: neither breaking nor adding to the streak."
  @spec open?(status()) :: boolean()
  def open?(status), do: status in [:in_progress, :pending]
end
