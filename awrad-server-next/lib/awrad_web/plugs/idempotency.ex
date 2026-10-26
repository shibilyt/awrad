defmodule AwradWeb.Plugs.Idempotency do
  @moduledoc """
  `Idempotency-Key` on POST operations (`contracts/api/STYLE.md` §10, server
  ADR 0007). The header is optional; when present it must be a lowercase UUID
  (`400 malformed_request` otherwise).

    * The first successful (2xx) result for an operation and key is stored for
      24 hours with a fingerprint of the body. Errors aren't stored: a retry
      after one runs again.
    * The same key with the same body gets the stored result back
      (`mode: :replay`), or runs the operation again (`mode: :rerun`, for
      browser sign-in, whose result is a cookie that can't be replayed).
    * The same key with a different body is `422 idempotency_key_reused`.
    * For signed-in operations (after `AccountAuth`), results are per account:
      another account's key never matches, and an account's results are
      deleted with it.

  `refresh_device_session` doesn't use this plug: it requires the key and
  gives it stricter, 60-second semantics (`Awrad.Accounts.DeviceSessions`).
  """

  @behaviour Plug

  import Plug.Conn

  alias Awrad.Idempotency
  alias Awrad.Idempotency.Record
  alias AwradWeb.Problem

  @uuid ~r/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/

  @impl Plug
  def init(opts), do: Keyword.validate!(opts, mode: :replay)

  @impl Plug
  def call(conn, opts) do
    case key(conn) do
      :none -> conn
      {:ok, key} -> handle(conn, key, Keyword.fetch!(opts, :mode))
      :error -> Problem.malformed(conn, "Idempotency-Key must be a lowercase UUID")
    end
  end

  @doc "The request's `Idempotency-Key`: `:none`, `{:ok, key}`, or `:error` when malformed or repeated."
  @spec key(Plug.Conn.t()) :: :none | {:ok, String.t()} | :error
  def key(conn) do
    case get_req_header(conn, "idempotency-key") do
      [] -> :none
      [key] -> if Regex.match?(@uuid, key), do: {:ok, key}, else: :error
      _many -> :error
    end
  end

  defp handle(conn, key, mode) do
    scope = conn.method <> " " <> conn.request_path
    user_id = user_id(conn)
    fingerprint = Idempotency.fingerprint(conn.body_params)

    case Idempotency.lookup(scope, key, user_id) do
      nil ->
        register_before_send(conn, &store(&1, {scope, key, user_id}, fingerprint, mode))

      %Record{fingerprint: ^fingerprint} = record ->
        if mode == :replay, do: replay(conn, record), else: conn

      %Record{} ->
        Problem.send_code(conn, "idempotency_key_reused")
    end
  end

  defp store(%Plug.Conn{status: status} = conn, for_key, fingerprint, mode)
       when status in 200..299 do
    {content_type, body} =
      case mode do
        :replay -> {content_type(conn), IO.iodata_to_binary(conn.resp_body || "")}
        :rerun -> {nil, nil}
      end

    :ok = Idempotency.store(for_key, fingerprint, status, content_type, body)
    conn
  end

  defp store(conn, _for_key, _fingerprint, _mode), do: conn

  # Signed-in operations keep their results per account; this plug then runs
  # after authentication.
  defp user_id(conn) do
    case conn.assigns[:current_scope] do
      %{user: %{id: id}} -> id
      _public -> nil
    end
  end

  # The body is this server's own stored JSON response, sent with its stored
  # content type, never request input reflected back.
  # sobelow_skip ["XSS.SendResp"]
  defp replay(conn, record) do
    case Idempotency.body(record) do
      {:ok, body} ->
        conn
        |> put_content_type(record.content_type)
        |> send_resp(record.status, body)
        |> halt()

      :error ->
        # Undecryptable (e.g. the encryption secret rotated): run the request again.
        conn
    end
  end

  defp put_content_type(conn, nil), do: conn

  defp put_content_type(conn, content_type),
    do: put_resp_header(conn, "content-type", content_type)

  defp content_type(conn) do
    case get_resp_header(conn, "content-type") do
      [content_type | _] -> content_type
      [] -> nil
    end
  end
end
