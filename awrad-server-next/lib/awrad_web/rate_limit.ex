defmodule AwradWeb.RateLimit do
  @moduledoc """
  Applies `Awrad.Accounts.RateLimiter` to a request: per client IP and per
  account (`contracts/api/STYLE.md` §12).

  **The client IP is `conn.remote_ip`, the TCP peer.** That's right when the
  server faces clients directly. Behind a reverse proxy or load balancer every
  client would share the proxy's address, so a deployment behind one must
  rewrite `remote_ip` from its trusted forwarding header first (for example
  with the `remote_ip` plug, configured with the proxy's addresses) — never
  from a header the client controls. See `ARCHITECTURE.md`.
  """

  alias Awrad.Accounts.{EmailInput, RateLimiter}

  @doc """
  Counts `action` for the request's IP and `account` (an email as typed, or
  `nil` to limit by IP only). Returns `:ok` or `{:error, {:rate_limited, seconds}}`.
  """
  @spec check(Plug.Conn.t(), RateLimiter.action(), String.t() | nil) ::
          :ok | {:error, {:rate_limited, pos_integer()}}
  def check(conn, action, account) do
    case RateLimiter.check(action, ip(conn), account && account_subject(account)) do
      :ok -> :ok
      {:error, retry_after} -> {:error, {:rate_limited, retry_after}}
    end
  end

  defp ip(conn), do: conn.remote_ip |> :inet.ntoa() |> to_string()

  # Emails compare case-insensitively, and clients trim them; so does the limit.
  defp account_subject(email) do
    case EmailInput.normalize(email) do
      {:ok, normalized} -> "email:" <> String.downcase(normalized)
      :error -> "email:" <> String.downcase(String.trim(email))
    end
  end
end
