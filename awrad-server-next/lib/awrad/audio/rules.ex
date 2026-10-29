defmodule Awrad.Audio.Rules do
  @moduledoc """
  Whether an account may upload a recording (`contracts/audio/v1/README.md`,
  "Limits"; the spec is `fixtures/audio_upload_validity.json`). The checks run
  in this order, and the first failure answers:

    1. the type, exactly `audio/mpeg` or `audio/mp4`: `unsupported_audio_type`;
    2. the size: below 1 is `invalid_size`, above 10,000,000 `file_too_large`;
    3. the quota: `used_bytes + byte_size` above 500,000,000 is `storage_full`
       (equal is allowed).

  Limits are decimal bytes. The same values bound an uploaded recording in a
  custom dhikr document (`Awrad.Audio.document_audio?/1`).
  """

  @content_types ~w(audio/mpeg audio/mp4)
  @max_byte_size 10_000_000
  @limit_bytes 500_000_000

  @type error :: :unsupported_audio_type | :invalid_size | :file_too_large | :storage_full

  @doc "The media types an upload may have, exactly as written."
  @spec content_types() :: [String.t(), ...]
  def content_types, do: @content_types

  @doc "The largest file, in bytes."
  @spec max_byte_size() :: 10_000_000
  def max_byte_size, do: @max_byte_size

  @doc "The bytes one account may hold, ready and pending together."
  @spec limit_bytes() :: 500_000_000
  def limit_bytes, do: @limit_bytes

  @doc "`:ok`, or the first rule an upload of `byte_size` and `content_type` breaks with `used_bytes` held."
  @spec check(non_neg_integer(), String.t(), non_neg_integer()) :: :ok | {:error, error()}
  def check(byte_size, content_type, used_bytes) do
    cond do
      content_type not in @content_types -> {:error, :unsupported_audio_type}
      byte_size < 1 -> {:error, :invalid_size}
      byte_size > @max_byte_size -> {:error, :file_too_large}
      used_bytes + byte_size > @limit_bytes -> {:error, :storage_full}
      true -> :ok
    end
  end
end
