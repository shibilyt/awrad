defmodule Awrad.Accounts.UserNotifierTest do
  @moduledoc "Code emails in en, ar and ml, with every message present in every locale."
  use ExUnit.Case, async: true

  alias Awrad.Accounts.UserNotifier

  @keys ~w(verify_email.subject verify_email.body reset_password.subject reset_password.body)

  for locale <- Awrad.Gettext.locales(), key <- @keys do
    @locale locale
    @key key
    test "#{locale} translates #{key}" do
      text =
        Gettext.with_locale(Awrad.Gettext, @locale, fn ->
          Gettext.dgettext(Awrad.Gettext, "emails", @key, code: "1", minutes: 15)
        end)

      assert text != @key and text != ""
    end
  end

  for locale <- Awrad.Gettext.locales(), purpose <- [:verify_email, :reset_password] do
    @locale locale
    @purpose purpose
    test "the #{purpose} email in #{locale} carries the code and the validity" do
      email = UserNotifier.build("amina@example.com", @purpose, "048213", @locale)

      assert email.to == [{"", "amina@example.com"}]
      assert email.text_body =~ "048213"
      assert email.text_body =~ "15"
    end
  end

  test "the languages differ" do
    subjects =
      for locale <- ~w(en ar ml),
          do: UserNotifier.build("a@example.com", :verify_email, "1", locale).subject

    assert Enum.uniq(subjects) == subjects
  end
end
