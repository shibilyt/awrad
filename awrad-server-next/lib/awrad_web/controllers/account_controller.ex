defmodule AwradWeb.AccountController do
  @moduledoc """
  Account operations (`contracts/api/paths/accounts.yaml`): registration,
  email verification, password reset, and the signed-in account.

  The public operations answer the same whether or not an email has an
  account (`contracts/api/STYLE.md` §11).
  """

  use AwradWeb, :controller

  alias Awrad.Accounts
  alias AwradWeb.{AccountJSON, Locale, Params, RateLimit}

  action_fallback AwradWeb.FallbackController

  @doc "`register_account`: `202`, always."
  @spec register(Plug.Conn.t(), map()) :: Plug.Conn.t() | {:error, term()}
  def register(conn, _params) do
    with {:ok, values} <-
           Params.cast(conn, email: {:string, :required}, password: {:string, :required}),
         %{email: email, password: password} = values,
         :ok <- RateLimit.check(conn, :register, email),
         :ok <- Accounts.register(email, password, Locale.from_conn(conn)) do
      send_resp(conn, :accepted, "")
    end
  end

  @doc "`verify_account_email`: `204`; doesn't sign in."
  @spec verify_email(Plug.Conn.t(), map()) :: Plug.Conn.t() | {:error, term()}
  def verify_email(conn, _params) do
    with {:ok, values} <-
           Params.cast(conn, email: {:string, :required}, code: {:string, :required}),
         %{email: email, code: code} = values,
         :ok <- RateLimit.check(conn, :verify_email, email),
         :ok <- code_result(Accounts.verify_email(email, code), :verification_code_invalid) do
      send_resp(conn, :no_content, "")
    end
  end

  @doc "`resend_verification_code`: `202`, always."
  @spec resend_verification_code(Plug.Conn.t(), map()) :: Plug.Conn.t() | {:error, term()}
  def resend_verification_code(conn, _params) do
    with {:ok, values} <- Params.cast(conn, email: {:string, :required}),
         %{email: email} = values,
         :ok <- RateLimit.check(conn, :resend_verification_code, email),
         :ok <- Accounts.resend_verification_code(email, Locale.from_conn(conn)) do
      send_resp(conn, :accepted, "")
    end
  end

  @doc "`request_password_reset`: `202`, always."
  @spec request_password_reset(Plug.Conn.t(), map()) :: Plug.Conn.t() | {:error, term()}
  def request_password_reset(conn, _params) do
    with {:ok, values} <- Params.cast(conn, email: {:string, :required}),
         %{email: email} = values,
         :ok <- RateLimit.check(conn, :request_password_reset, email),
         :ok <- Accounts.request_password_reset(email, Locale.from_conn(conn)) do
      send_resp(conn, :accepted, "")
    end
  end

  @doc "`reset_password`: `204`; every session of the account is revoked."
  @spec reset_password(Plug.Conn.t(), map()) :: Plug.Conn.t() | {:error, term()}
  def reset_password(conn, _params) do
    with {:ok, values} <-
           Params.cast(conn,
             email: {:string, :required},
             code: {:string, :required},
             new_password: {:string, :required}
           ),
         %{email: email, code: code, new_password: new_password} = values,
         :ok <- RateLimit.check(conn, :reset_password, email),
         :ok <-
           code_result(Accounts.reset_password(email, code, new_password), :reset_code_invalid) do
      send_resp(conn, :no_content, "")
    end
  end

  @doc "`get_current_account`: the account of the bearer token or the cookie session."
  @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def show(conn, _params) do
    json(conn, AccountJSON.account(conn.assigns.current_scope.user))
  end

  defp code_result({:error, :code_invalid}, code), do: {:error, code}
  defp code_result(result, _code), do: result
end
