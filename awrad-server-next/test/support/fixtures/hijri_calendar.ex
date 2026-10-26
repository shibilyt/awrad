defmodule Awrad.Fixtures.HijriCalendar do
  @moduledoc """
  Maps the JSON of `contracts/hijri-calendar/v1/hijri-calendar.schema.json` to
  `Awrad.Hijri` inputs, and results back to the fixtures' `expect` shapes.
  """

  alias Awrad.Hijri.Corrections
  alias Awrad.Hijri.HijriDate

  @doc "A schema `corrections_shape` as `Corrections.new/1` input, without validating it."
  @spec corrections([map()]) :: [Corrections.correction()]
  def corrections(json) do
    for %{"year" => year, "month" => month, "offset_days" => offset} <- json,
        do: %{year: year, month: month, offset_days: offset}
  end

  @doc "A schema `corrections` (valid) as `Corrections`. An invalid set raises."
  @spec corrections!([map()]) :: Corrections.t()
  def corrections!(json) do
    case json |> corrections() |> Corrections.new() do
      {:ok, corrections} -> corrections
      {:error, errors} -> raise ArgumentError, "invalid fixture corrections: #{inspect(errors)}"
    end
  end

  @doc "A `hijri_date` result as its expect shape."
  @spec encode_date(HijriDate.t() | nil) :: map()
  def encode_date(nil), do: %{"hijri" => nil, "month_length" => nil}

  def encode_date(%HijriDate{} = date) do
    %{
      "hijri" => %{"year" => date.year, "month" => date.month, "day" => date.day},
      "month_length" => date.month_length
    }
  end

  @doc "A `Corrections.new/1` result as the `hijri_corrections_validity` expect shape."
  @spec encode_validity({:ok, Corrections.t()} | {:error, [Corrections.error()]}) :: map()
  def encode_validity({:ok, %Corrections{}}), do: %{"valid" => true, "errors" => []}

  def encode_validity({:error, errors}),
    do: %{"valid" => false, "errors" => Enum.map(errors, &Atom.to_string/1)}
end
