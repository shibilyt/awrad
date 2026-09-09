defmodule AwradServerWeb.PracticeLiveSupport do
  @moduledoc false

  alias AwradServer.PracticeSettings
  alias AwradServer.PracticeDay
  alias AwradServer.ProgressSync

  @home_prayer_names ~w(Fajr Dhuhr Asr Maghrib Isha)

  def initialize(socket) do
    socket =
      socket
      |> Phoenix.Component.assign(:browser_date, Date.utc_today())
      |> Phoenix.Component.assign(:effective_date, Date.utc_today())
      |> Phoenix.Component.assign(:browser_timezone, "UTC")
      |> Phoenix.Component.assign(:browser_maghrib_at, nil)
      |> Phoenix.Component.assign(:browser_prayer_times, [])
      |> Phoenix.Component.assign(:browser_next_prayer, nil)
      |> Phoenix.Component.assign(:practice_day_status, :midnight)
      |> Phoenix.Component.assign(:browser_context_ready?, false)
      |> Phoenix.Component.assign(:practice_policy, PracticeSettings.default_policy())
      |> Phoenix.Component.assign(:device_context, nil)
      |> Phoenix.Component.assign(:sync_available?, true)

    with {:ok, socket} <- refresh_actor(socket),
         {:ok, socket} <- refresh_settings(socket) do
      {:ok, socket}
    end
  end

  def apply_browser_context(socket, %{"date" => date, "timezone" => timezone} = params)
      when is_binary(date) and is_binary(timezone) do
    with {:ok, date} <- Date.from_iso8601(date),
         true <- byte_size(timezone) in 1..128,
         {:ok, socket} <- refresh_actor(socket),
         {:ok, socket} <- store_device_context(socket, params),
         {:ok, socket} <- refresh_settings(socket),
         {:ok, day} <- resolve_practice_day(socket, date, Map.get(params, "maghrib_at")) do
      prayer_context =
        normalize_prayer_context(
          Map.get(params, "prayer_times"),
          Map.get(params, "next_prayer")
        )

      {:ok,
       socket
       |> Phoenix.Component.assign(:browser_date, date)
       |> Phoenix.Component.assign(:browser_timezone, timezone)
       |> Phoenix.Component.assign(:effective_date, day.effective_date)
       |> Phoenix.Component.assign(:browser_maghrib_at, day.maghrib_at)
       |> Phoenix.Component.assign(:browser_prayer_times, prayer_context.prayer_times)
       |> Phoenix.Component.assign(:browser_next_prayer, prayer_context.next_prayer)
       |> Phoenix.Component.assign(:practice_day_status, day.status)
       |> Phoenix.Component.assign(:browser_context_ready?, true)}
    else
      _other -> :error
    end
  end

  def apply_browser_context(_socket, _params), do: :error

  def apply_manual_location(
        socket,
        %{"latitude" => latitude, "longitude" => longitude}
      ) do
    persist_location(socket, %{
      timezone: socket.assigns.browser_timezone,
      latitude: latitude,
      longitude: longitude,
      location_name: nil,
      location_source: "manual"
    })
  end

  def apply_manual_location(_socket, _params), do: :error

  def apply_named_location(
        socket,
        %{display_name: display_name, latitude: latitude, longitude: longitude}
      )
      when is_binary(display_name) do
    persist_location(socket, %{
      timezone: socket.assigns.browser_timezone,
      latitude: latitude,
      longitude: longitude,
      location_name: display_name,
      location_source: "manual"
    })
  end

  def apply_named_location(_socket, _location), do: :error

  defp persist_location(socket, attrs) do
    with {:ok, socket} <- refresh_actor(socket),
         {:ok, _context} <-
           PracticeSettings.upsert_device_context(
             socket.assigns.current_scope,
             socket.assigns[:web_installation_id],
             attrs
           ),
         {:ok, socket} <- refresh_settings(socket),
         {:ok, day} <-
           resolve_practice_day(
             socket,
             socket.assigns.browser_date,
             nil
           ) do
      socket =
        socket
        |> Phoenix.Component.assign(:effective_date, day.effective_date)
        |> Phoenix.Component.assign(:browser_maghrib_at, day.maghrib_at)
        |> Phoenix.Component.assign(:browser_prayer_times, [])
        |> Phoenix.Component.assign(:browser_next_prayer, nil)
        |> Phoenix.Component.assign(:practice_day_status, day.status)

      {:ok, socket}
    else
      _other -> :error
    end
  end

  defp store_device_context(socket, params) do
    attrs =
      %{timezone: Map.fetch!(params, "timezone")}
      |> maybe_put_number(:latitude, Map.get(params, "latitude"))
      |> maybe_put_number(:longitude, Map.get(params, "longitude"))
      |> maybe_put_number(:accuracy_m, Map.get(params, "accuracy_m"))
      |> maybe_put_string(:location_name, Map.get(params, "location_name"))
      |> maybe_put_string(:location_source, Map.get(params, "location_source"))

    case PracticeSettings.upsert_device_context(
           socket.assigns.current_scope,
           socket.assigns[:web_installation_id],
           attrs
         ) do
      {:ok, _context} -> {:ok, socket}
      {:error, _reason} -> :error
    end
  end

  defp refresh_settings(socket) do
    case PracticeSettings.snapshot(
           socket.assigns[:current_scope],
           socket.assigns[:web_installation_id]
         ) do
      %{policy: policy, device_context: device_context} ->
        {:ok,
         socket
         |> Phoenix.Component.assign(:practice_policy, policy)
         |> Phoenix.Component.assign(:device_context, device_context)}
    end
  end

  defp resolve_practice_day(socket, civil_date, maghrib_at) do
    PracticeDay.resolve(%{
      now: DateTime.utc_now(:second),
      civil_date: civil_date,
      day_reset: socket.assigns.practice_policy.day_reset,
      maghrib_at: maghrib_at
    })
  end

  defp maybe_put_number(attrs, _key, value) when is_nil(value), do: attrs
  defp maybe_put_number(attrs, key, value) when is_number(value), do: Map.put(attrs, key, value)
  defp maybe_put_number(attrs, _key, _value), do: attrs

  defp maybe_put_string(attrs, _key, value) when not is_binary(value), do: attrs
  defp maybe_put_string(attrs, key, value), do: Map.put(attrs, key, value)

  defp normalize_prayer_context(prayer_times, next_prayer) do
    prayer_times =
      prayer_times
      |> List.wrap()
      |> Enum.take(5)
      |> Enum.map(&normalize_prayer_row/1)
      |> Enum.reject(&is_nil/1)

    %{prayer_times: prayer_times, next_prayer: normalize_prayer_row(next_prayer)}
  end

  defp normalize_prayer_row(row) when is_map(row) do
    name = Map.get(row, "name")
    time = Map.get(row, "time")
    at = Map.get(row, "at")

    with true <- name in @home_prayer_names,
         true <- valid_display_text?(time, 32),
         true <- valid_display_text?(at, 64),
         {:ok, _date_time, _offset} <- DateTime.from_iso8601(at) do
      %{
        name: name,
        time: time,
        at: at,
        is_complete: Map.get(row, "is_complete") == true,
        is_next: Map.get(row, "is_next") == true,
        countdown: normalize_countdown(Map.get(row, "countdown"))
      }
    else
      _other -> nil
    end
  end

  defp normalize_prayer_row(_row), do: nil

  defp normalize_countdown(value) when is_binary(value) do
    if valid_display_text?(value, 32), do: value, else: nil
  end

  defp normalize_countdown(_value), do: nil

  defp valid_display_text?(value, max_bytes)
       when is_binary(value) and byte_size(value) >= 1 and byte_size(value) <= max_bytes,
       do: true

  defp valid_display_text?(_value, _max_bytes), do: false

  defp refresh_actor(socket) do
    scope = socket.assigns.current_scope
    installation_id = socket.assigns[:web_installation_id]

    with %AwradServer.Accounts.Scope{} <- scope,
         user when not is_nil(user) <- scope.user,
         installation_id when is_binary(installation_id) <- installation_id,
         {:ok, actor} <- ProgressSync.ensure_actor(scope, installation_id),
         {:ok, _acknowledged} <- ProgressSync.acknowledge_actor_at_head(scope, actor.id) do
      {:ok, Phoenix.Component.assign(socket, :web_actor_id, actor.id)}
    else
      _other ->
        {:ok, Phoenix.Component.assign(socket, :sync_available?, false)}
    end
  end
end
