defmodule AwradServerWeb.UserSessionHTML do
  use AwradServerWeb, :html

  embed_templates "user_session_html/*"

  defp local_mail_adapter? do
    Application.get_env(:awrad_server, AwradServer.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
