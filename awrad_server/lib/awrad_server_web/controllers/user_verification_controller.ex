defmodule AwradServerWeb.UserVerificationController do
  use AwradServerWeb, :controller

  alias AwradServer.Accounts
  alias AwradServerWeb.BrowserAuthProtection
  alias AwradServerWeb.PublicUrls

  def resend(conn, _params) do
    user = conn.assigns.current_scope.user

    if user.confirmed_at do
      redirect(conn, to: ~p"/home")
    else
      with :ok <-
             BrowserAuthProtection.allow?(conn, "verification_resend", user.email, 5, 3, 3600) do
        _ =
          Accounts.deliver_user_verification_instructions(
            user,
            &PublicUrls.web(~p"/auth/verify-email/#{&1}")
          )

        conn
        |> put_flash(:info, "If the address is valid, a new verification email is on its way.")
        |> redirect(to: ~p"/users/verification-required")
      else
        {:error, retry_after} -> BrowserAuthProtection.rate_limited(conn, retry_after)
      end
    end
  end
end
