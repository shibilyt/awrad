defmodule AwradWeb.Plugs.IdempotencyTest do
  @moduledoc "Idempotency-Key details the controller tests don't cover (STYLE.md §10)."
  use AwradWeb.ConnCase, async: true

  import Awrad.AccountsFixtures

  alias Awrad.Idempotency.Record
  alias Awrad.Repo

  defp post_json(conn, path, body, headers) do
    conn |> json_conn(headers) |> post(path, Jason.encode!(body))
  end

  test "an error isn't stored: fixing the body and retrying with the same key runs", %{conn: conn} do
    key = Ecto.UUID.generate()
    email = unique_email()

    failed =
      post_json(conn, ~p"/api/v1/accounts", %{email: email, password: "short"}, [
        {"idempotency-key", key}
      ])

    assert failed.status == 422

    fixed =
      post_json(
        %{build_conn() | remote_ip: conn.remote_ip},
        ~p"/api/v1/accounts",
        %{email: email, password: valid_password()},
        [
          {"idempotency-key", key}
        ]
      )

    assert fixed.status == 202
    assert code_from_email(email)
  end

  test "stored bodies are encrypted and fingerprints are keyed hashes", %{conn: conn} do
    user = user_fixture()
    key = Ecto.UUID.generate()

    conn =
      post_json(
        conn,
        ~p"/api/v1/device_sessions",
        %{email: user.email, password: valid_password(), device: device_params()},
        [
          {"idempotency-key", key}
        ]
      )

    %{"refresh_token" => refresh_token} = json_response(conn, 201)
    record = Repo.get_by!(Record, key: key)

    assert record.scope == "POST /api/v1/device_sessions"
    refute record.body_ciphertext =~ refresh_token
    assert byte_size(record.fingerprint) == 32
  end

  test "the same key on another operation is independent", %{conn: conn} do
    key = Ecto.UUID.generate()
    email = unique_email()

    assert post_json(conn, ~p"/api/v1/accounts/resend_verification_code", %{email: email}, [
             {"idempotency-key", key}
           ]).status ==
             202

    assert post_json(
             %{build_conn() | remote_ip: conn.remote_ip},
             ~p"/api/v1/accounts/request_password_reset",
             %{email: email},
             [
               {"idempotency-key", key}
             ]
           ).status == 202
  end

  test "a result for an account deleted meanwhile isn't stored, and doesn't fail" do
    key = Ecto.UUID.generate()
    for_key = {"POST /api/v1/account/change_password", key, Ecto.UUID.generate()}

    assert Awrad.Idempotency.store(for_key, "fingerprint", 204, nil, "") == :ok
    refute Repo.get_by(Record, key: key)
  end

  test "expired results are ignored and pruned", %{conn: conn} do
    key = Ecto.UUID.generate()

    post_json(conn, ~p"/api/v1/accounts/resend_verification_code", %{email: unique_email()}, [
      {"idempotency-key", key}
    ])

    Repo.update_all(Record, set: [expires_at: DateTime.add(DateTime.utc_now(:second), -1)])
    assert Awrad.Idempotency.lookup("POST /api/v1/accounts/resend_verification_code", key) == nil
    assert Awrad.Pruner.prune() >= 1
  end
end
