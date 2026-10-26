defmodule AwradWeb.AccountSettingsController do
  @moduledoc """
  Account settings for a signed-in account
  (`contracts/api/paths/account_settings.yaml`, slice 2b): the session list,
  password and email changes, and account deletion.

  Every action runs after `AwradWeb.Plugs.AccountAuth`, so the caller is a
  bearer token or a cookie session (with its CSRF token checked on changes),
  never both, and ownership always comes from `conn.assigns.current_scope`.
  """

  use AwradWeb, :controller

  alias Awrad.Accounts
  alias Awrad.Accounts.Scope
  alias AwradWeb.{AccountJSON, Locale, Params, RateLimit, UserAuth}
  alias AwradWeb.Plugs.Idempotency

  action_fallback AwradWeb.FallbackController

  @doc "`list_account_sessions`: `200` with a page of device and browser sessions."
  @spec list_sessions(Plug.Conn.t(), map()) :: Plug.Conn.t() | {:error, term()}
  def list_sessions(conn, params) do
    with {:ok, limit} <- limit(params["limit"]),
         {:ok, cursor} <- cursor(params["cursor"]),
         {:ok, page} <- sessions_page(conn.assigns.current_scope, cursor, limit) do
      json(conn, %{
        items: Enum.map(page.items, &AccountJSON.account_session/1),
        next_cursor: page.next_cursor
      })
    end
  end

  @doc """
  `revoke_account_session`: `204`, or `404` for an ID that isn't one of the
  account's live sessions. Revoking the caller's own browser session signs the
  browser out (its cookies are cleared).
  """
  @spec revoke_session(Plug.Conn.t(), map()) :: Plug.Conn.t() | {:error, term()}
  def revoke_session(conn, %{"session_id" => session_id}) do
    scope = conn.assigns.current_scope

    case Accounts.revoke_account_session(scope, session_id) do
      :ok ->
        conn
        |> sign_out_if_own_browser(scope, session_id)
        |> send_resp(:no_content, "")

      :not_found ->
        {:error, :not_found}
    end
  end

  @doc "`revoke_other_account_sessions`: `204`; the caller's own session stays."
  @spec revoke_other_sessions(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def revoke_other_sessions(conn, _params) do
    :ok = Accounts.revoke_other_account_sessions(conn.assigns.current_scope)
    send_resp(conn, :no_content, "")
  end

  @doc """
  `change_password`: `204`. Every other session ends; the caller's stays as it
  is (a browser keeps its cookie and CSRF token).
  """
  @spec change_password(Plug.Conn.t(), map()) :: Plug.Conn.t() | {:error, term()}
  def change_password(conn, _params) do
    scope = conn.assigns.current_scope

    with {:ok, values} <-
           Params.cast(conn,
             current_password: {:string, :required},
             new_password: {:string, :required}
           ),
         %{current_password: current_password, new_password: new_password} = values,
         :ok <- RateLimit.check_account(conn, :password_check, scope.user),
         :ok <-
           Accounts.change_password(
             scope,
             current_password,
             new_password,
             Locale.from_conn(conn)
           ) do
      send_resp(conn, :no_content, "")
    end
  end

  @doc "`request_email_change`: `202` for any valid request (no enumeration)."
  @spec request_email_change(Plug.Conn.t(), map()) :: Plug.Conn.t() | {:error, term()}
  def request_email_change(conn, _params) do
    scope = conn.assigns.current_scope

    with {:ok, values} <-
           Params.cast(conn,
             current_password: {:string, :required},
             new_email: {:string, :required}
           ),
         %{current_password: current_password, new_email: new_email} = values,
         :ok <- RateLimit.check_account(conn, :password_check, scope.user),
         :ok <- RateLimit.check_account(conn, :request_email_change, scope.user),
         :ok <-
           Accounts.request_email_change(
             scope,
             current_password,
             new_email,
             Locale.from_conn(conn)
           ) do
      send_resp(conn, :accepted, "")
    end
  end

  @doc "`confirm_email_change`: `200` with the account and its new email."
  @spec confirm_email_change(Plug.Conn.t(), map()) :: Plug.Conn.t() | {:error, term()}
  def confirm_email_change(conn, _params) do
    scope = conn.assigns.current_scope

    with {:ok, values} <- Params.cast(conn, code: {:string, :required}),
         %{code: code} = values,
         :ok <- RateLimit.check_account(conn, :confirm_email_change, scope.user),
         {:ok, user} <-
           code_result(Accounts.confirm_email_change(scope, code, Locale.from_conn(conn))) do
      json(conn, AccountJSON.account(user))
    end
  end

  @doc """
  `delete_account`: `204`. The account is gone and every session with it; a
  browser's cookies are cleared. `Idempotency-Key` is checked for shape only:
  nothing can be stored for an account that no longer exists, and a repeat
  after success is `401` because the credential ended with the account.
  """
  @spec delete(Plug.Conn.t(), map()) :: Plug.Conn.t() | {:error, term()}
  def delete(conn, _params) do
    scope = conn.assigns.current_scope

    with :ok <- optional_key(conn),
         {:ok, values} <- Params.cast(conn, current_password: {:string, :required}),
         %{current_password: current_password} = values,
         :ok <- RateLimit.check_account(conn, :password_check, scope.user),
         :ok <- Accounts.delete_account(scope, current_password, Locale.from_conn(conn)) do
      conn
      |> sign_out_browser(scope)
      |> send_resp(:no_content, "")
    end
  end

  defp sessions_page(scope, cursor, limit) do
    case Accounts.list_account_sessions(scope, cursor, limit) do
      {:ok, page} -> {:ok, page}
      {:error, :cursor_invalid} -> {:error, "cursor is invalid"}
    end
  end

  defp limit(nil), do: {:ok, nil}

  defp limit(value) when is_binary(value) do
    case Integer.parse(value) do
      {limit, ""} when limit in 1..100 -> {:ok, limit}
      _invalid -> {:error, "limit must be an integer from 1 to 100"}
    end
  end

  defp limit(_value), do: {:error, "limit must be an integer from 1 to 100"}

  defp cursor(nil), do: {:ok, nil}
  defp cursor(value) when is_binary(value) and value != "", do: {:ok, value}
  defp cursor(_value), do: {:error, "cursor is invalid"}

  defp sign_out_if_own_browser(conn, scope, session_id) do
    if Scope.current_session_id(scope) == String.downcase(session_id),
      do: sign_out_browser(conn, scope),
      else: conn
  end

  defp sign_out_browser(conn, %Scope{browser_session_id: id}) when is_binary(id),
    do: UserAuth.log_out_user(conn)

  defp sign_out_browser(conn, _bearer), do: conn

  defp code_result({:error, :code_invalid}), do: {:error, :email_change_code_invalid}
  defp code_result(result), do: result

  defp optional_key(conn) do
    case Idempotency.key(conn) do
      :error -> {:error, "Idempotency-Key must be a lowercase UUID"}
      _none_or_key -> :ok
    end
  end
end
