defmodule AwradWeb.SyncController do
  @moduledoc """
  The change queue (`contracts/api/paths/sync.yaml`, `contracts/sync/v1/`).
  Both operations run after `AccountAuth`: a bearer token (phones), or the
  cookie session with CSRF on the POST (the web), never one standing in for
  the other.

  Before anything is read or written, `X-Awrad-Account` must name the
  signed-in account: missing or not an ID is `400 malformed_request`, another
  account `409 account_mismatch`. `Idempotency-Key` is accepted and ignored:
  commands are idempotent by `command_id`.
  """

  use AwradWeb, :controller

  alias Awrad.Sync
  alias AwradWeb.{Params, SyncJSON}

  action_fallback AwradWeb.FallbackController

  @max_revision 9_007_199_254_740_991
  @default_limit 200
  @max_limit 500

  @doc "`post_sync_commands`: one receipt per command, in order, and the head revision."
  @spec commands(Plug.Conn.t(), map()) :: Plug.Conn.t() | {:error, term()}
  def commands(conn, _params) do
    with {:ok, user_id} <- account(conn),
         {:ok, %{commands: commands}} <- batch_body(conn),
         :ok <- batch(commands) do
      json(conn, SyncJSON.receipts(Sync.apply_batch(user_id, commands)))
    end
  end

  @doc "`list_sync_changes`: one page of changes after `after`."
  @spec changes(Plug.Conn.t(), map()) :: Plug.Conn.t() | {:error, term()}
  def changes(conn, params) do
    with {:ok, user_id} <- account(conn),
         {:ok, after_revision} <- integer(params, "after", 0, 0..@max_revision),
         {:ok, limit} <- integer(params, "limit", @default_limit, 1..@max_limit) do
      json(conn, SyncJSON.changes(Sync.changes(user_id, after_revision, limit)))
    end
  end

  # The signed-in account, if X-Awrad-Account names it.
  defp account(conn) do
    %{id: user_id} = conn.assigns.current_scope.user

    case get_req_header(conn, "x-awrad-account") do
      [^user_id] ->
        {:ok, user_id}

      [value] ->
        if Awrad.ID.valid?(value), do: {:error, :account_mismatch}, else: invalid_account()

      _none_or_many ->
        invalid_account()
    end
  end

  defp invalid_account, do: {:error, "X-Awrad-Account must be one lowercase account ID"}

  # The body is `{"commands": [...]}` and nothing else (400 otherwise); the
  # commands themselves are the envelope's to check (422).
  defp batch_body(conn) do
    case Params.cast(conn, commands: {:array, :required}) do
      {:ok, %{commands: commands}} -> {:ok, %{commands: commands}}
      {:ok, _missing} -> {:error, "missing field \"commands\""}
      {:error, detail} -> {:error, detail}
    end
  end

  defp batch(commands) do
    case Sync.validate_batch(commands) do
      :ok -> :ok
      {:error, errors} -> {:error, {:validation_at, errors}}
    end
  end

  # A query parameter that's a decimal integer in `range`, or `default` when absent.
  defp integer(params, name, default, range) do
    with {:ok, value} <- Map.fetch(params, name),
         true <- is_binary(value) and value =~ ~r/\A[0-9]{1,16}\z/,
         number = String.to_integer(value),
         true <- number in range do
      {:ok, number}
    else
      :error -> {:ok, default}
      false -> {:error, "#{name} must be an integer from #{range.first} to #{range.last}"}
    end
  end
end
