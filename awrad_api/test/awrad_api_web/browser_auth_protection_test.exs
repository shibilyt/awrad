defmodule AwradApiWeb.BrowserAuthProtectionTest do
  use AwradApiWeb.ConnCase, async: true

  alias AwradApiWeb.BrowserAuthProtection

  test "keeps IP and normalized account budgets independent", %{conn: conn} do
    other_ip_conn = %{conn | remote_ip: {127, 0, 0, 2}}

    assert :ok = BrowserAuthProtection.allow?(conn, "test", "person@example.com", 1, 1, 60)

    assert {:error, _retry_after} =
             BrowserAuthProtection.allow?(
               other_ip_conn,
               "test",
               "PERSON@EXAMPLE.COM",
               1,
               1,
               60
             )

    assert {:error, _retry_after} =
             BrowserAuthProtection.allow?(conn, "test", "other@example.com", 1, 1, 60)
  end
end
