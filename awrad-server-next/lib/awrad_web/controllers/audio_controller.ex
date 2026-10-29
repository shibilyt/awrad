defmodule AwradWeb.AudioController do
  @moduledoc """
  Private recordings for custom dhikrs (`contracts/api/paths/audio.yaml`,
  `contracts/audio/v1/`): reserve an upload, confirm it, get a download link,
  and the storage used. The bytes never pass through here: clients `PUT` to
  and `GET` from R2 with the signed links these return.

  Every operation runs after `AccountAuth` (a bearer token, or the cookie
  session with CSRF on the POSTs) and checks `X-Awrad-Account` before anything
  is read or written (`AwradWeb.AccountHeader`). `Idempotency-Key` is accepted
  and ignored: reserving is idempotent by `asset_id`, confirming anyway.

  A request body that breaks the request schema (a non-UUID `asset_id`, a
  `sha256` that isn't 64 lowercase hex digits, a `byte_size` outside 0 to
  2^53 - 1, a `content_type` over 255 characters, an unknown member) is
  `400 malformed_request`; the upload rules are the domain's. An `asset_id`
  path parameter that isn't an ID is `404`, like an unknown one.
  """

  use AwradWeb, :controller

  import AwradWeb.AccountHeader, only: [account: 1]

  alias Awrad.Audio
  alias AwradWeb.{AudioJSON, Params}

  action_fallback AwradWeb.FallbackController

  @max_int53 9_007_199_254_740_991
  @max_content_type 255

  @doc "`create_audio_upload`: `201` with a signed `PUT` link, or `200` for a repeat."
  @spec create_upload(Plug.Conn.t(), map()) :: Plug.Conn.t() | {:error, term()}
  def create_upload(conn, _params) do
    with {:ok, user_id} <- account(conn),
         {:ok, request} <- upload_request(conn) do
      case Audio.reserve(user_id, request, DateTime.utc_now(:second)) do
        {:created, upload} -> conn |> put_status(:created) |> json(AudioJSON.upload(upload))
        {:pending, upload} -> json(conn, AudioJSON.upload(upload))
        {:ready, asset} -> json(conn, AudioJSON.asset(asset))
        {:error, error} -> {:error, upload_problem(error, request)}
      end
    end
  end

  @doc "`complete_audio_upload`: the ready asset once the stored object matches."
  @spec complete_upload(Plug.Conn.t(), map()) :: Plug.Conn.t() | {:error, term()}
  def complete_upload(conn, %{"asset_id" => asset_id}) do
    with {:ok, user_id} <- account(conn),
         {:ok, asset_id} <- path_id(asset_id) do
      case Audio.complete(user_id, asset_id, DateTime.utc_now(:second)) do
        {:ok, asset} ->
          json(conn, AudioJSON.asset(asset))

        {:error, {:upload_mismatch, detail}} ->
          {:error, {:problem, "upload_mismatch", detail, %{}}}

        {:error, code} ->
          {:error, code}
      end
    end
  end

  @doc "`get_audio_download`: a signed `GET` link to a ready asset."
  @spec download(Plug.Conn.t(), map()) :: Plug.Conn.t() | {:error, term()}
  def download(conn, %{"asset_id" => asset_id}) do
    with {:ok, user_id} <- account(conn),
         {:ok, asset_id} <- path_id(asset_id),
         {:ok, link} <- Audio.download(user_id, asset_id, DateTime.utc_now(:second)) do
      json(conn, AudioJSON.download(link))
    end
  end

  @doc "`get_audio_usage`: bytes used, ready and pending, and the limit."
  @spec usage(Plug.Conn.t(), map()) :: Plug.Conn.t() | {:error, term()}
  def usage(conn, _params) do
    with {:ok, user_id} <- account(conn) do
      json(conn, AudioJSON.usage(Audio.usage(user_id)))
    end
  end

  defp upload_request(conn) do
    spec = [
      asset_id: {:string, :required},
      byte_size: {:integer, :required},
      content_type: {:string, :required},
      sha256: {:string, :required}
    ]

    with {:ok, body} <- Params.cast(conn, spec),
         :ok <- valid(Awrad.ID.valid?(body.asset_id), "asset_id must be a lowercase UUID"),
         :ok <- valid(body.byte_size in 0..@max_int53, "byte_size must be from 0 to 2^53 - 1"),
         :ok <-
           valid(
             length(String.to_charlist(body.content_type)) <= @max_content_type,
             "content_type must be at most 255 characters"
           ),
         :ok <-
           valid(body.sha256 =~ ~r/\A[0-9a-f]{64}\z/, "sha256 must be 64 lowercase hex digits") do
      {:ok, body}
    end
  end

  defp valid(true, _detail), do: :ok
  defp valid(false, detail), do: {:error, detail}

  defp path_id(value) do
    if Awrad.ID.valid?(value), do: {:ok, value}, else: {:error, :not_found}
  end

  defp upload_problem({:storage_full, used, limit}, request) do
    {:problem, "storage_full",
     "#{request.byte_size} more bytes would pass the account's #{limit}-byte limit",
     %{used_bytes: used, limit_bytes: limit}}
  end

  defp upload_problem(:file_too_large, request) do
    {:problem, "file_too_large",
     "byte_size #{request.byte_size} is above the #{Audio.max_byte_size()}-byte limit", %{}}
  end

  defp upload_problem(:unsupported_audio_type, request) do
    {:problem, "unsupported_audio_type",
     "content_type #{request.content_type} is not audio/mpeg or audio/mp4", %{}}
  end

  defp upload_problem(code, _request) when code in [:asset_id_in_use, :invalid_size], do: code
end
