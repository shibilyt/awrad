defmodule AwradServerWeb.UserRegistrationController do
  use AwradServerWeb, :controller

  alias AwradServer.Accounts
  alias AwradServer.Accounts.User
  alias AwradServerWeb.BrowserAuthProtection
  alias AwradServerWeb.PublicUrls

  @generic_registration "If the address can be registered, instructions will arrive shortly."

  def new(conn, _params) do
    changeset = Accounts.change_user_email(%User{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"user" => user_params}) do
    email = Map.get(user_params, "email")

    with :ok <- BrowserAuthProtection.allow?(conn, "register", email, 5, 5, 3600) do
      case Accounts.register_user(user_params) do
        {:ok, user} ->
          {:ok, _} =
            Accounts.deliver_login_instructions(
              user,
              &PublicUrls.web(~p"/users/log-in/#{&1}")
            )

          registration_accepted(conn)

        {:error, %Ecto.Changeset{} = changeset} ->
          if BrowserAuthProtection.duplicate_email?(changeset) do
            registration_accepted(conn)
          else
            render(conn, :new, changeset: changeset)
          end
      end
    else
      {:error, retry_after} -> BrowserAuthProtection.rate_limited(conn, retry_after)
    end
  end

  defp registration_accepted(conn) do
    conn
    |> put_flash(:info, @generic_registration)
    |> redirect(to: ~p"/users/log-in")
  end
end
