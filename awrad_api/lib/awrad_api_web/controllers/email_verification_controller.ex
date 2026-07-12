defmodule AwradApiWeb.EmailVerificationController do
  use AwradApiWeb, :controller

  alias AwradApi.Accounts

  def verify(conn, %{"token" => token}) do
    case Accounts.verify_user_email(token) do
      {:ok, _user} ->
        send_resp(conn, :ok, "Email verified. You can return to Awrad and log in.")

      {:error, _reason} ->
        send_resp(conn, :unprocessable_entity, "This verification link is invalid or expired.")
    end
  end
end
