defmodule Awrad.Hijri.Corrections do
  @moduledoc """
  The account's Hijri month-start corrections, for local moon sighting
  (`CONTEXT.md`, Hijri correction; root ADR-2026-10-26).

  A correction `%{year: 1447, month: 9, offset_days: 1}` moves that month's
  start by `offset_days` from the table (positive = later), and every later
  month's, until the next correction. The table's end moves with the last
  correction in force.

  Build them with `new/1`, which rejects invalid sets with the
  `hijri_corrections_validity` codes, or use `none/0`. Every rule that reads
  Hijri dates takes a valid set.
  """

  alias Awrad.Hijri.Table

  @enforce_keys [:offsets]
  defstruct @enforce_keys

  @typedoc """
  `offsets` holds `{month_index, offset_days}` per correction, by month
  (`Awrad.Hijri.Table` indexes). Build it with `new/1` or `none/0`.
  """
  @type t :: %__MODULE__{offsets: [{Table.index(), -2..2}]}

  @typedoc "One correction, before validation."
  @type correction :: %{year: integer(), month: integer(), offset_days: integer()}

  @typedoc """
  Why a set of corrections is invalid (fixtures/hijri_corrections_validity.json):

  - `:month_out_of_range`: a year outside 1400–1500 or a month outside 1–12;
  - `:offset_out_of_range`: more than 2 days from the table;
  - `:duplicate_month`: two corrections for the same month;
  - `:month_length_invalid`: an adjusted month without 29 or 30 days. Only
    checked when the set has no other error.
  """
  @type error ::
          :duplicate_month | :month_length_invalid | :month_out_of_range | :offset_out_of_range

  @max_offset 2

  @doc "No corrections: the table as it is."
  @spec none() :: t()
  def none, do: %__MODULE__{offsets: []}

  @doc """
  Builds a valid set of corrections, in any order, or returns every reason
  it's invalid, sorted alphabetically.
  """
  @spec new([correction()]) :: {:ok, t()} | {:error, [error(), ...]}
  def new(corrections) do
    case shape_errors(corrections) do
      [] -> corrections |> from_valid() |> check_month_lengths()
      errors -> {:error, Enum.sort(errors)}
    end
  end

  @doc "The offset in force for month `index`: the latest correction on or before it."
  @spec offset(t(), 0..1212) :: -2..2
  def offset(%__MODULE__{offsets: offsets}, index) do
    Enum.reduce_while(offsets, 0, fn
      {month, offset}, _in_force when month <= index -> {:cont, offset}
      _later, in_force -> {:halt, in_force}
    end)
  end

  @doc "The adjusted start of month `index` (a Gregorian day number); #{Table.months()} is the table's end."
  @spec start(t(), 0..1212) :: Table.day()
  def start(corrections, index), do: Table.start(index) + offset(corrections, index)

  defp shape_errors(corrections) do
    months = Enum.map(corrections, &{&1.year, &1.month})

    [
      {:month_out_of_range, Enum.any?(corrections, &is_nil(Table.index(&1.year, &1.month)))},
      {:offset_out_of_range, Enum.any?(corrections, &(abs(&1.offset_days) > @max_offset))},
      {:duplicate_month, length(Enum.uniq(months)) != length(months)}
    ]
    |> Enum.flat_map(fn {code, failed?} -> if failed?, do: [code], else: [] end)
  end

  defp from_valid(corrections) do
    offsets =
      corrections
      |> Enum.map(fn %{year: year, month: month, offset_days: offset} ->
        {checked_index(year, month), checked_offset(offset)}
      end)
      |> Enum.sort()

    %__MODULE__{offsets: offsets}
  end

  # Every adjusted month must still have 29 or 30 days.
  defp check_month_lengths(%__MODULE__{} = corrections) do
    starts = Enum.map(0..Table.months(), &start(corrections, &1))

    if starts
       |> Enum.chunk_every(2, 1, :discard)
       |> Enum.all?(fn [a, b] -> (b - a) in 29..30 end),
       do: {:ok, corrections},
       else: {:error, [:month_length_invalid]}
  end

  # Both already checked by shape_errors/1; these narrow the types.
  defp checked_index(year, month) do
    case Table.index(year, month) do
      index when is_integer(index) -> index
    end
  end

  defp checked_offset(offset) when offset in -@max_offset..@max_offset, do: offset
end
