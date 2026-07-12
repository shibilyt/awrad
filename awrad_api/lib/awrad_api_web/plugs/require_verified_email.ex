defmodule AwradApiWeb.Plugs.RequireVerifiedEmail do
  import Plug.Conn

  def init(opts), do: opts

  def call(%{assigns: %{current_user: %{confirmed_at: confirmed_at}}} = conn, _opts)
      when not is_nil(confirmed_at), do: conn

  def call(conn, _opts) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(
      403,
      Jason.encode!(%{
        error: "email verification required",
        error_code: "email_verification_required"
      })
    )
    |> halt()
  end
end
