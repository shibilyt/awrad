defmodule Awrad.Goals.CountPolicy do
  @moduledoc """
  The numbers a goal or session works against: an optional minimum, the
  target, an optional maximum, and which of them the streak uses (the streak
  threshold). A valid goal's streak threshold always points at a value that is
  set (`Awrad.Goals.Goal.new/1`).
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

  @doc "Whether the streak threshold is any count, or points at a value that is set."
  @spec streak_threshold_set?(t()) :: boolean()
  def streak_threshold_set?(%__MODULE__{streak_threshold: :any_count}), do: true

  def streak_threshold_set?(%__MODULE__{streak_threshold: :minimum, minimum: value}),
    do: value != nil

  def streak_threshold_set?(%__MODULE__{streak_threshold: :target, target: value}),
    do: value != nil

  def streak_threshold_set?(%__MODULE__{streak_threshold: :maximum, maximum: value}),
    do: value != nil
end
