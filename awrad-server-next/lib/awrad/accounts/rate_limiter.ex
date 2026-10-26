defmodule Awrad.Accounts.RateLimiter do
  @moduledoc """
  Fixed-window rate limits for account actions, stored in Postgres
  (`auth_rate_limits`, server ADR 0006), so every node shares them and they
  survive restarts.

  Each action is limited per client IP and per account (the normalised email,
  or the account ID). Subjects are stored only as HMACs. The limits follow the
  frozen server's (`awrad_server` `Api.AuthController`).
  """

  use Ecto.Schema

  import Ecto.Query

  alias Awrad.{Repo, Secrets}

  @hour 3600
  @quarter 900

  # action => {per-IP {limit, window seconds}, per-account {limit, window seconds}}
  @limits %{
    register: {{5, @hour}, {5, @hour}},
    verify_email: {{10, @hour}, {10, @hour}},
    resend_verification_code: {{5, @hour}, {5, @hour}},
    request_password_reset: {{5, @hour}, {5, @hour}},
    reset_password: {{10, @hour}, {10, @hour}},
    sign_in: {{30, @quarter}, {10, @quarter}},
    refresh: {{60, @quarter}, {60, @quarter}},
    # Fresh verification codes sent by a sign-in to an unverified account.
    verification_email: {{5, @hour}, {5, @hour}}
  }

  @type action ::
          :register
          | :verify_email
          | :resend_verification_code
          | :request_password_reset
          | :reset_password
          | :sign_in
          | :refresh
          | :verification_email

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "auth_rate_limits" do
    field :scope, :string
    field :subject_hash, :binary
    field :window_started_at, :utc_datetime
    field :count, :integer, default: 1

    timestamps(type: :utc_datetime, inserted_at: false)
  end

  @doc """
  Counts one `action` for the client `ip` and, when given, the `account`
  subject. Returns `:ok`, or `{:error, retry_after_seconds}` once either limit
  is exceeded.
  """
  @spec check(action(), String.t() | nil, String.t() | nil) :: :ok | {:error, pos_integer()}
  def check(action, ip, account) do
    {ip_limit, account_limit} = Map.fetch!(@limits, action)

    with :ok <- hit("#{action}:ip", ip, ip_limit) do
      hit("#{action}:account", account, account_limit)
    end
  end

  @doc "Deletes windows that ended before `now`. Returns how many."
  @spec prune(DateTime.t()) :: non_neg_integer()
  def prune(now) do
    {count, _} =
      Repo.delete_all(
        from(r in __MODULE__,
          where: r.window_started_at < ^DateTime.add(now, -@hour * 2, :second)
        )
      )

    count
  end

  defp hit(_scope, nil, _limit), do: :ok

  defp hit(scope, subject, {limit, window}) do
    now = DateTime.utc_now(:second)
    unix = DateTime.to_unix(now)
    window_started_at = DateTime.from_unix!(unix - rem(unix, window))

    row = %__MODULE__{
      scope: scope,
      subject_hash: Secrets.hmac("rate_limit", [scope, ":", String.downcase(subject)]),
      window_started_at: window_started_at,
      count: 1,
      updated_at: now
    }

    %{count: count} =
      Repo.insert!(row,
        on_conflict: [inc: [count: 1], set: [updated_at: now]],
        conflict_target: [:scope, :subject_hash, :window_started_at],
        returning: [:count]
      )

    if count <= limit, do: :ok, else: {:error, window - rem(unix, window)}
  end
end
