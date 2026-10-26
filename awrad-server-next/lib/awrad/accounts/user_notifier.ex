defmodule Awrad.Accounts.UserNotifier do
  @moduledoc """
  Account emails, in the request's language (en, ar or ml; `Awrad.Gettext`):

    * codes: email verification, password reset, and email change (sent to
      the new address);
    * notices: password changed, email change to an address that already has
      an account (sent there instead of a code), email changed (sent to the
      old address), account deleted.

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

  @type notice :: :password_changed | :email_taken | :email_changed | :account_deleted

  @doc "Builds the email carrying `code` for `purpose`, in `locale`."
  @spec build(String.t(), EmailCode.purpose(), String.t(), String.t()) :: Swoosh.Email.t()
  def build(to, purpose, code, locale) do
    email(to, locale, fn -> code_text(purpose, code) end)
  end

  @doc """
  Builds the `notice` email, in `locale`. `bindings` fill its placeholders
  (`new_email` for `:email_changed`).
  """
  @spec build_notice(String.t(), notice(), String.t(), keyword()) :: Swoosh.Email.t()
  def build_notice(to, notice, locale, bindings \\ []) do
    email(to, locale, fn -> notice_text(notice, bindings) end)
  end

  @doc "Sends the code email in the background. Always returns `:ok`."
  @spec deliver_code(String.t(), EmailCode.purpose(), String.t(), String.t()) :: :ok
  def deliver_code(to, purpose, code, locale), do: deliver(build(to, purpose, code, locale))

  @doc "Sends the `notice` email in the background. Always returns `:ok`."
  @spec deliver_notice(String.t(), notice(), String.t(), keyword()) :: :ok
  def deliver_notice(to, notice, locale, bindings \\ []),
    do: deliver(build_notice(to, notice, locale, bindings))

  defp email(to, locale, text) do
    {subject, body} = Gettext.with_locale(Awrad.Gettext, locale, text)

    new()
    |> to(to)
    |> from(sender())
    |> subject(subject)
    |> text_body(body)
  end

  defp deliver(email) do
    {:ok, _pid} =
      Task.Supervisor.start_child(Awrad.TaskSupervisor, fn ->
        case Mailer.deliver(email) do
          {:ok, _metadata} -> :ok
          {:error, reason} -> Logger.error("account email not sent: #{inspect(reason)}")
        end
      end)

    :ok
  end

  defp code_text(:verify_email, code) do
    {dgettext("emails", "verify_email.subject"),
     dgettext("emails", "verify_email.body", code: code, minutes: EmailCode.validity_minutes())}
  end

  defp code_text(:reset_password, code) do
    {dgettext("emails", "reset_password.subject"),
     dgettext("emails", "reset_password.body", code: code, minutes: EmailCode.validity_minutes())}
  end

  defp code_text(:change_email, code) do
    {dgettext("emails", "change_email.subject"),
     dgettext("emails", "change_email.body", code: code, minutes: EmailCode.validity_minutes())}
  end

  defp notice_text(:password_changed, _bindings) do
    {dgettext("emails", "password_changed.subject"), dgettext("emails", "password_changed.body")}
  end

  defp notice_text(:email_taken, _bindings) do
    {dgettext("emails", "email_taken.subject"), dgettext("emails", "email_taken.body")}
  end

  defp notice_text(:email_changed, bindings) do
    {dgettext("emails", "email_changed.subject"),
     dgettext("emails", "email_changed.body", new_email: Keyword.fetch!(bindings, :new_email))}
  end

  defp notice_text(:account_deleted, _bindings) do
    {dgettext("emails", "account_deleted.subject"), dgettext("emails", "account_deleted.body")}
  end

  defp sender do
    :awrad
    |> Application.fetch_env!(__MODULE__)
    |> Keyword.fetch!(:from)
  end
end
