defmodule Awrad.Sync.PracticePolicyDocument do
  @moduledoc """
  Checks a `practice_policy` document (slice 3d,
  `urn:awrad:practice-settings:1#/$defs/practice_policy_document`) by hand,
  reporting each problem as the `{field, code}` errors of
  `contracts/practice-settings/v1/fixtures/practice_policy_validity.json`:

    * `required`: a member that's missing;
    * `not_allowed`: a member the policy doesn't have (`location` and
      `timezone` are device context and never reach the server);
    * `invalid`: a value that isn't one of the member's (`null` and wrong
      case included), `hijri_corrections` that isn't a list (on
      `/hijri_corrections`), or a correction that isn't exactly
      `{year, month, offset_days}` as integers with year 1400–1500, month
      1–12 and offset −2 to 2 (on `/hijri_corrections/N`);
    * `duplicate`: a later correction for a month already corrected, checked
      only when every correction is well formed;
    * `range` on `/hijri_corrections`: a month that would have neither 29 nor
      30 days, checked only when there are no duplicates
      (`Awrad.Hijri.Corrections.new/1`).

  Corrections may come in any order. Fields are JSON Pointers into the
  document; errors are sorted by field, then code.
  """

  alias Awrad.Hijri.Corrections

  @enums %{
    "day_reset" => ~w(midnight maghrib),
    "calculation_method" =>
      ~w(karachi north_america muslim_world_league egyptian umm_al_qura moonsighting_committee dubai kuwait qatar singapore),
    "madhab" => ~w(shafi hanafi),
    "week_start" => ~w(saturday sunday monday)
  }
  @members ["hijri_corrections" | Map.keys(@enums)]
  @correction_members ~w(month offset_days year)

  @type error :: %{required(String.t()) => String.t()}

  @doc "The document's errors, sorted; `[]` when it's valid."
  @spec errors(map()) :: [error()]
  def errors(document) when is_map(document) do
    unknown =
      for key <- Map.keys(document), key not in @members, do: {pointer(key), "not_allowed"}

    settings =
      for {key, values} <- @enums,
          error <- setting(Map.fetch(document, key), values),
          do: {"/" <> key, error}

    (unknown ++ settings ++ corrections(Map.fetch(document, "hijri_corrections")))
    |> Enum.sort()
    |> Enum.map(fn {field, code} -> %{"field" => field, "code" => code} end)
  end

  defp setting(:error, _values), do: ["required"]
  defp setting({:ok, value}, values), do: if(value in values, do: [], else: ["invalid"])

  defp corrections(:error), do: [{"/hijri_corrections", "required"}]

  defp corrections({:ok, list}) when is_list(list) do
    malformed =
      for {correction, index} <- Enum.with_index(list),
          not well_formed?(correction),
          do: {"/hijri_corrections/#{index}", "invalid"}

    if malformed == [], do: duplicates_or_range(list), else: malformed
  end

  defp corrections({:ok, _not_a_list}), do: [{"/hijri_corrections", "invalid"}]

  defp well_formed?(%{"year" => year, "month" => month, "offset_days" => offset} = correction),
    do:
      map_size(correction) == length(@correction_members) and is_integer(year) and
        year in 1400..1500 and is_integer(month) and month in 1..12 and is_integer(offset) and
        offset in -2..2

  defp well_formed?(_other), do: false

  # Every later correction of a month already seen is a duplicate; only a set
  # without duplicates has its month lengths checked.
  defp duplicates_or_range(list) do
    months = Enum.map(list, &{&1["year"], &1["month"]})

    duplicates =
      for {month, index} <- Enum.with_index(months),
          month in Enum.take(months, index),
          do: {"/hijri_corrections/#{index}", "duplicate"}

    if duplicates == [], do: month_lengths(list), else: duplicates
  end

  defp month_lengths(list) do
    corrections =
      for %{"year" => year, "month" => month, "offset_days" => offset} <- list,
          do: %{year: year, month: month, offset_days: offset}

    case Corrections.new(corrections) do
      {:ok, _corrections} -> []
      {:error, [:month_length_invalid]} -> [{"/hijri_corrections", "range"}]
    end
  end

  defp pointer(key), do: "/" <> (key |> String.replace("~", "~0") |> String.replace("/", "~1"))
end
