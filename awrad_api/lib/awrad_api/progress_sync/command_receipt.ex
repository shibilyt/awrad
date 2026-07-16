defmodule AwradApi.ProgressSync.CommandReceipt do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:command_id, :binary_id, autogenerate: false}
  @foreign_key_type :binary_id

  schema "progress_sync_command_receipts" do
    field :actor_sequence, :integer
    field :canonical_payload_hash, :binary
    field :status, :string
    field :result_revision, :integer
    field :canonical_effect, :map, default: %{}
    field :canonical_effect_hash, :binary

    belongs_to :user, AwradApi.Accounts.User
    belongs_to :actor, AwradApi.ProgressSync.Actor

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def terminal_changeset(receipt, attrs, user_id, actor_id, status) do
    receipt
    |> cast(attrs, [
      :command_id,
      :actor_sequence,
      :canonical_payload_hash,
      :result_revision,
      :canonical_effect,
      :canonical_effect_hash
    ])
    |> put_change(:user_id, user_id)
    |> put_change(:actor_id, actor_id)
    |> put_change(:status, status)
    |> validate_required([
      :command_id,
      :user_id,
      :actor_id,
      :actor_sequence,
      :canonical_payload_hash,
      :status,
      :result_revision,
      :canonical_effect,
      :canonical_effect_hash
    ])
    |> validate_number(:actor_sequence, greater_than: 0)
    |> validate_number(:result_revision, greater_than_or_equal_to: 0)
    |> validate_inclusion(
      :status,
      ~w(accepted conflict invalid stale_basis gone blocked_dependency)
    )
    |> validate_hash(:canonical_payload_hash)
    |> validate_hash(:canonical_effect_hash)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:actor_id)
    |> unique_constraint(:command_id, name: :progress_sync_command_receipts_pkey)
    |> unique_constraint([:user_id, :actor_id, :actor_sequence],
      name: :progress_sync_receipts_actor_sequence_index
    )
  end

  defp validate_hash(changeset, field) do
    validate_change(changeset, field, fn ^field, value ->
      if is_binary(value) and byte_size(value) == 32,
        do: [],
        else: [{field, "must be a 32-byte SHA-256 digest"}]
    end)
  end
end
