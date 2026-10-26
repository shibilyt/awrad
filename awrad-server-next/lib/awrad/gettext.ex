defmodule Awrad.Gettext do
  @moduledoc """
  Translations for text the server sends to people: today only account emails
  (`priv/gettext/<locale>/LC_MESSAGES/emails.po`).

  Messages use stable keys (`"verify_email.subject"`) rather than English
  source text, so every string lives in a `.po` file, never in code. en, ar and
  ml are kept together; `test/awrad/accounts/user_notifier_test.exs` fails when
  a locale misses a key.
  """

  use Gettext.Backend, otp_app: :awrad, default_locale: "en", allowed_locales: ~w(en ar ml)

  @doc "The supported locales, default first."
  @spec locales() :: [String.t(), ...]
  def locales, do: ~w(en ar ml)
end
