defmodule Awrad.Accounts.EmailCodeTest do
  use Awrad.DataCase, async: true

  import Awrad.AccountsFixtures

  alias Awrad.Accounts.EmailCode

  defp ok, do: {:ok, :matched}

  setup do
    %{user: unconfirmed_user_fixture()}
  end

  test "a code is six digits and is stored only as a hash", %{user: user} do
    code = EmailCode.issue(user, :verify_email)

    assert code =~ ~r/\A\d{6}\z/
    row = Repo.get_by!(EmailCode, user_id: user.id, purpose: :verify_email)
    refute row.code_hash =~ code
    assert byte_size(row.code_hash) == 32
  end

  test "the right code matches once", %{user: user} do
    code = EmailCode.issue(user, :verify_email)

    assert EmailCode.consume(user, :verify_email, code, &ok/0) == {:ok, :matched}
    assert EmailCode.consume(user, :verify_email, code, &ok/0) == {:error, :code_invalid}
  end

  test "a code only works for its purpose", %{user: user} do
    code = EmailCode.issue(user, :verify_email)

    assert EmailCode.consume(user, :reset_password, code, &ok/0) == {:error, :code_invalid}
  end

  test "a new code cancels the old one", %{user: user} do
    old = EmailCode.issue(user, :verify_email)
    new = EmailCode.issue(user, :verify_email)

    if old != new do
      assert EmailCode.consume(user, :verify_email, old, &ok/0) == {:error, :code_invalid}
    end

    assert EmailCode.consume(user, :verify_email, new, &ok/0) == {:ok, :matched}
  end

  test "five wrong tries spend the code, and the tries are kept", %{user: user} do
    code = EmailCode.issue(user, :verify_email)
    wrong = if code == "000000", do: "111111", else: "000000"

    for _try <- 1..5 do
      assert EmailCode.consume(user, :verify_email, wrong, &ok/0) == {:error, :code_invalid}
    end

    assert Repo.get_by!(EmailCode, user_id: user.id).attempts == 5
    assert EmailCode.consume(user, :verify_email, code, &ok/0) == {:error, :code_invalid}
  end

  test "four wrong tries still leave the right code usable", %{user: user} do
    code = EmailCode.issue(user, :verify_email)
    wrong = if code == "000000", do: "111111", else: "000000"

    for _try <- 1..4, do: EmailCode.consume(user, :verify_email, wrong, &ok/0)

    assert EmailCode.consume(user, :verify_email, code, &ok/0) == {:ok, :matched}
  end

  test "an expired code doesn't match", %{user: user} do
    code = EmailCode.issue(user, :verify_email)
    expire(user)

    assert EmailCode.consume(user, :verify_email, code, &ok/0) == {:error, :code_invalid}
  end

  test "codes last 15 minutes", %{user: user} do
    EmailCode.issue(user, :verify_email)
    row = Repo.get_by!(EmailCode, user_id: user.id)

    assert DateTime.diff(row.expires_at, row.inserted_at, :minute) == 15
  end

  test "a failing on_match keeps the code", %{user: user} do
    code = EmailCode.issue(user, :verify_email)

    assert EmailCode.consume(user, :verify_email, code, fn -> {:error, :boom} end) ==
             {:error, :boom}

    assert EmailCode.consume(user, :verify_email, code, &ok/0) == {:ok, :matched}
  end

  test "prune deletes expired codes", %{user: user} do
    EmailCode.issue(user, :verify_email)
    expire(user)

    assert EmailCode.prune(DateTime.utc_now(:second)) == 1
  end

  defp expire(user) do
    past = DateTime.add(DateTime.utc_now(:second), -1, :second)
    Repo.update_all(from(c in EmailCode, where: c.user_id == ^user.id), set: [expires_at: past])
  end
end
