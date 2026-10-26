defmodule Awrad.Accounts.UserNotifierTest do
  @moduledoc "Account emails in en, ar and ml, with every message present in every locale."
  use ExUnit.Case, async: true

  alias Awrad.Accounts.UserNotifier

  @codes [:verify_email, :reset_password, :change_email]
  @notices [:password_changed, :email_taken, :email_changed, :account_deleted]
  @keys for(name <- @codes ++ @notices, part <- ~w(subject body), do: "#{name}.#{part}")

  for locale <- Awrad.Gettext.locales(), key <- @keys do
    @locale locale
    @key key
    test "#{locale} translates #{key}" do
      text =
        Gettext.with_locale(Awrad.Gettext, @locale, fn ->
          Gettext.dgettext(Awrad.Gettext, "emails", @key,
            code: "1",
            minutes: 15,
            new_email: "x@example.com"
          )
        end)

      assert text != @key and text != ""
    end
  end

  for locale <- Awrad.Gettext.locales(), purpose <- @codes do
    @locale locale
    @purpose purpose
    test "the #{purpose} email in #{locale} carries the code and the validity" do
      email = UserNotifier.build("amina@example.com", @purpose, "048213", @locale)

      assert email.to == [{"", "amina@example.com"}]
      assert email.text_body =~ "048213"
      assert email.text_body =~ "15"
    end
  end

  for locale <- Awrad.Gettext.locales(), notice <- @notices do
    @locale locale
    @notice notice
    test "the #{notice} notice in #{locale} carries no code" do
      email =
        UserNotifier.build_notice("amina@example.com", @notice, @locale,
          new_email: "amina.new@example.com"
        )

      assert email.to == [{"", "amina@example.com"}]
      refute email.text_body =~ ~r/\d{6}/
      refute email.text_body =~ "%{"
    end
  end

  for locale <- Awrad.Gettext.locales() do
    @locale locale
    test "the email_changed notice in #{locale} names the new address" do
      email =
        UserNotifier.build_notice("amina@example.com", :email_changed, @locale,
          new_email: "amina.new@example.com"
        )

      assert email.text_body =~ "amina.new@example.com"
    end
  end

  test "the languages differ" do
    for build <- [
          &UserNotifier.build("a@example.com", :verify_email, "1", &1),
          &UserNotifier.build_notice("a@example.com", :account_deleted, &1)
        ] do
      subjects = for locale <- ~w(en ar ml), do: build.(locale).subject
      assert Enum.uniq(subjects) == subjects
    end
  end
end
