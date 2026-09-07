defmodule AwradServerWeb.UserResetPasswordController do
  use AwradServerWeb, :controller

  alias AwradServer.Accounts
  alias AwradServerWeb.BrowserAuthProtection
  alias AwradServerWeb.PublicUrls

  def new(conn, _params) do
    render(conn, :new)
  end

  def create(conn, %{"user" => %{"email" => email}}) do
    with :ok <- BrowserAuthProtection.allow?(conn, "password_reset", email, 5, 5, 3600) do
      if user = Accounts.get_user_by_email(email) do
        Accounts.deliver_user_reset_password_instructions(
          user,
          &PublicUrls.web(~p"/users/reset-password/#{&1}")
        )
      end

      conn
      |> put_flash(
        :info,
        "If your email is in our system, you will receive reset instructions shortly."
      )
      |> redirect(to: ~p"/users/log-in")
    else
      {:error, retry_after} -> BrowserAuthProtection.rate_limited(conn, retry_after)
    end
  end

  def edit(conn, %{"token" => token}) do
    if Accounts.get_user_by_reset_password_token(token) do
      form = Phoenix.Component.to_form(%{"token" => token}, as: "user")
      render(conn, :edit, form: form)
    else
      conn
      |> put_flash(:error, "Reset password link is invalid or it has expired.")
      |> redirect(to: ~p"/users/reset-password")
    end
  end

  def update(conn, %{
        "user" => %{
          "token" => token,
          "password" => password,
          "password_confirmation" => password_confirmation
        }
      }) do
    case Accounts.get_user_by_reset_password_token(token) do
      nil ->
        conn
        |> put_flash(:error, "Reset password link is invalid or it has expired.")
        |> redirect(to: ~p"/users/reset-password")

      user ->
        case Accounts.reset_user_password(user, %{
               password: password,
               password_confirmation: password_confirmation
             }) do
          {:ok, _} ->
            conn
            |> put_flash(:info, "Password reset successfully. You can now log in.")
            |> redirect(to: ~p"/users/log-in")

          {:error, changeset} ->
            form = Phoenix.Component.to_form(%{"token" => token}, as: "user")
            render(conn, :edit, form: form, errors: format_errors(changeset))
        end
    end
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
