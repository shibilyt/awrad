defmodule AwradWeb.DeviceSessionController do
  @moduledoc """
  Mobile sign-in, refresh and sign-out (`contracts/api/paths/device_sessions.yaml`,
  ADR-2026-07-12, root ADR-2026-10-26). These operations take no bearer token.
  """

  use AwradWeb, :controller

  alias Awrad.Accounts
  alias AwradWeb.{AccountJSON, Locale, Params, RateLimit}
  alias AwradWeb.Plugs.Idempotency

  action_fallback AwradWeb.FallbackController

  @refresh_token [refresh_token: {:string, :required}]

  @doc "`create_device_session`: `201` with the grant."
  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t() | {:error, term()}
  def create(conn, _params) do
    device =
      {:object,
       installation_id: {:string, :required},
       name: {:string, :required},
       platform: {:string, :required}}

    with {:ok, values} <-
           Params.cast(conn,
             email: {:string, :required},
             password: {:string, :required},
             device: {device, :required}
           ),
         %{email: email, password: password, device: device} = values,
         :ok <- RateLimit.check(conn, :sign_in, email),
         {:ok, grant} <-
           Accounts.create_device_session(email, password, device, Locale.from_conn(conn)) do
      conn
      |> put_status(:created)
      |> json(AccountJSON.grant(grant))
    end
  end

  @doc """
  `refresh_device_session`: `200` with the new grant. `Idempotency-Key` is
  required; a retry with the same key within 60 seconds gets the same tokens.
  """
  @spec refresh(Plug.Conn.t(), map()) :: Plug.Conn.t() | {:error, term()}
  def refresh(conn, _params) do
    with {:ok, key} <- required_key(conn),
         {:ok, values} <- Params.cast(conn, @refresh_token),
         %{refresh_token: refresh_token} = values,
         :ok <- RateLimit.check(conn, :refresh, nil),
         {:ok, grant} <- Accounts.refresh_device_session(refresh_token, key) do
      json(conn, AccountJSON.grant(grant))
    end
  end

  @doc "`sign_out_device_session`: `204`, also for an unknown or already revoked token."
  @spec sign_out(Plug.Conn.t(), map()) :: Plug.Conn.t() | {:error, term()}
  def sign_out(conn, _params) do
    with :ok <- optional_key(conn),
         {:ok, values} <- Params.cast(conn, @refresh_token) do
      %{refresh_token: refresh_token} = values

      :ok = Accounts.sign_out_device_session(refresh_token)
      send_resp(conn, :no_content, "")
    end
  end

  defp required_key(conn) do
    case Idempotency.key(conn) do
      {:ok, key} -> {:ok, key}
      :none -> {:error, "Idempotency-Key is required"}
      :error -> {:error, "Idempotency-Key must be a lowercase UUID"}
    end
  end

  # Sign-out is idempotent by nature (always 204), so the key is only checked
  # for shape and nothing is stored.
  defp optional_key(conn) do
    case Idempotency.key(conn) do
      :error -> {:error, "Idempotency-Key must be a lowercase UUID"}
      _none_or_key -> :ok
    end
  end
end
