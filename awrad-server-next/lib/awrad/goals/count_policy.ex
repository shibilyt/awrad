defmodule Awrad.Goals.CountPolicy do
  @moduledoc """
  The numbers a goal works against: an optional minimum, the target, an
  optional maximum, and which number a day needs to keep the streak (the
  streak threshold):

  - `:any_count` (1), or the policy's `:minimum`, `:target` or `:maximum`;
  - `{:amount, n}`, a number of its own (decisions 29 and 36);
  - `:daily_pace`, that day's pace share (totals with an end only).

  A valid goal's streak threshold always points at a value that is set
  (`Awrad.Goals.Goal.new/1`).
  """

  @type streak_threshold ::
          :any_count | :minimum | :target | :maximum | :daily_pace | {:amount, pos_integer()}

  @enforce_keys [:minimum, :target, :maximum, :streak_threshold]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          minimum: non_neg_integer() | nil,
          target: non_neg_integer() | nil,
          maximum: non_neg_integer() | nil,
          streak_threshold: streak_threshold()
        }

  @doc "Whether the streak threshold names the minimum, target or maximum while that value isn't set."
  @spec streak_threshold_unset?(t()) :: boolean()
  def streak_threshold_unset?(%__MODULE__{streak_threshold: :minimum, minimum: nil}), do: true
  def streak_threshold_unset?(%__MODULE__{streak_threshold: :target, target: nil}), do: true
  def streak_threshold_unset?(%__MODULE__{streak_threshold: :maximum, maximum: nil}), do: true
  def streak_threshold_unset?(%__MODULE__{}), do: false
end
