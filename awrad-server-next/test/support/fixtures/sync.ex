defmodule Awrad.Fixtures.Sync do
  @moduledoc """
  Puts an account's sync state from `contracts/sync/v1/fixtures/` into the
  database, and reads it back in the fixtures' `expect` shapes.

  State is inserted as rows, never through commands, so a fixture's state is
  exactly what it says: entities at their versions and revisions, the head,
  stored receipts (with the payload hash of their command) and tag aliases.
  """

  import Ecto.Query

  alias Awrad.Repo
  alias Awrad.Sync.{Entity, Head, Receipt, TagAlias}

  @doc "Inserts a `sync_receipts` given `state` (or a feed's entities and head) for `user_id`."
  @spec put_state!(Ecto.UUID.t(), map()) :: :ok
  def put_state!(user_id, state) do
    Repo.insert!(%Head{user_id: user_id, head_revision: state["head_revision"]})

    for entity <- state["entities"] do
      Repo.insert!(%Entity{
        user_id: user_id,
        entity_type: entity["entity_type"],
        entity_id: entity["entity_id"],
        version: entity["version"],
        revision: entity["revision"],
        state: entity["state"],
        document: entity["document"]
      })
    end

    for %{"command" => command, "receipt" => receipt} <- Map.get(state, "receipts", []) do
      Repo.insert!(%Receipt{
        user_id: user_id,
        command_id: command["command_id"],
        payload_hash: Receipt.payload_hash(command),
        receipt: receipt
      })
    end

    for %{"alias_id" => alias_id, "tag_id" => tag_id} <- Map.get(state, "tag_aliases", []) do
      Repo.insert!(%TagAlias{user_id: user_id, alias_id: alias_id, tag_id: tag_id})
    end

    :ok
  end

  @doc "The account's entities changed after `revision`, in feed order, as `$defs/change` maps."
  @spec changes_after(Ecto.UUID.t(), non_neg_integer()) :: [map()]
  def changes_after(user_id, revision) do
    from(e in Entity, where: e.user_id == ^user_id and e.revision > ^revision)
    |> Repo.all()
    |> Enum.sort_by(&{&1.revision, &1.entity_type, &1.entity_id})
    |> Enum.map(&Entity.change/1)
  end

  @doc "The account's head revision (0 without a head row)."
  @spec head_revision(Ecto.UUID.t()) :: non_neg_integer()
  def head_revision(user_id) do
    Repo.one(from(h in Head, where: h.user_id == ^user_id, select: h.head_revision)) || 0
  end

  @doc "Every tag alias of the account, ordered by alias ID."
  @spec tag_aliases(Ecto.UUID.t()) :: [map()]
  def tag_aliases(user_id) do
    from(a in TagAlias,
      where: a.user_id == ^user_id,
      order_by: a.alias_id,
      select: %{"alias_id" => a.alias_id, "tag_id" => a.tag_id}
    )
    |> Repo.all()
  end

  @doc "Every stored command ID of the account, sorted."
  @spec stored_receipts(Ecto.UUID.t()) :: [Ecto.UUID.t()]
  def stored_receipts(user_id) do
    from(r in Receipt, where: r.user_id == ^user_id, select: r.command_id)
    |> Repo.all()
    |> Enum.sort()
  end
end
