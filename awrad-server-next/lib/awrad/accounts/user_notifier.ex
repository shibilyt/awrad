defmodule Awrad.Accounts.UserNotifier do
  @moduledoc """
  Account emails: the 6-digit verification and password-reset codes, in the
  request's language (en, ar or ml; `Awrad.Gettext`).

  Emails are sent from a supervised task, so a request takes the same time
  whether or not it sent one: the generic `202` responses don't reveal through
  timing whether an email has an account (`contracts/api/STYLE.md` §11).
  In development they land in Swoosh's local mailbox at `/dev/mailbox`.
  """

  use Gettext, backend: Awrad.Gettext

  import Swoosh.Email

  require Logger

  alias Awrad.Accounts.EmailCode
  alias Awrad.Mailer

  @doc "Builds the email carrying `code` for `purpose`, in `locale`."
  @spec build(String.t(), EmailCode.purpose(), String.t(), String.t()) :: Swoosh.Email.t()
  def build(to, purpose, code, locale) do
    {subject, body} = Gettext.with_locale(Awrad.Gettext, locale, fn -> text(purpose, code) end)

    new()
    |> to(to)
    |> from(sender())
    |> subject(subject)
    |> text_body(body)
  end

  @doc "Sends the code email in the background. Always returns `:ok`."
  @spec deliver_code(String.t(), EmailCode.purpose(), String.t(), String.t()) :: :ok
  def deliver_code(to, purpose, code, locale) do
    email = build(to, purpose, code, locale)

    {:ok, _pid} =
      Task.Supervisor.start_child(Awrad.TaskSupervisor, fn ->
        case Mailer.deliver(email) do
          {:ok, _metadata} -> :ok
          {:error, reason} -> Logger.error("account email not sent: #{inspect(reason)}")
        end
      end)

    :ok
  end

  defp text(:verify_email, code) do
    {dgettext("emails", "verify_email.subject"),
     dgettext("emails", "verify_email.body", code: code, minutes: EmailCode.validity_minutes())}
  end

  defp text(:reset_password, code) do
    {dgettext("emails", "reset_password.subject"),
     dgettext("emails", "reset_password.body", code: code, minutes: EmailCode.validity_minutes())}
  end

  defp sender do
    :awrad
    |> Application.fetch_env!(__MODULE__)
    |> Keyword.fetch!(:from)
  end
end
