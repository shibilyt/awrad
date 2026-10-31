defmodule Awrad.Goals.Placement do
  @moduledoc """
  My Goals sections (decisions 12, 25, 26, 30 and 46), each in display order:

  - `today`: due today, or with a day pending make-up;
  - `upcoming`: soonest `next_due` first (`nil` last: nothing due in the next
    400 days);
  - `tracking`: trackers;
  - `paused`: paused today;
  - `history`: newest `on` first, `finished` as `:completed` or `:ended`.

  Ties follow the account's goal order, then `created_on`, then the ID.
  """

  @type id :: String.t()
  @type upcoming :: %{id: id(), next_due: Date.t() | nil}
  @type finished :: %{id: id(), finished: :completed | :ended, on: Date.t()}

  @enforce_keys [:today, :upcoming, :tracking, :paused, :history]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          today: [id()],
          upcoming: [upcoming()],
          tracking: [id()],
          paused: [id()],
          history: [finished()]
        }
end
