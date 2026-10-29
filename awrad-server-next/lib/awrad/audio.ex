defmodule Awrad.Audio do
  @moduledoc """
  Private recordings for custom dhikrs (slice 3c, root ADR-2026-10-29,
  `contracts/audio/v1/`, server ADR 0011). The bytes go straight between the
  client and the private R2 bucket through short-lived signed links; this
  context keeps the record of each upload, signs the links, confirms uploads,
  enforces the limits and cleans up.

  The only entry point to the context, besides `Storage` (the R2 behaviour)
  and `Cleaner` (the periodic job). Ownership is the `user_id` the caller
  authenticated; nothing here reads an account from the request.

    * `reserve/3`, `complete/3`, `download/3`, `usage/1`: the four operations;
    * `check_reference/2`, `note_references/3`: what the change queue asks;
    * `clean/1`: the cleanup job, on demand.
  """

  use Boundary, deps: [Awrad], exports: [Cleaner, Storage]

  alias Awrad.Audio.{Cleaner, Cleanup, References, Rules, Storage, Uploads}

  @typedoc "A `create_audio_upload` body, already checked against the request schema."
  @type upload_request :: %{
          asset_id: Ecto.UUID.t(),
          byte_size: non_neg_integer(),
          content_type: String.t(),
          sha256: String.t()
        }

  @typedoc """
  What an upload declared: at least its `content_type` and `sha256` (64
  lowercase hex digits), and for comparisons its `byte_size`. Any map with
  them will do (a request, a stored upload).
  """
  @type declared :: %{
          optional(:byte_size) => pos_integer(),
          required(:content_type) => String.t(),
          required(:sha256) => String.t(),
          optional(atom()) => term()
        }

  @typedoc "A pending upload's signed `PUT` link and the headers to send with it."
  @type upload :: %{
          asset_id: Ecto.UUID.t(),
          url: String.t(),
          headers: %{String.t() => String.t()},
          expires_at: DateTime.t()
        }

  @typedoc "A ready asset."
  @type asset :: %{
          asset_id: Ecto.UUID.t(),
          byte_size: pos_integer(),
          content_type: String.t(),
          created_at: DateTime.t()
        }

  @typedoc "A signed `GET` link."
  @type download :: %{url: String.t(), expires_at: DateTime.t()}

  @type reserve_result ::
          {:created | :pending, upload()}
          | {:ready, asset()}
          | {:error,
             :asset_id_in_use
             | :unsupported_audio_type
             | :invalid_size
             | :file_too_large
             | {:storage_full, non_neg_integer(), pos_integer()}}

  @type complete_result ::
          {:ok, asset()}
          | {:error, :not_found | :upload_incomplete | {:upload_mismatch, String.t()}}

  @doc """
  Reserves an upload (`create_audio_upload`): `{:created, upload}` for a new
  one, `{:pending, upload}` with a fresh link for a repeat while pending,
  `{:ready, asset}` for a repeat once ready, or the error. An `asset_id` the
  account has, or another account uses, is looked at before the upload rules.
  """
  @spec reserve(Ecto.UUID.t(), upload_request(), DateTime.t()) :: reserve_result()
  defdelegate reserve(user_id, request, now), to: Uploads

  @doc """
  Confirms an upload (`complete_audio_upload`) once its object matches.
  `:not_found` for anything but the account's pending or ready upload.
  """
  @spec complete(Ecto.UUID.t(), Ecto.UUID.t(), DateTime.t()) :: complete_result()
  defdelegate complete(user_id, asset_id, now), to: Uploads

  @doc "A signed `GET` link (`get_audio_download`) to a ready asset of the account."
  @spec download(Ecto.UUID.t(), Ecto.UUID.t(), DateTime.t()) ::
          {:ok, download()} | {:error, :not_found}
  defdelegate download(user_id, asset_id, now), to: Uploads

  @doc "Storage used (`get_audio_usage`): ready and pending uploads, and the account's limit."
  @spec usage(Ecto.UUID.t()) :: %{used_bytes: non_neg_integer(), limit_bytes: 500_000_000}
  def usage(user_id),
    do: %{used_bytes: Uploads.used_bytes(user_id), limit_bytes: Rules.limit_bytes()}

  @doc """
  Whether `byte_size` and `content_type` are a recording's: 1 to 10,000,000
  bytes, exactly `audio/mpeg` or `audio/mp4` (a custom dhikr document's
  uploaded `audio`).
  """
  @spec recording?(integer(), String.t()) :: boolean()
  def recording?(byte_size, content_type),
    do: content_type in Rules.content_types() and byte_size in 1..Rules.max_byte_size()//1

  @doc "The largest recording, in bytes (10,000,000)."
  @spec max_byte_size() :: 10_000_000
  defdelegate max_byte_size(), to: Rules

  @doc """
  The headers a client sends with its `PUT` (`upload_headers`), which its
  link is signed with: `content-type`, and `x-amz-checksum-sha256` (the
  SHA-256 in base64).
  """
  @spec upload_headers(declared()) :: %{String.t() => String.t()}
  defdelegate upload_headers(upload), to: Uploads

  @doc "`nil` when a stored object (`Storage.head/1`) is the upload's, or why it isn't."
  @spec object_mismatch(Storage.object(), declared()) :: String.t() | nil
  defdelegate object_mismatch(object, expected), to: Uploads

  @doc """
  Whether a custom dhikr document's uploaded `audio` may name its asset:
  `:ok`, `{:error, :audio_not_found}` or `{:error, {:audio_mismatch, members}}`.
  Call it inside the change queue's transaction: it locks the asset until
  the transaction ends.
  """
  @spec check_reference(Ecto.UUID.t(), map()) ::
          :ok | {:error, :audio_not_found | {:audio_mismatch, [String.t(), ...]}}
  defdelegate check_reference(user_id, audio), to: References, as: :check

  @doc "Records whether active custom dhikrs now name each asset (`asset_id => boolean`)."
  @spec note_references(Ecto.UUID.t(), %{Ecto.UUID.t() => boolean()}, DateTime.t()) :: :ok
  defdelegate note_references(user_id, referenced, now), to: References, as: :note

  @doc """
  Runs the cleanup once (`Awrad.Audio.Cleanup`): abandoned uploads,
  recordings unreferenced for 24 hours and deleted accounts' recordings.
  """
  @spec clean(DateTime.t()) :: Cleanup.result()
  def clean(now \\ DateTime.utc_now(:second)), do: Cleanup.run(now)

  @doc "An account was deleted: its recordings are cleaned up soon (`Cleaner.wake/0`)."
  @spec account_deleted() :: :ok
  defdelegate account_deleted(), to: Cleaner, as: :wake
end
