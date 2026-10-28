defmodule AwradWeb.RefreshAccountDeletedTest do
  @moduledoc """
  `refresh_device_session` after the account is deleted (slice 3b, server ADR
  0010): a refresh token that still worked answers `401 account_deleted`;
  anything else stays `refresh_token_invalid`.
  """
  use AwradWeb.ConnCase, async: true

  import Awrad.AccountsFixtures
  import AwradWeb.Contract

  alias Awrad.Accounts.DeletedRefreshToken
  alias Awrad.Repo

  defp fresh(conn), do: %{build_conn() | remote_ip: conn.remote_ip}

  defp refresh(conn, refresh_token) do
    conn
    |> fresh()
    |> json_conn([{"idempotency-key", Awrad.UUIDv7.generate()}])
    |> post(~p"/api/v1/device_sessions/refresh", Jason.encode!(%{refresh_token: refresh_token}))
  end

  defp delete_account(conn, grant) do
    conn
    |> bearer_request(grant)
    |> post(~p"/api/v1/account/delete", Jason.encode!(%{current_password: valid_password()}))
  end

  test "a live refresh token of a deleted account is 401 account_deleted", %{conn: conn} do
    user = user_fixture()
    grant = grant_fixture(user)
    other_device = grant_fixture(user)

    assert delete_account(conn, grant).status == 204

    for token <- [grant.refresh_token, other_device.refresh_token] do
      response = refresh(conn, token)
      assert assert_conforms(response, "refresh_device_session")["code"] == "account_deleted"
      assert response.status == 401
    end
  end

  test "a token that no longer worked before the deletion stays refresh_token_invalid",
       %{conn: conn} do
    user = user_fixture()
    signed_out = grant_fixture(user)
    :ok = Awrad.Accounts.sign_out_device_session(signed_out.refresh_token)

    spent = grant_fixture(user)
    assert refresh(conn, spent.refresh_token).status == 200

    assert delete_account(conn, grant_fixture(user)).status == 204

    for token <- [signed_out.refresh_token, spent.refresh_token, "never-issued"] do
      response = refresh(conn, token)

      assert assert_conforms(response, "refresh_device_session")["code"] ==
               "refresh_token_invalid"
    end
  end

  test "only token hashes are kept, until the tokens would have expired", %{conn: conn} do
    user = user_fixture()
    grant = grant_fixture(user)
    assert delete_account(conn, grant).status == 204

    [row] = Repo.all(DeletedRefreshToken)
    assert row.token_hash == :crypto.hash(:sha256, grant.refresh_token)
    assert DateTime.compare(row.expires_at, grant.session.idle_expires_at) != :gt

    assert DeletedRefreshToken.prune(DateTime.add(row.expires_at, -1)) == 0
    assert Awrad.Pruner.prune(row.expires_at) >= 1
    assert Repo.all(DeletedRefreshToken) == []

    assert assert_conforms(refresh(conn, grant.refresh_token), "refresh_device_session")[
             "code"
           ] == "refresh_token_invalid"
  end
end
