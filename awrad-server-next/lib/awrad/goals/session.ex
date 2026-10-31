defmodule Awrad.Goals.Session do
  @moduledoc """
  A time-of-day opportunity with its own target (decisions 10 and 47). The
  kind only guides: any session can be counted at any time of its day.

  A session carries a target only, with no minimum, cap or streak threshold of
  its own: its streak amount is its target. A tracker's session may have no
  target (`nil`, any count).

  Its ID is derived from the kind (`id_for/1`), so a shared count made in one
  goal's "after Fajr" fills the same session of another goal on that dhikr.
  `Awrad.Goals.Goal.new/1` rejects a session whose ID isn't derived.
  """

  @type prayer :: :fajr | :dhuhr | :asr | :maghrib | :isha

  @typedoc "Local wall-clock times, in minutes. A `between` window may run past midnight."
  @type kind ::
          :anytime
          | {:before_prayer, prayer()}
          | {:after_prayer, prayer()}
          | {:at_time, Time.t()}
          | {:between, from :: Time.t(), to :: Time.t()}

  @enforce_keys [:id, :kind, :target]
  defstruct @enforce_keys

  @type t :: %__MODULE__{id: String.t(), kind: kind(), target: non_neg_integer() | nil}

  @doc """
  The ID a session of `kind` has: `anytime`, `before_<prayer>`,
  `after_<prayer>`, `at_HHMM` or `between_HHMM_HHMM`.
  """
  @spec id_for(kind()) :: String.t()
  def id_for(:anytime), do: "anytime"
  def id_for({:before_prayer, prayer}), do: "before_#{prayer}"
  def id_for({:after_prayer, prayer}), do: "after_#{prayer}"
  def id_for({:at_time, time}), do: "at_" <> hhmm(time)
  def id_for({:between, from, to}), do: "between_" <> hhmm(from) <> "_" <> hhmm(to)

  defp hhmm(%Time{} = time), do: Calendar.strftime(time, "%H%M")
end
