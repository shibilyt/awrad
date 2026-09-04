defmodule AwradServer.Accounts.UserNotifierTest do
  use AwradServer.DataCase, async: false

  import AwradServer.AccountsFixtures
  import Swoosh.TestAssertions

  alias AwradServer.Accounts.UserNotifier

  setup do
    previous_mailer_from = Application.get_env(:awrad_server, :mailer_from)

    Application.put_env(
      :awrad_server,
      :mailer_from,
      {"Awrad", "noreply@test.awrad.app"}
    )

    on_exit(fn ->
      if previous_mailer_from do
        Application.put_env(:awrad_server, :mailer_from, previous_mailer_from)
      else
        Application.delete_env(:awrad_server, :mailer_from)
      end
    end)

    :ok
  end

  test "uses the configured product sender for account emails" do
    user = unconfirmed_user_fixture()

    assert {:ok, _email} =
             UserNotifier.deliver_email_verification_instructions(
               user,
               "https://example.com/auth/verify-email/token"
             )

    assert_email_sent(fn email ->
      assert email.from == {"Awrad", "noreply@test.awrad.app"}
      assert email.subject == "Verify your Awrad account"
      true
    end)
  end
end
