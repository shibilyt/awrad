defmodule AwradApi.ProgressSync.EntityStore do
  @moduledoc false

  import Ecto.Query

  alias AwradApi.ProgressSync.{Document, EntityConflict, EntityRecord, Materializer}
  alias AwradApi.Repo

  @retention_seconds 30 * 24 * 60 * 60
  @max_int64 9_223_372_036_854_775_807

  def apply(user_id, attrs, revision) do
    payload = value(attrs, :payload)

    case value(payload || %{}, :type) do
      "entity_upsert" -> upsert(user_id, payload, value(attrs, :command_id), revision)
      "entity_delete" -> delete(user_id, payload, revision)
      "entity_restore" -> restore(user_id, payload, revision)
      "entity_accept_canonical" -> accept_canonical(user_id, payload, revision)
      "manual_complete" -> lifecycle_completion(user_id, payload, revision, true)
      "manual_reopen" -> lifecycle_completion(user_id, payload, revision, false)
      _ -> {:error, :unsupported_entity_command}
    end
  end

  def active_incarnation(user_id, goal_id) do
    case Repo.one(
           from entity in EntityRecord,
             where:
               entity.user_id == ^user_id and entity.entity_type == "goal" and
                 entity.entity_id == ^goal_id,
             select: {entity.state, entity.incarnation}
         ) do
      {"active", incarnation} -> {:ok, incarnation}
      {"deleted", _} -> {:error, :entity_deleted}
      {"purged", _} -> {:error, :entity_gone}
      nil -> {:error, :entity_missing}
    end
  end

  defp upsert(user_id, attrs, command_id, revision) do
    with {:ok, identity} <- identity(attrs),
         document when is_map(document) <- value(attrs, :proposed_document),
         {:ok, document} <- Document.validate(identity.type, document, identity.id) do
      case lock_entity(user_id, identity.type, identity.id) do
        nil -> create(user_id, identity, document, revision)
        entity -> update(user_id, entity, identity, document, command_id, revision)
      end
    else
      nil -> {:error, :invalid_entity_document}
      {:error, reason} -> {:error, reason}
      _ -> {:error, :invalid_entity_command}
    end
  end

  defp create(user_id, %{base_version: 0, incarnation: 1} = identity, document, revision) do
    with :ok <- maybe_coalesce_or_guard_create(user_id, identity, document) do
      do_create(user_id, identity, document, revision)
    else
      {:coalesce, %EntityRecord{} = existing} ->
        {:ok, effect(existing)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp create(_user_id, _identity, _document, _revision), do: {:error, :invalid_create_version}

  defp do_create(user_id, identity, document, revision) do
    with {:ok, _materialized} <- Materializer.put(identity.type, document, user_id),
         {:ok, entity} <-
           %EntityRecord{}
           |> EntityRecord.create_changeset(
             %{
               entity_type: identity.type,
               entity_id: identity.id,
               incarnation: 1,
               version: 1,
               sync_revision: revision,
               document: document,
               state: "active",
               completion_origin: initial_completion_origin(identity.type, document)
             },
             user_id
           )
           |> Repo.insert() do
      {:ok, effect(entity)}
    end
  end

  defp maybe_coalesce_or_guard_create(user_id, %{type: "user_tag"} = identity, document) do
    lock_user_tags!(user_id)
    normalized = document["normalized_name"]

    case find_active_user_tag_by_normalized_name(user_id, normalized) do
      %EntityRecord{entity_id: existing_id} = existing when existing_id != identity.id ->
        {:coalesce, existing}

      %EntityRecord{entity_id: id} when id == identity.id ->
        :ok

      nil ->
        if active_entity_count(user_id, "user_tag") >= 100 do
          {:error, :invalid_entity_document}
        else
          :ok
        end
    end
  end

  defp maybe_coalesce_or_guard_create(
         user_id,
         %{type: "dhikr_tag_assignment"} = identity,
         document
       ) do
    lock_user_tags!(user_id)

    with :ok <- validate_assignment_references(user_id, document),
         :ok <- validate_assignment_limits(user_id, document) do
      case find_active_assignment(user_id, document["tag_id"], document["dhikr_id"]) do
        %EntityRecord{entity_id: existing_id} = existing when existing_id != identity.id ->
          {:coalesce, existing}

        _ ->
          :ok
      end
    end
  end

  defp maybe_coalesce_or_guard_create(_user_id, _identity, _document), do: :ok

  defp lock_user_tags!(user_id) do
    Repo.query!("SELECT pg_advisory_xact_lock(hashtextextended($1, 0))", [
      "sync-dhikr-tags:" <> to_string(user_id)
    ])

    :ok
  end

  defp find_active_user_tag_by_normalized_name(user_id, normalized_name) do
    Repo.one(
      from entity in EntityRecord,
        where:
          entity.user_id == ^user_id and entity.entity_type == "user_tag" and
            entity.state == "active" and
            fragment("(?->>'normalized_name') = ?", entity.document, ^normalized_name),
        lock: "FOR UPDATE"
    )
  end

  defp find_active_assignment(user_id, tag_id, dhikr_id) do
    Repo.one(
      from entity in EntityRecord,
        where:
          entity.user_id == ^user_id and entity.entity_type == "dhikr_tag_assignment" and
            entity.state == "active" and
            fragment("(?->>'tag_id') = ?", entity.document, ^tag_id) and
            fragment("(?->>'dhikr_id') = ?", entity.document, ^dhikr_id),
        lock: "FOR UPDATE"
    )
  end

  defp active_entity_count(user_id, type) do
    Repo.aggregate(
      from(entity in EntityRecord,
        where:
          entity.user_id == ^user_id and entity.entity_type == ^type and entity.state == "active"
      ),
      :count
    )
  end

  defp validate_assignment_references(user_id, document) do
    tag_ok =
      Repo.exists?(
        from entity in EntityRecord,
          where:
            entity.user_id == ^user_id and entity.entity_type == "user_tag" and
              entity.entity_id == ^document["tag_id"] and entity.state == "active"
      )

    dhikr_ok = assignable_dhikr?(user_id, document["dhikr_id"])

    if tag_ok and dhikr_ok, do: :ok, else: {:error, :invalid_dhikr_reference}
  end

  defp validate_assignment_limits(user_id, document) do
    per_dhikr =
      Repo.aggregate(
        from(entity in EntityRecord,
          where:
            entity.user_id == ^user_id and entity.entity_type == "dhikr_tag_assignment" and
              entity.state == "active" and
              fragment("(?->>'dhikr_id') = ?", entity.document, ^document["dhikr_id"])
        ),
        :count
      )

    if per_dhikr >= 20, do: {:error, :invalid_entity_document}, else: :ok
  end

  defp assignable_dhikr?(user_id, dhikr_id) do
    Repo.exists?(
      from d in AwradApi.Dhikr.Dhikr,
        where:
          d.id == ^dhikr_id and is_nil(d.deleted_at) and
            (is_nil(d.user_id) or d.user_id == ^user_id)
    )
  end

  defp update(user_id, entity, identity, document, command_id, revision) do
    document = preserve_derived_completion(entity, document)

    with :ok <- guard_user_tag_rename(user_id, entity, document),
         :ok <- guard_assignment_update(user_id, entity, document) do
      cond do
        entity.state == "purged" ->
          {:reject, :gone, effect(entity)}

        entity.state == "deleted" ->
          {:reject, :gone, effect(entity)}

        identity.incarnation != entity.incarnation ->
          {:reject, :gone, effect(entity)}

        identity.base_version == entity.version ->
          accept_update(user_id, entity, document, revision)

        identity.base_version < entity.version and entity.document == document ->
          {:ok, effect(entity)}

        identity.base_version < entity.version ->
          with {:ok, _conflict} <-
                 preserve_conflict(
                   user_id,
                   entity,
                   command_id,
                   identity.base_version,
                   document,
                   revision
                 ) do
            {:reject_with_revision, :conflict, effect(entity)}
          end

        true ->
          {:error, :future_entity_version}
      end
    end
  end

  defp guard_user_tag_rename(user_id, %EntityRecord{entity_type: "user_tag"} = entity, document) do
    lock_user_tags!(user_id)
    normalized = document["normalized_name"]

    case find_active_user_tag_by_normalized_name(user_id, normalized) do
      %EntityRecord{entity_id: existing_id} when existing_id != entity.entity_id ->
        {:error, :invalid_entity_document}

      _ ->
        :ok
    end
  end

  defp guard_user_tag_rename(_user_id, _entity, _document), do: :ok

  defp guard_assignment_update(
         user_id,
         %EntityRecord{entity_type: "dhikr_tag_assignment"} = entity,
         document
       ) do
    lock_user_tags!(user_id)

    if entity.document["tag_id"] == document["tag_id"] and
         entity.document["dhikr_id"] == document["dhikr_id"] do
      validate_assignment_references(user_id, document)
    else
      {:error, :invalid_entity_document}
    end
  end

  defp guard_assignment_update(_user_id, _entity, _document), do: :ok

  defp accept_update(user_id, entity, document, revision) do
    if entity.document == document do
      resolve_conflicts(entity, revision)
      {:ok, effect(entity)}
    else
      with {:ok, _materialized} <- Materializer.put(entity.entity_type, document, user_id),
           {:ok, updated} <-
             entity
             |> Ecto.Changeset.change(
               document: document,
               completion_origin: updated_completion_origin(entity, document),
               version: entity.version + 1,
               sync_revision: revision
             )
             |> Repo.update() do
        resolve_conflicts(updated, revision)
        {:ok, effect(updated)}
      end
    end
  end

  defp delete(user_id, attrs, revision) do
    with {:ok, identity} <- identity(attrs),
         %EntityRecord{} = entity <- lock_entity(user_id, identity.type, identity.id) do
      cond do
        entity.state == "purged" ->
          {:reject, :gone, effect(entity)}

        entity.state == "deleted" ->
          {:ok, effect(entity)}

        identity.incarnation != entity.incarnation ->
          {:reject, :gone, effect(entity)}

        identity.base_version != entity.version ->
          {:reject, :conflict, effect(entity)}

        entity.entity_type == "custom_dhikr" and
            Materializer.custom_dhikr_referenced?(entity.entity_id, user_id) ->
          {:reject, :blocked_dependency, effect(entity)}

        true ->
          accept_delete(user_id, entity, revision)
      end
    else
      nil -> {:error, :entity_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp accept_delete(user_id, entity, revision) do
    now = DateTime.utc_now(:second)

    with {:ok, _materialized} <-
           Materializer.soft_delete(entity.entity_type, entity.entity_id, user_id, now),
         {:ok, deleted} <-
           entity
           |> Ecto.Changeset.change(
             state: "deleted",
             deleted_at: now,
             purge_after: DateTime.add(now, @retention_seconds, :second),
             version: entity.version + 1,
             sync_revision: revision
           )
           |> Repo.update(),
         :ok <- cascade_assignment_tombstones(user_id, deleted, revision, now) do
      {:ok, effect(deleted)}
    end
  end

  defp cascade_assignment_tombstones(
         user_id,
         %EntityRecord{entity_type: "user_tag"} = tag,
         revision,
         now
       ) do
    soft_delete_assignments(
      user_id,
      from(entity in EntityRecord,
        where:
          entity.user_id == ^user_id and entity.entity_type == "dhikr_tag_assignment" and
            entity.state == "active" and
            fragment("(?->>'tag_id') = ?", entity.document, ^tag.entity_id)
      ),
      revision,
      now
    )
  end

  defp cascade_assignment_tombstones(
         user_id,
         %EntityRecord{entity_type: "custom_dhikr"} = dhikr,
         revision,
         now
       ) do
    soft_delete_assignments(
      user_id,
      from(entity in EntityRecord,
        where:
          entity.user_id == ^user_id and entity.entity_type == "dhikr_tag_assignment" and
            entity.state == "active" and
            fragment("(?->>'dhikr_id') = ?", entity.document, ^dhikr.entity_id)
      ),
      revision,
      now
    )
  end

  defp cascade_assignment_tombstones(_user_id, _entity, _revision, _now), do: :ok

  defp soft_delete_assignments(_user_id, query, revision, now) do
    assignments = Repo.all(from entity in query, lock: "FOR UPDATE")

    Enum.reduce_while(assignments, :ok, fn assignment, :ok ->
      case assignment
           |> Ecto.Changeset.change(
             state: "deleted",
             deleted_at: now,
             purge_after: DateTime.add(now, @retention_seconds, :second),
             version: assignment.version + 1,
             sync_revision: revision
           )
           |> Repo.update() do
        {:ok, _} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp restore(user_id, attrs, revision) do
    with {:ok, identity} <- identity(attrs),
         %EntityRecord{} = entity <- lock_entity(user_id, identity.type, identity.id) do
      cond do
        entity.state == "purged" -> {:reject, :gone, effect(entity)}
        entity.state == "active" -> {:ok, effect(entity)}
        identity.incarnation != entity.incarnation -> {:reject, :gone, effect(entity)}
        identity.base_version != entity.version -> {:reject, :conflict, effect(entity)}
        true -> accept_restore(user_id, entity, revision)
      end
    else
      nil -> {:error, :entity_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp accept_restore(user_id, entity, revision) do
    with :ok <- guard_restore(user_id, entity),
         {:ok, _materialized} <- Materializer.put(entity.entity_type, entity.document, user_id),
         {:ok, restored} <-
           entity
           |> Ecto.Changeset.change(
             state: "active",
             incarnation: entity.incarnation + 1,
             version: entity.version + 1,
             sync_revision: revision,
             deleted_at: nil,
             purge_after: nil
           )
           |> Repo.update() do
      {:ok, effect(restored)}
    end
  end

  defp guard_restore(user_id, %EntityRecord{entity_type: "dhikr_tag_assignment"} = entity) do
    lock_user_tags!(user_id)

    with :ok <- validate_assignment_references(user_id, entity.document),
         :ok <- validate_assignment_limits(user_id, entity.document) do
      case find_active_assignment(
             user_id,
             entity.document["tag_id"],
             entity.document["dhikr_id"]
           ) do
        %EntityRecord{entity_id: existing_id} when existing_id != entity.entity_id ->
          {:error, :invalid_entity_document}

        _ ->
          :ok
      end
    end
  end

  defp guard_restore(user_id, %EntityRecord{entity_type: "user_tag"} = entity) do
    lock_user_tags!(user_id)
    normalized = entity.document["normalized_name"]

    case find_active_user_tag_by_normalized_name(user_id, normalized) do
      %EntityRecord{entity_id: existing_id} when existing_id != entity.entity_id ->
        {:error, :invalid_entity_document}

      nil ->
        if active_entity_count(user_id, "user_tag") >= 100 do
          {:error, :invalid_entity_document}
        else
          :ok
        end

      %EntityRecord{entity_id: id} when id == entity.entity_id ->
        :ok
    end
  end

  defp guard_restore(_user_id, _entity), do: :ok

  defp lifecycle_completion(user_id, attrs, revision, completed?) do
    with {:ok, %{type: "goal"} = identity} <- identity(attrs),
         %EntityRecord{state: "active"} = entity <- lock_entity(user_id, "goal", identity.id) do
      cond do
        identity.incarnation != entity.incarnation ->
          {:reject, :gone, effect(entity)}

        identity.base_version != entity.version ->
          {:reject, :conflict, effect(entity)}

        true ->
          completed_at =
            if completed?, do: DateTime.utc_now(:second) |> DateTime.to_iso8601(), else: nil

          document = Map.put(entity.document, "completed_at", completed_at)
          accept_update(user_id, entity, document, revision)
      end
    else
      nil -> {:error, :entity_not_found}
      {:error, reason} -> {:error, reason}
      _ -> {:error, :invalid_entity_command}
    end
  end

  defp accept_canonical(user_id, attrs, revision) do
    with {:ok, identity} <- identity(attrs),
         %EntityRecord{} = entity <- lock_entity(user_id, identity.type, identity.id) do
      cond do
        entity.state == "purged" ->
          {:reject, :gone, effect(entity)}

        identity.incarnation != entity.incarnation ->
          {:reject, :gone, effect(entity)}

        identity.base_version != entity.version ->
          {:reject, :conflict, effect(entity)}

        true ->
          resolve_conflicts(entity, revision)
          {:ok, effect(entity)}
      end
    else
      nil -> {:error, :entity_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp preserve_conflict(user_id, entity, command_id, base_version, document, revision) do
    %EntityConflict{}
    |> EntityConflict.changeset(
      %{
        command_id: command_id,
        base_version: base_version,
        proposed_document: document,
        sync_revision: revision
      },
      user_id,
      entity.id
    )
    |> Repo.insert()
  end

  defp resolve_conflicts(entity, revision) do
    now = DateTime.utc_now(:second)

    Repo.update_all(
      from(conflict in EntityConflict,
        where: conflict.entity_record_id == ^entity.id and is_nil(conflict.resolved_at)
      ),
      set: [resolved_at: now, sync_revision: revision]
    )

    :ok
  end

  defp identity(attrs) do
    with type when type in ~w(custom_dhikr goal user_tag dhikr_tag_assignment) <-
           value(attrs, :entity_type),
         {:ok, id} <- uuid_v4(value(attrs, :entity_id)),
         {:ok, base_version} <- non_negative_integer(value(attrs, :base_version)),
         {:ok, incarnation} <- positive_integer(value(attrs, :entity_incarnation)) do
      {:ok, %{type: type, id: id, base_version: base_version, incarnation: incarnation}}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :invalid_entity_command}
    end
  end

  defp lock_entity(user_id, type, id) do
    Repo.one(
      from entity in EntityRecord,
        where:
          entity.user_id == ^user_id and entity.entity_type == ^type and entity.entity_id == ^id,
        lock: "FOR UPDATE"
    )
  end

  defp effect(entity) do
    %{
      "entity_type" => entity.entity_type,
      "entity_id" => entity.entity_id,
      "entity_incarnation" => Integer.to_string(entity.incarnation),
      "entity_version" => Integer.to_string(entity.version),
      "state" => entity.state,
      "document" => entity.document
    }
  end

  defp uuid_v4(value) when is_binary(value) do
    with {:ok, normalized} <- Ecto.UUID.cast(value),
         true <- value == normalized,
         true <-
           String.match?(
             normalized,
             ~r/\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/
           ) do
      {:ok, normalized}
    else
      _ -> {:error, :invalid_uuid_v4}
    end
  end

  defp uuid_v4(_), do: {:error, :invalid_uuid_v4}

  defp positive_integer(value) when is_integer(value) and value > 0 and value <= @max_int64,
    do: {:ok, value}

  defp positive_integer(value) when is_binary(value), do: parse_integer(value, 1)
  defp positive_integer(_), do: {:error, :invalid_entity_incarnation}

  defp non_negative_integer(value)
       when is_integer(value) and value >= 0 and value <= @max_int64,
       do: {:ok, value}

  defp non_negative_integer(value) when is_binary(value), do: parse_integer(value, 0)
  defp non_negative_integer(_), do: {:error, :invalid_entity_version}

  defp parse_integer(value, minimum) do
    case if(byte_size(value) <= 19, do: Integer.parse(value), else: :error) do
      {integer, ""} when integer >= minimum and integer <= @max_int64 -> {:ok, integer}
      _ -> {:error, :invalid_entity_version}
    end
  end

  defp value(attrs, key), do: Map.get(attrs, key) || Map.get(attrs, Atom.to_string(key))

  defp initial_completion_origin("goal", %{"completed_at" => completed_at})
       when not is_nil(completed_at),
       do: "manual"

  defp initial_completion_origin(_, _), do: nil

  defp updated_completion_origin(%EntityRecord{entity_type: "goal"} = entity, document) do
    previous = entity.document["completed_at"]
    current = document["completed_at"]

    cond do
      is_nil(current) -> nil
      current != previous -> "manual"
      true -> entity.completion_origin
    end
  end

  defp updated_completion_origin(entity, _document), do: entity.completion_origin

  # Automatic completion is projection state, not part of the user's editable
  # goal-definition version. A device editing metadata from the current entity
  # version may still hold an older local projection; keep the server-derived
  # lifecycle fields until an explicit manual lifecycle command changes them.
  defp preserve_derived_completion(
         %EntityRecord{entity_type: "goal", completion_origin: "automatic", document: current},
         proposed
       ) do
    proposed
    |> Map.put("completed_at", current["completed_at"])
    |> Map.put("is_active", current["is_active"])
  end

  defp preserve_derived_completion(_entity, proposed), do: proposed
end
