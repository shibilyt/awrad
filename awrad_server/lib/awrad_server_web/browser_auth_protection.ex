defmodule AwradServerWeb.BrowserAuthProtection do
  @moduledoc false

  import Plug.Conn

  alias AwradServer.Accounts.AuthRateLimiter

  @spec allow?(Plug.Conn.t(), String.t(), term(), pos_integer(), pos_integer(), pos_integer()) ::
          :ok | {:error, pos_integer()}
  def allow?(conn, action, email, ip_limit, account_limit, window_seconds) do
    with {:ok, _remaining} <-
           AuthRateLimiter.allow?(
             "browser_#{action}_ip",
             ip_subject(conn),
             ip_limit,
             window_seconds
           ),
         {:ok, _remaining} <-
           AuthRateLimiter.allow?(
             "browser_#{action}_account",
             account_subject(email),
             account_limit,
             window_seconds
           ) do
      :ok
    else
      {:error, retry_after} -> {:error, retry_after}
    end
  end

  @spec rate_limited(Plug.Conn.t(), pos_integer()) :: Plug.Conn.t()
  def rate_limited(conn, retry_after) do
    conn
    |> put_resp_header("retry-after", Integer.to_string(retry_after))
    |> send_resp(:too_many_requests, "Too many requests. Please try again later.")
  end

  @spec duplicate_email?(Ecto.Changeset.t()) :: boolean()
  def duplicate_email?(changeset) do
    Enum.any?(changeset.errors, fn {field, {_message, options}} ->
      field == :email and
        (options[:constraint] == :unique or options[:validation] == :unsafe_unique)
    end)
  end

  defp ip_subject(conn), do: conn.remote_ip |> :inet.ntoa() |> to_string()
  defp account_subject(email) when is_binary(email), do: email
  defp account_subject(_email), do: "missing-email"
end
