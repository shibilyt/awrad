defmodule Awrad.Secrets do
  @moduledoc """
  The server-side secrets accounts need, read from `config :awrad, Awrad.Secrets`
  (dev and test values in `config/`, production values from the environment in
  `config/runtime.exs`):

    * `access_token_secret` signs mobile access tokens (HS256);
    * `hmac_pepper` keys every HMAC: installation IDs, email codes, rate-limit
      subjects and idempotency fingerprints, so a database dump alone can't
      reverse them;
    * `encryption_secret` encrypts what must be read back later: refresh retries
      and stored idempotent responses.

  A sub-boundary of `Awrad` that `Awrad` doesn't re-export: only the domain
  contexts that list it as a dependency can read the secrets, never `AwradWeb`.
  """

  use Boundary, deps: [], exports: []

  alias Plug.Crypto.MessageEncryptor

  @doc "The HS256 key for access tokens."
  @spec access_token_secret() :: String.t()
  def access_token_secret, do: fetch!(:access_token_secret)

  @doc "HMAC-SHA256 of `data` under the pepper, domain-separated by `purpose`."
  @spec hmac(String.t(), iodata()) :: binary()
  def hmac(purpose, data) when is_binary(purpose) do
    :crypto.mac(:hmac, :sha256, fetch!(:hmac_pepper), [purpose, 0, data])
  end

  @doc "Encrypts and authenticates `plaintext` (AES-256-GCM via `Plug.Crypto.MessageEncryptor`)."
  @spec encrypt(String.t(), binary()) :: String.t()
  def encrypt(purpose, plaintext) do
    {secret, sign_secret} = encryption_keys(purpose)
    MessageEncryptor.encrypt(plaintext, secret, sign_secret)
  end

  @doc "Decrypts what `encrypt/2` produced for the same `purpose`."
  @spec decrypt(String.t(), String.t()) :: {:ok, binary()} | :error
  def decrypt(purpose, ciphertext) do
    {secret, sign_secret} = encryption_keys(purpose)
    MessageEncryptor.decrypt(ciphertext, secret, sign_secret)
  end

  defp encryption_keys(purpose) do
    base = fetch!(:encryption_secret)

    {:crypto.mac(:hmac, :sha256, base, purpose <> ":encrypt"),
     :crypto.mac(:hmac, :sha256, base, purpose <> ":sign")}
  end

  defp fetch!(key) do
    :awrad
    |> Application.fetch_env!(__MODULE__)
    |> Keyword.fetch!(key)
  end
end
