defmodule Awrad.Accounts.DeviceSessionsTest do
  @moduledoc "Device sessions, refresh rotation with retry and reuse detection, and access tokens."
  use Awrad.DataCase, async: true

  import Awrad.AccountsFixtures

  alias Awrad.Accounts.{AccessToken, DeviceSession, DeviceSessions, RefreshToken}

  setup do
    user = user_fixture()
    %{user: user, grant: grant_fixture(user)}
  end

  describe "create/2" do
    test "starts a 30-day idle, 180-day absolute session", %{grant: grant} do
      session = grant.session

      assert DateTime.diff(session.idle_expires_at, session.inserted_at, :day) == 30
      assert DateTime.diff(session.absolute_expires_at, session.inserted_at, :day) == 180
      assert DateTime.diff(grant.access_token_expires_at, DateTime.utc_now(), :second) in 895..900
    end

    test "stores the installation ID only as an HMAC", %{user: user} do
      device = device()
      grant = grant_fixture(user, device)

      hash = Repo.get!(DeviceSession, grant.session.id).installation_hash
      assert byte_size(hash) == 32
      refute hash =~ device.installation_id
    end

    test "signing in again from the same installation replaces its session", %{user: user} do
      device = device()
      first = grant_fixture(user, device)
      second = grant_fixture(user, device)

      assert %DeviceSession{revoked_at: %DateTime{}, revoke_reason: "replaced"} =
               Repo.get!(DeviceSession, first.session.id)

      assert Repo.get!(DeviceSession, second.session.id).revoked_at == nil

      assert DeviceSessions.refresh(first.refresh_token, Awrad.UUIDv7.generate()) ==
               {:error, :refresh_token_invalid}

      assert DeviceSessions.identify(first.access_token) == :error
    end

    test "other installations keep their sessions", %{user: user, grant: grant} do
      grant_fixture(user)

      assert Repo.get!(DeviceSession, grant.session.id).revoked_at == nil
    end
  end

  describe "refresh/2" do
    test "rotates: new tokens, the old refresh token is spent", %{grant: grant} do
      key = Awrad.UUIDv7.generate()

      assert {:ok, next} = DeviceSessions.refresh(grant.refresh_token, key)
      assert next.refresh_token != grant.refresh_token
      assert {:ok, _user, _session} = DeviceSessions.identify(next.access_token)

      assert Repo.get_by!(RefreshToken, token_hash: :crypto.hash(:sha256, grant.refresh_token)).used_at
    end

    test "a retry with the same key within 60 seconds returns the same tokens", %{grant: grant} do
      key = Awrad.UUIDv7.generate()

      assert {:ok, first} = DeviceSessions.refresh(grant.refresh_token, key)
      assert {:ok, retry} = DeviceSessions.refresh(grant.refresh_token, key)

      assert retry.refresh_token == first.refresh_token
      assert retry.access_token == first.access_token
      assert retry.access_token_expires_at == first.access_token_expires_at
      assert retry.session.id == first.session.id
      # The session is still live and its successor token works.
      assert {:ok, _} = DeviceSessions.refresh(first.refresh_token, Awrad.UUIDv7.generate())
    end

    test "the same key after 60 seconds is reuse: the session is revoked", %{grant: grant} do
      key = Awrad.UUIDv7.generate()
      {:ok, next} = DeviceSessions.refresh(grant.refresh_token, key)

      Repo.update_all(RefreshToken,
        set: [retry_expires_at: DateTime.add(DateTime.utc_now(:second), -1)]
      )

      assert DeviceSessions.refresh(grant.refresh_token, key) == {:error, :refresh_reuse_detected}
      assert_revoked(grant.session.id, "refresh_reuse")

      assert DeviceSessions.refresh(next.refresh_token, Awrad.UUIDv7.generate()) ==
               {:error, :refresh_token_invalid}

      assert DeviceSessions.identify(next.access_token) == :error
    end

    test "a spent token with another key is reuse: the session is revoked", %{grant: grant} do
      {:ok, next} = DeviceSessions.refresh(grant.refresh_token, Awrad.UUIDv7.generate())

      assert DeviceSessions.refresh(grant.refresh_token, Awrad.UUIDv7.generate()) ==
               {:error, :refresh_reuse_detected}

      assert_revoked(grant.session.id, "refresh_reuse")

      assert DeviceSessions.refresh(next.refresh_token, Awrad.UUIDv7.generate()) ==
               {:error, :refresh_token_invalid}
    end

    test "a key that already rotated another token is idempotency_key_reused", %{
      user: user,
      grant: grant
    } do
      other = grant_fixture(user)
      key = Awrad.UUIDv7.generate()
      {:ok, _} = DeviceSessions.refresh(grant.refresh_token, key)

      assert DeviceSessions.refresh(other.refresh_token, key) == {:error, :idempotency_key_reused}
      # Nothing was spent or revoked.
      assert {:ok, _} = DeviceSessions.refresh(other.refresh_token, Awrad.UUIDv7.generate())
    end

    test "an unknown token is invalid" do
      assert DeviceSessions.refresh("not-a-real-refresh-token", Awrad.UUIDv7.generate()) ==
               {:error, :refresh_token_invalid}
    end

    test "moves the idle expiry, never past the absolute one", %{grant: grant} do
      soon = DateTime.add(DateTime.utc_now(:second), 10, :day)
      Repo.update_all(DeviceSession, set: [absolute_expires_at: soon])

      {:ok, next} = DeviceSessions.refresh(grant.refresh_token, Awrad.UUIDv7.generate())
      assert next.session.idle_expires_at == soon
    end

    test "an idle-expired session can't refresh", %{grant: grant} do
      expire(:idle_expires_at)

      assert DeviceSessions.refresh(grant.refresh_token, Awrad.UUIDv7.generate()) ==
               {:error, :refresh_token_invalid}

      assert DeviceSessions.identify(grant.access_token) == :error
    end

    test "an absolute-expired session can't refresh", %{grant: grant} do
      expire(:absolute_expires_at)

      assert DeviceSessions.refresh(grant.refresh_token, Awrad.UUIDv7.generate()) ==
               {:error, :refresh_token_invalid}
    end
  end

  describe "sign_out/1" do
    test "revokes the session and its tokens", %{grant: grant} do
      assert DeviceSessions.sign_out(grant.refresh_token) == :ok

      assert_revoked(grant.session.id, "signed_out")
      assert DeviceSessions.identify(grant.access_token) == :error

      assert DeviceSessions.refresh(grant.refresh_token, Awrad.UUIDv7.generate()) ==
               {:error, :refresh_token_invalid}
    end

    test "works with a spent token of the session too", %{grant: grant} do
      {:ok, _next} = DeviceSessions.refresh(grant.refresh_token, Awrad.UUIDv7.generate())

      assert DeviceSessions.sign_out(grant.refresh_token) == :ok
      assert_revoked(grant.session.id, "signed_out")
    end

    test "ignores unknown tokens" do
      assert DeviceSessions.sign_out("unknown-refresh-token-value") == :ok
    end
  end

  describe "identify/1" do
    test "returns the account and session", %{user: user, grant: grant} do
      assert {:ok, found, session} = DeviceSessions.identify(grant.access_token)
      assert found.id == user.id
      assert session.id == grant.session.id
    end

    test "rejects a token signed with another key, alg none, or garbage", %{grant: grant} do
      [header, payload, _signature] = String.split(grant.access_token, ".")
      forged = Joken.Signer.create("HS256", "another-secret-of-sufficient-length-000")
      {:ok, claims} = Joken.peek_claims(grant.access_token)
      {:ok, other_key, _} = Joken.encode_and_sign(claims, forged)

      none =
        Base.url_encode64(~s({"alg":"none","typ":"JWT"}), padding: false) <> "." <> payload <> "."

      assert DeviceSessions.identify(other_key) == :error
      assert DeviceSessions.identify(none) == :error
      assert DeviceSessions.identify(header <> "." <> payload <> ".AAAA") == :error
      assert DeviceSessions.identify("garbage") == :error
    end

    test "rejects an expired token", %{user: user, grant: grant} do
      signer =
        Joken.Signer.create(
          "HS256",
          Application.fetch_env!(:awrad, Awrad.Secrets)[:access_token_secret]
        )

      past = Joken.current_time() - 60

      {:ok, expired, _} =
        Joken.encode_and_sign(
          %{
            "sub" => user.id,
            "sid" => grant.session.id,
            "exp" => past,
            "iss" => "awrad",
            "aud" => "awrad-mobile"
          },
          signer
        )

      assert DeviceSessions.identify(expired) == :error
    end

    test "an account that isn't verified can't use its token", %{user: user, grant: grant} do
      Repo.update_all(from(u in Awrad.Accounts.User, where: u.id == ^user.id),
        set: [confirmed_at: nil]
      )

      assert DeviceSessions.identify(grant.access_token) == :error
    end

    test "issues tokens with the documented claims", %{grant: grant} do
      {:ok, claims} = Joken.peek_claims(grant.access_token)

      assert %{"iss" => "awrad", "aud" => "awrad-mobile", "sid" => sid, "sub" => _, "jti" => _} =
               claims

      assert sid == grant.session.id
      assert {:ok, _} = AccessToken.verify(grant.access_token)
    end
  end

  test "revoke_all/2 revokes every live session", %{user: user, grant: grant} do
    other = grant_fixture(user)

    :ok = DeviceSessions.revoke_all(user, "password_reset")
    assert_revoked(grant.session.id, "password_reset")
    assert_revoked(other.session.id, "password_reset")
  end

  defp assert_revoked(session_id, reason) do
    assert %DeviceSession{revoked_at: %DateTime{}, revoke_reason: ^reason} =
             Repo.get!(DeviceSession, session_id)

    assert Repo.all(
             from t in RefreshToken,
               where: t.device_session_id == ^session_id and is_nil(t.revoked_at)
           ) ==
             []
  end

  defp expire(field) do
    Repo.update_all(DeviceSession, set: [{field, DateTime.add(DateTime.utc_now(:second), -1)}])
  end
end
