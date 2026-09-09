defmodule AwradServer.PracticeDay do
  @moduledoc """
  Resolves the current practice date from an account day-reset policy.

  The browser calculates Maghrib with the same astronomical family as the
  native clients and sends the resulting UTC instant. The server compares that
  instant with its own clock before using the date for reads or a count.
  """

  @type status :: :midnight | :maghrib | :location_required | :calculation_unavailable

  @type result :: %{
          civil_date: Date.t(),
          effective_date: Date.t(),
          maghrib_at: DateTime.t() | nil,
          status: status()
        }

  @doc "Resolves a civil date and optional browser-calculated Maghrib instant."
  @spec resolve(map()) :: {:ok, result()} | {:error, atom()}
  def resolve(attrs) when is_map(attrs) do
    attrs
    |> Map.put_new(:now, DateTime.utc_now(:second))
    |> resolve_with_now()
  end

  defp resolve_with_now(
         %{
           now: %DateTime{} = now,
           civil_date: %Date{} = civil_date,
           day_reset: day_reset
         } = attrs
       )
       when day_reset in ["midnight", "maghrib"] do
    if day_reset == "midnight" do
      {:ok, result(civil_date, civil_date, nil, :midnight)}
    else
      case normalize_maghrib(Map.get(attrs, :maghrib_at)) do
        {:ok, nil, status} ->
          {:ok, result(civil_date, civil_date, nil, status)}

        {:ok, maghrib_at, :maghrib} ->
          effective_date =
            case DateTime.compare(now, maghrib_at) do
              :lt -> civil_date
              :eq -> Date.add(civil_date, 1)
              :gt -> Date.add(civil_date, 1)
            end

          {:ok, result(civil_date, effective_date, maghrib_at, :maghrib)}
      end
    end
  end

  defp resolve_with_now(_attrs), do: {:error, :invalid_practice_day_context}

  defp normalize_maghrib(nil), do: {:ok, nil, :location_required}
  defp normalize_maghrib(%DateTime{} = maghrib_at), do: {:ok, maghrib_at, :maghrib}

  defp normalize_maghrib(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, maghrib_at, _offset} -> {:ok, maghrib_at, :maghrib}
      {:error, _reason} -> {:ok, nil, :calculation_unavailable}
    end
  end

  defp normalize_maghrib(_value), do: {:ok, nil, :calculation_unavailable}

  defp result(civil_date, effective_date, maghrib_at, status) do
    %{
      civil_date: civil_date,
      effective_date: effective_date,
      maghrib_at: maghrib_at,
      status: status
    }
  end
end
