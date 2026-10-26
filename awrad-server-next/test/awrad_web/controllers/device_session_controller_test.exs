defmodule AwradWeb.DeviceSessionControllerTest do
  @moduledoc "Mobile sign-in, refresh (retry and replay) and sign-out, against contracts/api/paths/device_sessions.yaml."
  use AwradWeb.ConnCase, async: true

  import Awrad.AccountsFixtures
  import AwradWeb.Contract

  alias Awrad.Accounts.DeviceSession
  alias Awrad.Repo

  defp post_json(conn, path, body, headers \\ []) do
    conn |> json_conn(headers) |> post(path, Jason.encode!(body))
  end

  defp fresh(conn), do: %{build_conn() | remote_ip: conn.remote_ip}

  defp sign_in(conn, user, device \\ device_params()) do
    post_json(conn, ~p"/api/v1/device_sessions", %{
      email: user.email,
      password: valid_password(),
      device: device
    })
  end

  defp refresh(conn, refresh_token, key) do
    post_json(conn, ~p"/api/v1/device_sessions/refresh", %{refresh_token: refresh_token}, [
      {"idempotency-key", key}
    ])
  end

  describe "create_device_session" do
    test "201 with the account, session and tokens", %{conn: conn} do
      user = user_fixture()
      conn = sign_in(conn, user)

      body = assert_conforms(conn, "create_device_session")
      assert conn.status == 201

      assert body["account"] == %{
               "id" => user.id,
               "email" => user.email,
               "created_at" => DateTime.to_iso8601(user.inserted_at)
             }

      assert body["session"]["device_name"] == "Pixel 9"
      assert body["session"]["platform"] == "android"

      bearer =
        conn |> fresh() |> put_req_header("authorization", "Bearer " <> body["access_token"])

      assert get(bearer, ~p"/api/v1/account").status == 200
    end

    test "401 invalid_credentials for a wrong password or an unknown email", %{conn: conn} do
      user = user_fixture()

      for body <- [
            %{email: user.email, password: "the wrong passphrase", device: device_params()},
            %{email: unique_email(), password: valid_password(), device: device_params()}
          ] do
        conn = post_json(fresh(conn), ~p"/api/v1/device_sessions", body)
        assert assert_conforms(conn, "create_device_session")["code"] == "invalid_credentials"
      end
    end

    test "403 email_verification_required for an unverified account, with a fresh code emailed",
         %{conn: conn} do
      user = unconfirmed_user_fixture()

      conn = sign_in(conn, user)

      assert assert_conforms(conn, "create_device_session")["code"] ==
               "email_verification_required"

      assert conn.status == 403
      assert code_from_email(user.email)
      assert Repo.all(DeviceSession) == []
    end

    test "an unverified account gets at most 5 fresh codes an hour from sign-in", %{conn: conn} do
      user = unconfirmed_user_fixture()

      for _ <- 1..6, do: assert(sign_in(fresh(conn), user).status == 403)

      for _ <- 1..5, do: code_from_email(user.email)
      refute_email()
    end

    test "a wrong password on an unverified account is just invalid_credentials, no email", %{
      conn: conn
    } do
      user = unconfirmed_user_fixture()

      conn =
        post_json(conn, ~p"/api/v1/device_sessions", %{
          email: user.email,
          password: "not the passphrase",
          device: device_params()
        })

      assert assert_conforms(conn, "create_device_session")["code"] == "invalid_credentials"
      refute_email()
    end

    test "422 validation_failed for a bad device or email", %{conn: conn} do
      user = user_fixture()
      device = %{"installation_id" => "NOT-A-UUID", "name" => "", "platform" => "windows"}

      conn =
        post_json(conn, ~p"/api/v1/device_sessions", %{
          email: user.email,
          password: valid_password(),
          device: device
        })

      body = assert_conforms(conn, "create_device_session")
      assert body["code"] == "validation_failed"

      assert Enum.map(body["errors"], & &1["field"]) == [
               "/device/installation_id",
               "/device/name",
               "/device/platform"
             ]

      conn =
        post_json(fresh(conn), ~p"/api/v1/device_sessions", %{
          email: "x",
          password: "y",
          device: device_params()
        })

      assert [%{"field" => "/email", "code" => "email_invalid"}] =
               assert_conforms(conn, "create_device_session")["errors"]
    end

    test "400 for an unknown device field", %{conn: conn} do
      user = user_fixture()
      conn = sign_in(conn, user, Map.put(device_params(), "model", "Pixel"))

      body = assert_conforms(conn, "create_device_session")
      assert body["code"] == "malformed_request"
      assert body["detail"] =~ "device/model"
    end

    test "429 after 10 sign-ins for one account in 15 minutes", %{conn: conn} do
      user = user_fixture()
      for _ <- 1..10, do: sign_in(fresh(conn), user)

      conn = sign_in(fresh(conn), user)
      assert assert_conforms(conn, "create_device_session")["code"] == "rate_limited"
      assert get_resp_header(conn, "retry-after") != []
    end

    test "a repeated Idempotency-Key replays the same grant", %{conn: conn} do
      user = user_fixture()
      key = Ecto.UUID.generate()
      body = %{email: user.email, password: valid_password(), device: device_params()}

      first = post_json(conn, ~p"/api/v1/device_sessions", body, [{"idempotency-key", key}])

      repeat =
        post_json(fresh(conn), ~p"/api/v1/device_sessions", body, [{"idempotency-key", key}])

      assert assert_conforms(repeat, "create_device_session") == Jason.decode!(first.resp_body)
      assert Repo.aggregate(DeviceSession, :count) == 1
    end
  end

  describe "refresh_device_session" do
    setup %{conn: conn} do
      user = user_fixture()
      %{grant: conn |> sign_in(user) |> json_response(201)}
    end

    test "200 with new tokens", %{conn: conn, grant: grant} do
      conn = refresh(conn, grant["refresh_token"], Ecto.UUID.generate())

      body = assert_conforms(conn, "refresh_device_session")
      assert conn.status == 200
      assert body["refresh_token"] != grant["refresh_token"]
      assert body["session"]["id"] == grant["session"]["id"]
    end

    test "a retry with the same key returns the same tokens (a lost response doesn't sign out)",
         %{conn: conn, grant: grant} do
      key = Ecto.UUID.generate()

      first = refresh(conn, grant["refresh_token"], key)
      retry = refresh(fresh(conn), grant["refresh_token"], key)

      assert assert_conforms(retry, "refresh_device_session") == Jason.decode!(first.resp_body)
      # And the session lives on.
      next =
        refresh(
          fresh(conn),
          Jason.decode!(first.resp_body)["refresh_token"],
          Ecto.UUID.generate()
        )

      assert next.status == 200
    end

    test "reusing a spent token with another key is 401 refresh_reuse_detected and revokes the session",
         %{conn: conn, grant: grant} do
      first = refresh(conn, grant["refresh_token"], Ecto.UUID.generate())
      replay = refresh(fresh(conn), grant["refresh_token"], Ecto.UUID.generate())

      assert assert_conforms(replay, "refresh_device_session")["code"] == "refresh_reuse_detected"
      assert replay.status == 401

      successor =
        refresh(
          fresh(conn),
          Jason.decode!(first.resp_body)["refresh_token"],
          Ecto.UUID.generate()
        )

      assert assert_conforms(successor, "refresh_device_session")["code"] ==
               "refresh_token_invalid"

      bearer =
        conn |> fresh() |> put_req_header("authorization", "Bearer " <> grant["access_token"])

      assert get(bearer, ~p"/api/v1/account").status == 401
    end

    test "401 refresh_token_invalid for an unknown token", %{conn: conn} do
      conn = refresh(conn, "an-unknown-refresh-token-value", Ecto.UUID.generate())
      assert assert_conforms(conn, "refresh_device_session")["code"] == "refresh_token_invalid"
    end

    test "422 idempotency_key_reused when the key already rotated another token", %{
      conn: conn,
      grant: grant
    } do
      other = conn |> fresh() |> sign_in(user_fixture()) |> json_response(201)
      key = Ecto.UUID.generate()
      refresh(fresh(conn), grant["refresh_token"], key)

      conn = refresh(fresh(conn), other["refresh_token"], key)
      assert assert_conforms(conn, "refresh_device_session")["code"] == "idempotency_key_reused"
    end

    test "400 without an Idempotency-Key, or with a malformed one", %{conn: conn, grant: grant} do
      missing =
        post_json(conn, ~p"/api/v1/device_sessions/refresh", %{
          refresh_token: grant["refresh_token"]
        })

      assert assert_conforms(missing, "refresh_device_session")["code"] == "malformed_request"

      malformed = refresh(fresh(conn), grant["refresh_token"], "ABC")
      assert assert_conforms(malformed, "refresh_device_session")["code"] == "malformed_request"
      # The token wasn't spent.
      assert refresh(fresh(conn), grant["refresh_token"], Ecto.UUID.generate()).status == 200
    end

    test "429 after 60 refreshes from one IP in 15 minutes", %{conn: conn} do
      for _ <- 1..60, do: refresh(fresh(conn), "unknown-refresh-token-0000", Ecto.UUID.generate())

      conn = refresh(fresh(conn), "unknown-refresh-token-0000", Ecto.UUID.generate())
      assert assert_conforms(conn, "refresh_device_session")["code"] == "rate_limited"
    end
  end

  describe "sign_out_device_session" do
    test "204 and the session is revoked; again 204", %{conn: conn} do
      grant = conn |> sign_in(user_fixture()) |> json_response(201)

      for _ <- 1..2 do
        conn =
          post_json(fresh(conn), ~p"/api/v1/device_sessions/sign_out", %{
            refresh_token: grant["refresh_token"]
          })

        assert assert_conforms(conn, "sign_out_device_session") == nil
        assert conn.status == 204
      end

      assert %DeviceSession{revoke_reason: "signed_out"} =
               Repo.get!(DeviceSession, grant["session"]["id"])
    end

    test "204 for an unknown token", %{conn: conn} do
      conn =
        post_json(conn, ~p"/api/v1/device_sessions/sign_out", %{
          refresh_token: "an-unknown-refresh-token"
        })

      assert assert_conforms(conn, "sign_out_device_session") == nil
    end

    test "400 for a malformed body or Idempotency-Key", %{conn: conn} do
      conn1 = post_json(conn, ~p"/api/v1/device_sessions/sign_out", %{token: "x"})
      assert assert_conforms(conn1, "sign_out_device_session")["code"] == "malformed_request"

      conn2 =
        post_json(fresh(conn), ~p"/api/v1/device_sessions/sign_out", %{refresh_token: "x"}, [
          {"idempotency-key", "1"}
        ])

      assert assert_conforms(conn2, "sign_out_device_session")["code"] == "malformed_request"
    end
  end
end
