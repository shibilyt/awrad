defmodule Awrad.Goals.CountPolicy do
  @moduledoc """
  The numbers a goal or session works against: an optional minimum, the
  target, an optional maximum, and which of them the streak uses (the streak
  threshold). A threshold whose value is `nil` can never be met.
  """

  @type streak_threshold :: :any_count | :minimum | :target | :maximum

  @enforce_keys [:minimum, :target, :maximum, :streak_threshold]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          minimum: non_neg_integer() | nil,
          target: non_neg_integer() | nil,
          maximum: non_neg_integer() | nil,
          streak_threshold: streak_threshold()
        }
end
