defmodule Awrad.Idempotency.Record do
  @moduledoc "One stored `Idempotency-Key` result (`Awrad.Idempotency`)."

  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}

  @type t :: %__MODULE__{
          scope: String.t() | nil,
          key: Ecto.UUID.t() | nil,
          user_id: Ecto.UUID.t() | nil,
          fingerprint: binary() | nil,
          status: pos_integer() | nil,
          content_type: String.t() | nil,
          body_ciphertext: binary() | nil,
          expires_at: DateTime.t() | nil
        }

  schema "idempotency_records" do
    # The operation: method and path, e.g. "POST /api/v1/accounts".
    field :scope, :string
    field :key, Ecto.UUID
    # The signed-in account that made the request; nil for public operations.
    # The row cascades away with the account.
    field :user_id, :binary_id
    field :fingerprint, :binary, redact: true
    field :status, :integer
    field :content_type, :string
    field :body_ciphertext, :binary, redact: true
    field :expires_at, :utc_datetime

    timestamps(type: :utc_datetime, updated_at: false)
  end
end
