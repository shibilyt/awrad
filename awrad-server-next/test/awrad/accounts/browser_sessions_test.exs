defmodule Awrad.Accounts.BrowserSessionsTest do
  @moduledoc """
  Browser session tokens as account sessions (slice 2b): `last_seen_at`
  throttling, and reissue in place with a short grace for the replaced token.
  """
  use AwradWeb.ConnCase, async: true

  import Awrad.AccountsFixtures
  import Ecto.Query

  alias Awrad.Accounts
  alias Awrad.Accounts.{BrowserSessions, UserToken}
  alias Awrad.Repo
  alias AwradWeb.UserAuth

  defp row(token), do: Repo.one!(from(t in UserToken, where: t.token == ^token))

  defp shift(token, fields) do
    now = DateTime.utc_now(:second)
    set = for {field, seconds} <- fields, do: {field, DateTime.add(now, seconds, :second)}
    Repo.update_all(from(t in UserToken, where: t.token == ^token), set: set)
  end

  setup do
    user = user_fixture()
    %{user: user, token: Accounts.generate_user_session_token(user, "Firefox on Linux")}
  end

  describe "identify/1" do
    test "updates last_seen_at at most every 5 minutes", %{token: token} do
      shift(token, last_seen_at: -240)
      before = row(token).last_seen_at
      assert {_user, _session} = BrowserSessions.identify(token)
      assert row(token).last_seen_at == before

      shift(token, last_seen_at: -301)
      assert {_user, _session} = BrowserSessions.identify(token)
      assert DateTime.diff(DateTime.utc_now(:second), row(token).last_seen_at) <= 1
    end

    test "an expired token is nobody's", %{token: token} do
      shift(token, inserted_at: -15 * 86_400)
      assert BrowserSessions.identify(token) == nil
    end
  end

  describe "reissue/2" do
    test "replaces the token in place; the old one works for a minute only", ctx do
      %UserToken{id: id, name: name, authenticated_at: signed_in_at} = row(ctx.token)
      new = BrowserSessions.reissue(id, ctx.token)

      assert %UserToken{id: ^id, name: ^name, authenticated_at: ^signed_in_at} = row(new)
      assert {_user, %{id: ^id, token: ^new}} = BrowserSessions.identify(new)
      assert {_user, %{id: ^id, token: ^new}} = BrowserSessions.identify(ctx.token)

      Repo.update_all(from(t in UserToken, where: t.id == ^id),
        set: [previous_token_valid_until: DateTime.add(DateTime.utc_now(:second), -1)]
      )

      assert BrowserSessions.identify(ctx.token) == nil
      assert BrowserSessions.identify(new)
    end

    test "a concurrent reissue gets the token the first one made", %{token: token} do
      %UserToken{id: id} = row(token)
      first = BrowserSessions.reissue(id, token)
      assert BrowserSessions.reissue(id, token) == first
    end

    test "signing out with either token ends the session", %{token: token} do
      %UserToken{id: id} = row(token)
      new = BrowserSessions.reissue(id, token)
      :ok = BrowserSessions.delete_token(token)
      assert BrowserSessions.identify(new) == nil
    end
  end

  describe "a week-old browser session" do
    test "gets a new token in the same session; the old cookie moves on to it", %{conn: conn} do
      user = user_fixture()
      {browser, csrf} = sign_in_browser(conn, user)

      %UserToken{id: id, token: old} =
        Repo.one!(from(t in UserToken, where: t.user_id == ^user.id))

      shift(old, inserted_at: -8 * 86_400)

      reissued = browser |> browser_request(csrf) |> get(~p"/api/v1/account")
      assert reissued.status == 200
      assert %{max_age: 1_209_600} = reissued.resp_cookies[UserAuth.remember_me_cookie()]
      assert [%UserToken{id: ^id, token: new}] = Repo.all(where(UserToken, user_id: ^user.id))
      assert new != old

      # A request sent with the old cookie at the same time still works, and
      # takes the current token.
      late = browser |> browser_request(csrf) |> get(~p"/api/v1/account")
      assert late.status == 200
      assert late.resp_cookies[UserAuth.remember_me_cookie()]
      assert Repo.aggregate(where(UserToken, user_id: ^user.id), :count) == 1

      # The new cookie, with the same CSRF token, keeps working.
      after_reissue = late |> browser_request(csrf) |> get(~p"/api/v1/account")
      assert after_reissue.status == 200
    end
  end
end
