defmodule AwradWeb.Problem do
  @moduledoc """
  RFC 9457 problem details, the only error shape the API sends
  (`contracts/api/STYLE.md` §7).

  Clients switch on `code`; `title` and `detail` are English, for logs only.
  The codes and their statuses are those listed per operation in
  `contracts/api/` (`x-error-codes`).
  """

  import Plug.Conn

  @type field_error :: %{field: String.t(), code: String.t(), detail: String.t()}

  # code => {status, title, detail}
  @problems %{
    "unauthenticated" => {401, "Authentication required", "no valid session"},
    "invalid_credentials" => {401, "Invalid credentials", "wrong email or password"},
    "email_verification_required" =>
      {403, "Email verification required", "verify the account email first; a new code was sent"},
    "csrf_token_invalid" => {403, "CSRF token invalid", "missing or stale X-CSRF-Token"},
    "verification_code_invalid" =>
      {422, "Verification code invalid", "the code is wrong, expired or already used"},
    "reset_code_invalid" =>
      {422, "Reset code invalid", "the code is wrong, expired or already used"},
    "refresh_token_invalid" =>
      {401, "Refresh token invalid", "the refresh token is unknown or its session has ended"},
    "account_deleted" =>
      {401, "Account deleted", "the account this refresh token belonged to no longer exists"},
    "account_mismatch" =>
      {409, "Account mismatch", "X-Awrad-Account isn't the signed-in account"},
    "refresh_reuse_detected" =>
      {401, "Refresh token reused", "a spent refresh token was reused; the session is revoked"},
    "idempotency_key_reused" =>
      {422, "Idempotency key reused", "this Idempotency-Key was used with a different request"},
    "not_found" => {404, "Not found", "no such resource"},
    "email_change_code_invalid" =>
      {422, "Email change code invalid", "the code is wrong, expired or already used"},
    "email_taken" => {409, "Email taken", "the new email now belongs to another account"},
    # Audio (slice 3c, contracts/api/paths/audio.yaml). Most carry their own detail.
    "asset_id_in_use" =>
      {409, "Asset ID in use", "asset_id was already used for a different file"},
    "unsupported_audio_type" =>
      {415, "Unsupported audio type", "content_type is not audio/mpeg or audio/mp4"},
    "invalid_size" => {422, "Invalid size", "byte_size must be at least 1"},
    "file_too_large" => {413, "File too large", "byte_size is above the 10000000-byte limit"},
    "storage_full" => {422, "Storage full", "the upload would pass the account's limit"},
    "upload_incomplete" =>
      {409, "Upload incomplete", "no object has been uploaded for this asset yet"},
    "upload_mismatch" =>
      {422, "Upload mismatch", "the stored object isn't the upload that was reserved"}
  }

  # Request fields as JSON Pointers, and an English detail per field code.
  @fields %{
    email: "/email",
    password: "/password",
    new_password: "/new_password",
    current_password: "/current_password",
    new_email: "/new_email",
    code: "/code",
    installation_id: "/device/installation_id",
    device_name: "/device/name",
    platform: "/device/platform"
  }

  @field_details %{
    email_invalid: "must be an email address such as name@example.com",
    email_unchanged: "is already the account's email",
    current_password_incorrect: "is incorrect",
    password_too_short: "must be at least 12 characters",
    password_too_long: "is too long",
    password_too_common: "is too common; choose another",
    code_invalid: "must be 6 digits",
    installation_id_invalid: "must be a lowercase UUID",
    device_name_invalid: "must be 1 to 120 characters",
    platform_invalid: "must be android or ios"
  }

  @doc "Sends a problem response and halts the connection."
  @spec send_problem(Plug.Conn.t(), pos_integer(), String.t(), String.t(), String.t(), [
          field_error()
        ]) ::
          Plug.Conn.t()
  def send_problem(conn, status, code, title, detail, errors \\ []) do
    conn
    |> put_resp_content_type("application/problem+json")
    |> send_resp(status, Jason.encode_to_iodata!(body(status, code, title, detail, errors)))
    |> halt()
  end

  @doc "Sends the catalogued problem for `code` (e.g. `\"invalid_credentials\"`)."
  @spec send_code(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  def send_code(conn, code) do
    {status, title, detail} = Map.fetch!(@problems, code)
    send_problem(conn, status, code, title, detail)
  end

  @doc """
  The catalogued problem for `code` with its own `detail`, plus extension
  members next to the usual ones (STYLE.md §7), such as `storage_full`'s
  `used_bytes` and `limit_bytes`.
  """
  @spec send_code(Plug.Conn.t(), String.t(), String.t(), map()) :: Plug.Conn.t()
  def send_code(conn, code, detail, extensions \\ %{}) do
    {status, title, _detail} = Map.fetch!(@problems, code)
    body = Map.merge(extensions, body(status, code, title, detail))

    conn
    |> put_resp_content_type("application/problem+json")
    |> send_resp(status, Jason.encode_to_iodata!(body))
    |> halt()
  end

  @doc "`400 malformed_request`: bad JSON, wrong types, unknown or missing fields."
  @spec malformed(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  def malformed(conn, detail),
    do: send_problem(conn, 400, "malformed_request", "Malformed request", detail)

  @doc "`422 validation_failed` with one entry per `{field, code}`."
  @spec validation_failed(Plug.Conn.t(), [{atom(), atom()}, ...]) :: Plug.Conn.t()
  def validation_failed(conn, [_ | _] = field_errors) do
    errors =
      for {field, code} <- field_errors do
        %{
          field: Map.fetch!(@fields, field),
          code: Atom.to_string(code),
          detail: Map.fetch!(@field_details, code)
        }
      end

    [%{field: field, detail: detail} | _] = errors

    send_problem(
      conn,
      422,
      "validation_failed",
      "Request validation failed",
      "#{field} #{detail}",
      errors
    )
  end

  @doc """
  `422 validation_failed` with errors whose `field` is already a JSON Pointer
  into the request body (for nested bodies such as a sync batch).
  """
  @spec validation_failed_at(Plug.Conn.t(), [field_error(), ...]) :: Plug.Conn.t()
  def validation_failed_at(conn, [%{field: field, detail: detail} | _] = errors) do
    send_problem(
      conn,
      422,
      "validation_failed",
      "Request validation failed",
      "#{field} #{detail}",
      errors
    )
  end

  @doc "`429 rate_limited` with `Retry-After`."
  @spec rate_limited(Plug.Conn.t(), pos_integer()) :: Plug.Conn.t()
  def rate_limited(conn, retry_after) do
    conn
    |> put_resp_header("retry-after", Integer.to_string(retry_after))
    |> send_problem(
      429,
      "rate_limited",
      "Too many requests",
      "retry after #{retry_after} seconds"
    )
  end

  @doc "The problem body as a map, for renderers that encode it themselves."
  @spec body(pos_integer(), String.t(), String.t(), String.t(), [field_error()]) :: map()
  def body(status, code, title, detail, errors \\ []) do
    %{
      type: "urn:awrad:problem:#{code}",
      title: title,
      status: status,
      code: code,
      detail: detail,
      errors: errors
    }
  end
end
