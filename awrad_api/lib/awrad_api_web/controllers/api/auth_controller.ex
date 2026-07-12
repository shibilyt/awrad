defmodule AwradApiWeb.Api.AuthController do
  use AwradApiWeb, :controller

  alias AwradApi.Accounts
  alias AwradApi.Accounts.{AuthRateLimiter, Token}

  @generic_registration "If the address can be registered, verification instructions will arrive shortly."
  @generic_verification "If the account exists, verification instructions will arrive shortly."

  def register(conn, %{"email" => email, "password" => password}) do
    with :ok <- rate_limit(conn, "register_ip", ip_subject(conn), 5, 3600),
         :ok <- rate_limit(conn, "register_account", email, 5, 3600) do
      case Accounts.register_password_user(%{email: email, password: password}) do
        {:ok, user} ->
          _ = Accounts.deliver_user_verification_instructions(user, &verification_url/1)
          registration_accepted(conn)

        {:error, changeset} ->
          if duplicate_email?(changeset) do
            registration_accepted(conn)
          else
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{errors: format_changeset_errors(changeset)})
          end
      end
    else
      {:rate_limited, retry_after} -> rate_limited(conn, retry_after)
    end
  end

  def login(conn, %{"email" => email, "password" => password} = params) do
    with :ok <- rate_limit(conn, "login_ip", ip_subject(conn), 30, 900),
         :ok <- rate_limit(conn, "login_account", email, 10, 900) do
      case Accounts.authenticate_password_user(email, password) do
        {:ok, %{confirmed_at: nil}} ->
          conn
          |> put_status(:forbidden)
          |> json(%{
            error: "email verification required",
            error_code: "email_verification_required"
          })

        {:ok, user} ->
          case Token.create_session(user, Map.get(params, "device", %{})) do
            {:ok, {session, access, refresh}} ->
              json(conn, auth_payload(user, session, access, refresh))

            {:error, _} ->
              server_error(conn)
          end

        {:error, :invalid_credentials} ->
          conn |> put_status(:unauthorized) |> json(%{error: "invalid email or password"})
      end
    else
      {:rate_limited, retry_after} -> rate_limited(conn, retry_after)
    end
  end

  def verify_email(conn, %{"token" => token} = params) do
    with :ok <- rate_limit(conn, "verify_ip", ip_subject(conn), 10, 3600),
         {:ok, user} <- Accounts.verify_user_email(token),
         {:ok, {session, access, refresh}} <-
           Token.create_session(user, Map.get(params, "device", %{})) do
      json(conn, auth_payload(user, session, access, refresh))
    else
      {:rate_limited, retry_after} ->
        rate_limited(conn, retry_after)

      _ ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "invalid or expired verification token"})
    end
  end

  def resend_verification(conn, %{"email" => email}) do
    with :ok <- rate_limit(conn, "resend_ip", ip_subject(conn), 5, 3600),
         :ok <- rate_limit(conn, "resend_account", email, 5, 3600) do
      case Accounts.get_user_by_email(email) do
        %{confirmed_at: nil} = user ->
          _ = Accounts.deliver_user_verification_instructions(user, &verification_url/1)

        _ ->
          :ok
      end

      conn |> put_status(:accepted) |> json(%{message: @generic_verification})
    else
      {:rate_limited, retry_after} -> rate_limited(conn, retry_after)
    end
  end

  def refresh(conn, %{"refresh_token" => refresh_token} = params) do
    with :ok <- rate_limit(conn, "refresh_ip", ip_subject(conn), 60, 900),
         {:ok, user, session, access, refresh} <-
           Token.verify_and_rotate_refresh_token(refresh_token, params["request_id"]) do
      json(conn, auth_payload(user, session, access, refresh))
    else
      {:rate_limited, retry_after} ->
        rate_limited(conn, retry_after)

      {:error, :reuse_detected} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "session revoked", error_code: "refresh_reuse_detected"})

      _ ->
        conn |> put_status(:unauthorized) |> json(%{error: "invalid or expired refresh token"})
    end
  end

  def logout(conn, _params) do
    user = conn.assigns.current_user
    session = conn.assigns.current_session
    _ = Token.revoke_session(user, session.id, "logout")
    json(conn, %{message: "logged out"})
  end

  def sessions(conn, _params) do
    sessions = Enum.map(Token.list_sessions(conn.assigns.current_user), &session_payload/1)
    json(conn, %{sessions: sessions})
  end

  def revoke_session(conn, %{"id" => id}) do
    case Token.revoke_session(conn.assigns.current_user, id) do
      {:ok, :ok} ->
        send_resp(conn, :no_content, "")

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "session not found"})
    end
  end

  def revoke_all_sessions(conn, _params) do
    {:ok, :ok} = Token.revoke_all_sessions(conn.assigns.current_user)
    send_resp(conn, :no_content, "")
  end

  def forgot_password(conn, %{"email" => email}) do
    with :ok <- rate_limit(conn, "forgot_ip", ip_subject(conn), 5, 3600),
         :ok <- rate_limit(conn, "forgot_account", email, 5, 3600) do
      if user = Accounts.get_user_by_email(email) do
        Accounts.deliver_user_reset_password_instructions(
          user,
          &url(~p"/users/reset-password/#{&1}")
        )
      end

      json(conn, %{
        message: "If the email is registered, you will receive reset instructions shortly."
      })
    else
      {:rate_limited, retry_after} -> rate_limited(conn, retry_after)
    end
  end

  def reset_password(conn, %{"token" => token, "password" => password}) do
    with :ok <- rate_limit(conn, "reset_ip", ip_subject(conn), 10, 3600) do
      case Accounts.get_user_by_reset_password_token(token) do
        nil ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: "invalid or expired reset token"})

        user ->
          case Accounts.reset_user_password(user, %{password: password}) do
            {:ok, {_user, _tokens}} ->
              json(conn, %{message: "Password reset successfully."})

            {:error, changeset} ->
              conn
              |> put_status(:unprocessable_entity)
              |> json(%{errors: format_changeset_errors(changeset)})
          end
      end
    else
      {:rate_limited, retry_after} -> rate_limited(conn, retry_after)
    end
  end

  defp auth_payload(user, session, access, refresh) do
    %{
      user: %{id: user.id, email: user.email, email_verified: not is_nil(user.confirmed_at)},
      session: session_payload(session),
      access_token: access,
      refresh_token: refresh
    }
  end

  defp session_payload(session) do
    %{
      id: session.id,
      device_name: session.device_name,
      platform: session.platform,
      last_seen_at: session.last_seen_at,
      idle_expires_at: session.idle_expires_at,
      absolute_expires_at: session.absolute_expires_at
    }
  end

  defp rate_limit(_conn, scope, subject, limit, window) do
    case AuthRateLimiter.allow?(scope, subject, limit, window) do
      {:ok, _remaining} -> :ok
      {:error, retry_after} -> {:rate_limited, retry_after}
    end
  end

  defp rate_limited(conn, retry_after) do
    conn
    |> put_resp_header("retry-after", Integer.to_string(retry_after))
    |> put_status(:too_many_requests)
    |> json(%{error: "too many requests", error_code: "rate_limited"})
  end

  defp ip_subject(conn), do: conn.remote_ip |> :inet.ntoa() |> to_string()
  defp verification_url(token), do: url(~p"/auth/verify-email/#{token}")

  defp registration_accepted(conn),
    do:
      conn
      |> put_status(:accepted)
      |> json(%{message: @generic_registration, verification_required: true})

  defp duplicate_email?(changeset),
    do:
      Enum.any?(changeset.errors, fn {field, {_msg, opts}} ->
        field == :email and (opts[:constraint] == :unique or opts[:validation] == :unsafe_unique)
      end)

  defp server_error(conn),
    do: conn |> put_status(:internal_server_error) |> json(%{error: "authentication unavailable"})

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        replacement =
          if is_binary(value) or is_number(value), do: to_string(value), else: inspect(value)

        String.replace(acc, "%{#{key}}", replacement)
      end)
    end)
  end
end
