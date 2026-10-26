defmodule Awrad.Goals.Rules.EffectiveDay do
  @moduledoc false
  # Rule: effective practice day (fixtures/effective_practice_day.json).

  @spec resolve(DateTime.t(), String.t(), :midnight | :maghrib, DateTime.t() | nil) ::
          {:ok, Date.t()} | {:error, :time_zone_not_found | :utc_only_time_zone_database}
  def resolve(instant, time_zone, day_reset, maghrib) do
    with {:ok, local} <- DateTime.shift_zone(instant, time_zone) do
      date = DateTime.to_date(local)
      {:ok, if(from_maghrib?(instant, day_reset, maghrib), do: Date.add(date, 1), else: date)}
    end
  end

  # The Maghrib instant itself belongs to the new day (>=).
  defp from_maghrib?(instant, :maghrib, %DateTime{} = maghrib),
    do: DateTime.compare(instant, maghrib) != :lt

  defp from_maghrib?(_instant, _day_reset, _maghrib), do: false
end
