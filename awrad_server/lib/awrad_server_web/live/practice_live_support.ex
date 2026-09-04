defmodule AwradServerWeb.PracticeLiveSupport do
  @moduledoc false

  alias AwradServer.ProgressSync

  def initialize(socket) do
    socket =
      socket
      |> Phoenix.Component.assign(:browser_date, Date.utc_today())
      |> Phoenix.Component.assign(:browser_timezone, "UTC")
      |> Phoenix.Component.assign(:browser_context_ready?, false)
      |> Phoenix.Component.assign(:sync_available?, true)

    refresh_actor(socket)
  end

  def apply_browser_context(socket, %{"date" => date, "timezone" => timezone})
      when is_binary(date) and is_binary(timezone) do
    with {:ok, date} <- Date.from_iso8601(date),
         true <- byte_size(timezone) in 1..128,
         {:ok, socket} <- refresh_actor(socket) do
      {:ok,
       socket
       |> Phoenix.Component.assign(:browser_date, date)
       |> Phoenix.Component.assign(:browser_timezone, timezone)
       |> Phoenix.Component.assign(:browser_context_ready?, true)}
    else
      _other -> :error
    end
  end

  def apply_browser_context(_socket, _params), do: :error

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
