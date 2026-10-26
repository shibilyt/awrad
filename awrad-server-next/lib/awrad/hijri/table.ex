defmodule Awrad.Hijri.Table do
  @moduledoc false
  # The shared Umm al-Qura month table (contracts/hijri-calendar/v1/umm-al-qura.json),
  # compiled into this module (ADR 0004).
  #
  # The server's copy is priv/hijri-calendar/umm-al-qura.json: the release
  # never reads contracts/, and not even the copy, because the data is read
  # here at compile time. A test fails `mix validate` when the copy differs
  # from the contracts file.
  #
  # Months are numbered by index from 1 Muharram 1400 (index 0) to Dhu
  # al-Hijjah 1500 (index 1211). `start/1` is a month's Gregorian start as a
  # Gregorian day number (`Date.to_gregorian_days/1`); index 1212 is the
  # table's end (exclusive).

  @path Path.expand("../../../priv/hijri-calendar/umm-al-qura.json", __DIR__)
  @external_resource @path

  @first_year 1400
  @last_year 1500
  @months (@last_year - @first_year + 1) * 12

  table = @path |> File.read!() |> Jason.decode!()

  starts =
    for year <- @first_year..@last_year,
        start <- Map.fetch!(table["month_starts"], Integer.to_string(year)) do
      start |> Date.from_iso8601!() |> Date.to_gregorian_days()
    end

  starts = starts ++ [table["end_exclusive"] |> Date.from_iso8601!() |> Date.to_gregorian_days()]

  # The table the rules assume: Umm al-Qura v1, 1400–1500, every month 29 or 30 days.
  unless match?(%{"calendar" => "umm_al_qura", "version" => 1}, table) and
           {table["first_year"], table["last_year"]} == {@first_year, @last_year} and
           length(starts) == @months + 1 and
           starts
           |> Enum.chunk_every(2, 1, :discard)
           |> Enum.all?(fn [a, b] -> (b - a) in 29..30 end) do
    raise CompileError,
      description:
        "#{@path}: expected the Umm al-Qura v1 table, 1400–1500, months of 29 or 30 days"
  end

  @starts List.to_tuple(starts)

  @typedoc "A month's position in the table: 0 is Muharram 1400, 1211 Dhu al-Hijjah 1500."
  @type index :: 0..1211

  @typedoc "A Gregorian day number (`Date.to_gregorian_days/1`)."
  @type day :: integer()

  @doc "The number of months in the table."
  @spec months() :: 1212
  def months, do: @months

  @spec first_year() :: 1400
  def first_year, do: @first_year

  @spec last_year() :: 1500
  def last_year, do: @last_year

  @doc "The index of a Hijri month inside the table, or `nil` outside it."
  @spec index(integer(), integer()) :: index() | nil
  def index(year, month) when year in @first_year..@last_year and month in 1..12,
    do: (year - @first_year) * 12 + month - 1

  def index(_year, _month), do: nil

  @doc "The Hijri `{year, month}` of an index."
  @spec year_month(index()) :: {pos_integer(), 1..12}
  def year_month(index), do: {@first_year + div(index, 12), rem(index, 12) + 1}

  @doc "The table's start of month `index`; index #{@months} is the table's end (exclusive)."
  @spec start(0..1212) :: day()
  def start(index), do: elem(@starts, index)

  @doc """
  The last index whose table start is on or before `day`: -1 before the
  table, #{@months} from its end onwards.
  """
  @spec floor_index(day()) :: -1..1212
  def floor_index(day), do: search(day, -1, @months)

  # Invariant: start(low) <= day (or low = -1) and start(high + 1) > day (or high = @months).
  defp search(_day, low, high) when low == high, do: low

  defp search(day, low, high) do
    middle = div(low + high + 1, 2)
    if start(middle) <= day, do: search(day, middle, high), else: search(day, low, middle - 1)
  end
end
