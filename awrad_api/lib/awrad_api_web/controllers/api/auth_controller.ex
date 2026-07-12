defmodule AwradApiWeb.Api.AuthController do
  use AwradApiWeb, :controller

  alias AwradApi.Accounts
  alias AwradApi.Accounts.Token

  action_fallback AwradApiWeb.FallbackController

  def register(conn, %{"email" => email, "password" => password}) do
    case Accounts.register_user(%{email: email}) do
      {:ok, user} ->
        {:ok, user} =
          user
          |> Accounts.change_user_password(%{password: password})
          |> AwradApi.Repo.update()

        {:ok, access_token, refresh_token} = Token.generate_token_pair(user)

        conn
        |> put_status(:created)
        |> json(%{
          user: %{id: user.id, email: user.email},
          access_token: access_token,
          refresh_token: refresh_token
        })

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_changeset_errors(changeset)})
    end
  end

  def login(conn, %{"email" => email, "password" => password}) do
    case Accounts.get_user_by_email_and_password(email, password) do
      %{} = user ->
        {:ok, access_token, refresh_token} = Token.generate_token_pair(user)

        json(conn, %{
          user: %{id: user.id, email: user.email},
          access_token: access_token,
          refresh_token: refresh_token
        })

      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "invalid email or password"})
    end
  end

  def refresh(conn, %{"refresh_token" => refresh_token}) do
    case Token.verify_and_rotate_refresh_token(refresh_token) do
      {:ok, user} ->
        {:ok, access_token, new_refresh_token} = Token.generate_token_pair(user)

        json(conn, %{
          access_token: access_token,
          refresh_token: new_refresh_token
        })

      {:error, :invalid_token} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "invalid or expired refresh token"})
    end
  end

  def logout(conn, %{"refresh_token" => refresh_token}) do
    Token.delete_refresh_token(refresh_token)
    json(conn, %{message: "logged out"})
  end

  def logout(conn, _params) do
    user = conn.assigns[:current_user]

    if user do
      Token.delete_all_refresh_tokens(user)
    end

    json(conn, %{message: "logged out"})
  end

  def forgot_password(conn, %{"email" => email}) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_user_reset_password_instructions(
        user,
        &url(~p"/users/reset-password/#{&1}")
      )
    end

    # Always return 200 to prevent email enumeration
    json(conn, %{message: "If the email is registered, you will receive reset instructions shortly."})
  end

  def reset_password(conn, %{"token" => token, "password" => password}) do
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
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
