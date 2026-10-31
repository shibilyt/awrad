defmodule Awrad.Sync.Commands do
  @moduledoc """
  Applies a batch of commands (`contracts/sync/v1/README.md`, "Commands"; the
  spec is `fixtures/sync_receipts.json`).

  **One transaction per batch**, holding the account's `sync_heads` row
  `FOR UPDATE`, so the account's batches are serialized and every applied
  command takes the next revision (server ADR 0009). Commands run in order,
  and each one first decides its outcome from what's stored, then writes. A
  command that isn't applied writes nothing but its receipt, so no command's
  outcome changes or undoes another's.

  Each command is checked in the contract's order:

    1. the receipt store (`duplicate`, or `command_id_reused`, which isn't stored);
    2. a `dhikr_personal`, `practice_policy` or `goal_order` delete
       (`delete_not_allowed`), and a `practice_policy` or `goal_order` whose
       `entity_id` isn't the account's ID (`entity_id_invalid`, a `mismatch`
       on `/entity_id`, `current` null);
    3. a put's document (`document_too_large`, `document_invalid`; a goal's
       goal rules included);
    4. the entity's state (`gone` for a deleted entity or a merged tag ID;
       `entity_not_found` for anything but a create of an unknown entity;
       `conflict` for a stale `base_version`);
    5. the entity rules (`Awrad.Sync.Rules`);
    6. apply, with cascades at the same revision (`Awrad.Sync.Rules.write/5`),
       which a `user_tag` or `custom_dhikr` delete's `applied` receipt lists
       in `cascaded` (`null` on every other `applied` receipt); a custom
       dhikr's recordings learn whether they're still named
       (`Awrad.Sync.AudioReferences.track/3`).

  Goals the server ends itself get `today`, the UTC date the batch applies
  on (README, "The date a server-ended goal gets").
  """

  import Ecto.Query

  alias Awrad.Repo
  alias Awrad.Sync.{AudioReferences, Documents, Entity, Head, Receipt, Rules, TagAlias}

  @type result :: %{receipts: [map(), ...], head_revision: non_neg_integer()}

  @doc """
  Applies `commands` (envelope-valid, `Awrad.Sync.Batch`) for `user_id`, in
  order. `today` (`nil` for the current UTC date) is the date server-ended
  goals get.
  """
  @spec apply_batch(Ecto.UUID.t(), [map(), ...], Date.t() | nil) :: result()
  def apply_batch(user_id, [_ | _] = commands, today \\ nil) do
    {:ok, result} =
      Repo.transact(fn ->
        now = DateTime.utc_now(:second)
        head = lock_head(user_id, now)
        context = {now, today || DateTime.to_date(now)}

        {receipts, head_revision} =
          Enum.map_reduce(commands, head.head_revision, &run(user_id, &1, &2, context))

        if head_revision != head.head_revision do
          Repo.update_all(from(h in Head, where: h.id == ^head.id),
            set: [head_revision: head_revision, updated_at: now]
          )
        end

        {:ok, %{receipts: receipts, head_revision: head_revision}}
      end)

    result
  end

  # The account's head row, created at revision 0 on its first batch, locked
  # until the batch commits.
  defp lock_head(user_id, now) do
    Repo.insert_all(
      Head,
      [
        %{
          id: Awrad.UUIDv7.generate(),
          user_id: user_id,
          head_revision: 0,
          inserted_at: now,
          updated_at: now
        }
      ],
      on_conflict: :nothing,
      conflict_target: :user_id
    )

    Repo.one!(from(h in Head, where: h.user_id == ^user_id, lock: "FOR UPDATE"))
  end

  # One command: its receipt and the head revision after it.
  defp run(user_id, command, revision, {now, today}) do
    hash = Receipt.payload_hash(command)
    command_id = command["command_id"]

    case Repo.get_by(Receipt, user_id: user_id, command_id: command_id) do
      %Receipt{payload_hash: ^hash, receipt: original} ->
        {%{"command_id" => command_id, "status" => "duplicate", "original" => original}, revision}

      %Receipt{} ->
        entity = fetch_entity(user_id, command)
        {Receipt.rejected(command, "command_id_reused", [], entity), revision}

      nil ->
        {receipt, revision} = decide(user_id, command, revision, today)

        Repo.insert!(%Receipt{
          user_id: user_id,
          command_id: command_id,
          payload_hash: hash,
          receipt: receipt,
          inserted_at: now
        })

        {receipt, revision}
    end
  end

  defp decide(user_id, command, revision, today) do
    entity = fetch_entity(user_id, command)

    with :ok <- check_delete(command, entity),
         :ok <- check_entity_id(user_id, command),
         :ok <- check_document(command, entity),
         :ok <- check_state(user_id, command, entity),
         {:ok, document} <- Rules.check(user_id, command, entity, today) do
      revision = revision + 1
      {version, cascaded} = Rules.write(user_id, command, entity, {document, revision}, today)
      :ok = AudioReferences.track(user_id, command, entity)

      {%{
         "command_id" => command["command_id"],
         "status" => "applied",
         "version" => version,
         "revision" => revision,
         "cascaded" => cascaded
       }, revision}
    else
      {:stop, receipt} -> {receipt, revision}
    end
  end

  defp check_delete(%{"op" => "delete", "entity_type" => type} = command, entity)
       when type in ~w(dhikr_personal practice_policy goal_order),
       do: {:stop, Receipt.rejected(command, "delete_not_allowed", [], entity)}

  defp check_delete(_command, _entity), do: :ok

  # The practice policy and the goal order are one per account, with its ID.
  defp check_entity_id(user_id, %{"entity_type" => type, "entity_id" => id} = command)
       when type in ~w(practice_policy goal_order) and id != user_id do
    fields = [%{"field" => "/entity_id", "code" => "mismatch"}]
    {:stop, Receipt.rejected(command, "entity_id_invalid", fields, nil)}
  end

  defp check_entity_id(_user_id, _command), do: :ok

  defp check_document(%{"op" => "put"} = command, entity) do
    case Documents.check(command["entity_type"], command["document"]) do
      :ok ->
        :ok

      {:error, :document_too_large} ->
        {:stop, Receipt.rejected(command, "document_too_large", [], entity)}

      {:error, {:document_invalid, errors}} ->
        fields = Enum.map(errors, &Map.update!(&1, "field", fn field -> "/document" <> field end))
        {:stop, Receipt.rejected(command, "document_invalid", fields, entity)}
    end
  end

  defp check_document(_delete, _entity), do: :ok

  defp check_state(user_id, command, entity) do
    cond do
      merged_tag?(user_id, command) -> {:stop, gone(command)}
      entity && entity.state == "deleted" -> {:stop, gone(command)}
      is_nil(entity) -> check_create(command)
      command["base_version"] != entity.version -> {:stop, conflict(command, entity)}
      true -> :ok
    end
  end

  # Only a create (a put on version 0) may name an entity the server never had.
  defp check_create(%{"op" => "put", "base_version" => 0}), do: :ok

  defp check_create(command),
    do: {:stop, Receipt.rejected(command, "entity_not_found", [], nil)}

  defp merged_tag?(user_id, %{"entity_type" => "user_tag", "entity_id" => id}),
    do: Repo.exists?(from(a in TagAlias, where: a.user_id == ^user_id and a.alias_id == ^id))

  defp merged_tag?(_user_id, _command), do: false

  defp conflict(command, entity) do
    %{
      "command_id" => command["command_id"],
      "status" => "conflict",
      "current" => Entity.current(entity)
    }
  end

  defp fetch_entity(user_id, command) do
    Repo.one(
      from e in Entity,
        where: e.user_id == ^user_id and e.entity_type == ^command["entity_type"],
        where: e.entity_id == ^command["entity_id"]
    )
  end

  defp gone(command), do: %{"command_id" => command["command_id"], "status" => "gone"}
end
