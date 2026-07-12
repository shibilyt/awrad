defmodule AwradApi.Accounts.AuthRateLimiter do
  alias AwradApi.Accounts.AuthRateLimit
  alias AwradApi.Repo

  @spec allow?(String.t(), String.t(), pos_integer(), pos_integer()) ::
          {:ok, non_neg_integer()} | {:error, pos_integer()}
  def allow?(scope, subject, limit, window_seconds) do
    now = DateTime.utc_now(:second)
    unix = DateTime.to_unix(now)
    window_start = DateTime.from_unix!(unix - rem(unix, window_seconds))
    subject_hash = subject_hash(subject)

    changeset =
      AuthRateLimit.changeset(%AuthRateLimit{}, %{
        scope: scope,
        subject_hash: subject_hash,
        window_started_at: window_start,
        count: 1
      })

    {:ok, row} =
      Repo.insert(changeset,
        on_conflict: [inc: [count: 1], set: [updated_at: now]],
        conflict_target: [:scope, :subject_hash, :window_started_at],
        returning: true
      )

    if row.count <= limit do
      {:ok, limit - row.count}
    else
      retry_after = window_seconds - rem(unix, window_seconds)
      {:error, retry_after}
    end
  end

  def subject_hash(subject) do
    pepper = Application.fetch_env!(:awrad_api, __MODULE__)[:pepper]
    :crypto.mac(:hmac, :sha256, pepper, String.downcase(String.trim(subject)))
  end
end
