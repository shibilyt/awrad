defmodule Awrad.Accounts.RateLimiterTest do
  use Awrad.DataCase, async: true

  alias Awrad.Accounts.RateLimiter

  defp ip, do: "198.51.100.#{System.unique_integer([:positive])}"

  test "limits per IP across accounts" do
    ip = ip()

    for n <- 1..5, do: assert(RateLimiter.check(:register, ip, "a#{n}@example.com") == :ok)

    assert {:error, retry_after} = RateLimiter.check(:register, ip, "a6@example.com")
    assert retry_after in 1..3600
  end

  test "limits per account across IPs" do
    for _ <- 1..10, do: assert(RateLimiter.check(:sign_in, ip(), "same@example.com") == :ok)

    assert {:error, retry_after} = RateLimiter.check(:sign_in, ip(), "same@example.com")
    assert retry_after in 1..900
  end

  test "subjects are stored as HMACs only" do
    RateLimiter.check(:register, "203.0.113.9", "secret@example.com")

    for row <- Repo.all(RateLimiter) do
      assert byte_size(row.subject_hash) == 32
      refute row.subject_hash =~ "203.0.113.9"
    end
  end

  test "prune drops old windows" do
    RateLimiter.check(:register, ip(), nil)
    assert RateLimiter.prune(DateTime.add(DateTime.utc_now(:second), 3, :hour)) == 1
  end
end
