defmodule AwradApiWeb.UserSessionHTML do
  use AwradApiWeb, :html

  embed_templates "user_session_html/*"

  defp local_mail_adapter? do
    Application.get_env(:awrad_api, AwradApi.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
