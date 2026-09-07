defmodule AwradServerWeb.EmailVerificationController do
  use AwradServerWeb, :controller

  alias AwradServer.Accounts
  alias AwradServerWeb.PublicUrls

  def mobile(conn, %{"token" => token}) do
    custom_url = "awrad://verify-email?" <> URI.encode_query(%{"token" => token})
    legacy_url = PublicUrls.web(~p"/auth/verify-email/#{token}")
    nonce = 18 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)

    html = """
    <!doctype html>
    <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Verify your Awrad account</title>
        <style>
          body { font-family: system-ui, sans-serif; margin: 0; background: #f4f6f3; color: #193126; }
          main { max-width: 34rem; margin: 12vh auto; padding: 2rem; text-align: center; }
          section { background: white; border-radius: 1.5rem; padding: 2rem; box-shadow: 0 1rem 3rem rgba(25,49,38,.08); }
          a { display: block; margin-top: 1rem; padding: .9rem 1.2rem; border-radius: .9rem; text-decoration: none; }
          .primary { background: #4b7c5a; color: white; }
          .secondary { color: #355f43; border: 1px solid #b9c8bd; }
        </style>
      </head>
      <body>
        <main>
          <section>
            <h1>Verify your email</h1>
            <p>Open Awrad to finish verification and sign in on this device.</p>
            <a class="primary" href="#{custom_url}">Open Awrad</a>
            <a class="secondary" href="#{legacy_url}">Verify in this browser</a>
          </section>
        </main>
        <script nonce="#{nonce}">window.location.href = #{Jason.encode!(custom_url)};</script>
      </body>
    </html>
    """

    conn
    |> put_resp_header("cache-control", "no-store")
    |> put_resp_header("referrer-policy", "no-referrer")
    |> put_resp_header(
      "content-security-policy",
      "default-src 'none'; style-src 'unsafe-inline'; script-src 'nonce-#{nonce}'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'"
    )
    |> put_resp_content_type("text/html")
    |> send_resp(:ok, html)
  end

  def verify(conn, %{"token" => token}) do
    case Accounts.verify_user_email(token) do
      {:ok, _user} ->
        send_resp(conn, :ok, "Email verified. You can return to Awrad and log in.")

      {:error, _reason} ->
        send_resp(conn, :unprocessable_entity, "This verification link is invalid or expired.")
    end
  end
end
