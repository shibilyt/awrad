defmodule AwradApi.ProgressSync.Transfer do
  @moduledoc false

  import Ecto.Query

  alias AwradApi.Accounts.{Scope, User}

  alias AwradApi.ProgressSync.{
    CanonicalJSON,
    CountProjection,
    EntityConflict,
    EntityRecord,
    Head,
    TransferPage,
    TransferSession
  }

  alias AwradApi.Repo

  @page_size 200
  @expiry_seconds 30 * 60
  @max_active_sessions_per_user 8
  @max_transfer_records 50_000
  @cursor_salt "progress-sync-cursor-v1"

  def start(scope, kind, cursor \\ nil, options \\ [])

  def start(%Scope{user: %User{id: user_id}}, kind, cursor, options)
      when kind in ["snapshot", "delta"] do
    with {:ok, from_revision, requested_generation} <- cursor_position(kind, cursor, user_id) do
      Repo.transaction(
        fn ->
          start_or_materialize(
            user_id,
            kind,
            from_revision,
            requested_generation,
            Keyword.get(options, :allow_unchanged, false)
          )
        end,
        isolation: :repeatable_read
      )
      |> normalize_transaction()
    end
  end

  def start(_scope, _kind, _cursor, _options), do: {:error, :invalid_transfer_request}

  def page(%Scope{user: %User{id: user_id}}, session_id, page_number)
      when is_integer(page_number) and page_number > 0 do
    now = DateTime.utc_now(:second)

    query =
      from page in TransferPage,
        join: session in TransferSession,
        on: session.id == page.session_id,
        where:
          session.id == ^session_id and session.user_id == ^user_id and
            session.status in ["ready", "completed"] and session.expires_at > ^now and
            page.page_number == ^page_number,
        select: {session, page}

    case Repo.one(query) do
      nil ->
        {:error, :transfer_not_found}

      {session, page} ->
        if page.page_number == session.page_count and session.status == "ready" do
          Repo.update_all(
            from(stored in TransferSession,
              where: stored.id == ^session.id and stored.status == "ready"
            ),
            set: [status: "completed"]
          )
        end

        {:ok, page_response(session, page)}
    end
  end

  def page(_scope, _session_id, _page_number), do: {:error, :invalid_transfer_page}

  defp start_or_materialize(user_id, "delta", from_revision, requested_generation, true) do
    head = ensure_head!(user_id)

    cond do
      requested_generation != head.generation -> Repo.rollback(:generation_reset)
      from_revision > head.revision -> Repo.rollback(:future_cursor)
      from_revision == head.revision -> unchanged_response(head)
      true -> materialize(user_id, "delta", from_revision, requested_generation)
    end
  end

  defp start_or_materialize(user_id, kind, from_revision, requested_generation, _allow_unchanged) do
    materialize(user_id, kind, from_revision, requested_generation)
  end

  defp materialize(user_id, kind, from_revision, requested_generation) do
    now = DateTime.utc_now(:second)

    Repo.query!("SELECT pg_advisory_xact_lock(hashtextextended($1, 0))", [
      "sync-transfer:" <> to_string(user_id)
    ])

    Repo.delete_all(
      from session in TransferSession,
        where: session.user_id == ^user_id and session.expires_at <= ^now
    )

    active_sessions =
      Repo.aggregate(
        from(session in TransferSession,
          where:
            session.user_id == ^user_id and session.status == "ready" and
              session.expires_at > ^now
        ),
        :count
      )

    if active_sessions >= @max_active_sessions_per_user do
      Repo.rollback(:transfer_quota_exceeded)
    end

    head = ensure_head!(user_id)

    if requested_generation && requested_generation != head.generation do
      Repo.rollback(:generation_reset)
    end

    if from_revision > head.revision do
      Repo.rollback(:future_cursor)
    end

    records = records(user_id, kind, from_revision, head.revision)

    if length(records) > @max_transfer_records do
      Repo.rollback(:transfer_too_large)
    end

    record_pages =
      records
      |> Enum.chunk_every(@page_size)
      |> ensure_page()
      |> Enum.map(fn page_records ->
        payload = %{"records" => page_records}
        {:ok, checksum} = CanonicalJSON.hash(payload)
        %{records: page_records, payload: payload, checksum: checksum}
      end)

    checksum = session_checksum(record_pages, length(records))
    expires_at = DateTime.add(now, @expiry_seconds, :second)

    session =
      %TransferSession{}
      |> TransferSession.changeset(
        %{
          kind: kind,
          from_revision: from_revision,
          to_revision: head.revision,
          generation: head.generation,
          status: "ready",
          page_count: length(record_pages),
          record_count: length(records),
          checksum: checksum,
          expires_at: expires_at
        },
        user_id
      )
      |> Repo.insert!()

    record_pages
    |> Enum.with_index(1)
    |> Enum.each(fn {page, page_number} ->
      %TransferPage{}
      |> TransferPage.changeset(
        %{
          page_number: page_number,
          item_count: length(page.records),
          payload: page.payload,
          checksum: page.checksum
        },
        session.id
      )
      |> Repo.insert!()
    end)

    session_response(session)
  end

  defp records(user_id, kind, from_revision, to_revision) do
    entity_query =
      from entity in EntityRecord,
        where: entity.user_id == ^user_id and entity.sync_revision <= ^to_revision,
        order_by: [asc: entity.sync_revision, asc: entity.entity_type, asc: entity.entity_id]

    projection_query =
      from projection in CountProjection,
        join: entity in EntityRecord,
        on:
          entity.user_id == projection.user_id and entity.entity_type == "goal" and
            entity.entity_id == projection.goal_id and entity.state == "active" and
            entity.incarnation == projection.entity_incarnation,
        where: projection.user_id == ^user_id and projection.sync_revision <= ^to_revision,
        order_by: [asc: projection.sync_revision, asc: projection.id]

    conflict_query =
      from conflict in EntityConflict,
        join: entity in EntityRecord,
        on: entity.id == conflict.entity_record_id,
        where: conflict.user_id == ^user_id and conflict.sync_revision <= ^to_revision,
        order_by: [asc: conflict.sync_revision, asc: conflict.id],
        select: {conflict, conflict.sync_revision, entity.entity_type, entity.entity_id}

    entity_query = changed_after(entity_query, kind, from_revision)
    projection_query = changed_after(projection_query, kind, from_revision)
    conflict_query = changed_conflicts(conflict_query, kind, from_revision)

    entity_query = limit_records(entity_query)
    projection_query = limit_records(projection_query)
    conflict_query = limit_records(conflict_query)

    (Enum.map(Repo.all(entity_query), &entity_record/1) ++
       Enum.map(Repo.all(projection_query), &projection_record/1) ++
       Enum.map(Repo.all(conflict_query), &conflict_record/1))
    |> Enum.take(@max_transfer_records + 1)
    |> Enum.sort_by(
      &{
        dependency_order(&1["kind"]),
        integer_revision(&1["sync_revision"]),
        &1["id"]
      }
    )
  end

  defp changed_after(query, "delta", revision),
    do: from(row in query, where: row.sync_revision > ^revision)

  defp changed_after(query, "snapshot", _revision), do: query

  defp changed_conflicts(query, "delta", revision) do
    from [conflict, _entity] in query, where: conflict.sync_revision > ^revision
  end

  defp changed_conflicts(query, "snapshot", _revision) do
    from [conflict, _entity] in query, where: is_nil(conflict.resolved_at)
  end

  defp limit_records(query) do
    limit = @max_transfer_records + 1
    from row in query, limit: ^limit
  end

  defp entity_record(%EntityRecord{state: "active"} = entity) do
    %{
      "kind" => entity.entity_type,
      "id" => entity.entity_id,
      "sync_revision" => Integer.to_string(entity.sync_revision),
      "payload" => %{
        "entity_incarnation" => Integer.to_string(entity.incarnation),
        "entity_version" => Integer.to_string(entity.version),
        "document" => entity.document
      }
    }
  end

  defp entity_record(entity) do
    kind = if entity.state == "purged", do: "deletion_fence", else: "tombstone"

    %{
      "kind" => kind,
      "id" => entity.entity_id,
      "sync_revision" => Integer.to_string(entity.sync_revision),
      "payload" => %{
        "entity_type" => entity.entity_type,
        "entity_incarnation" => Integer.to_string(entity.incarnation),
        "entity_version" => Integer.to_string(entity.version),
        "deleted_at" => DateTime.to_iso8601(entity.deleted_at),
        "purge_after" => if(entity.purge_after, do: DateTime.to_iso8601(entity.purge_after)),
        "purged" => entity.state == "purged"
      }
    }
  end

  defp projection_record(projection) do
    %{
      "kind" => "count_projection",
      "id" => projection.id,
      "sync_revision" => Integer.to_string(projection.sync_revision),
      "payload" => %{
        "goal_id" => projection.goal_id,
        "slot_id" => projection.slot_id,
        "local_date" => Date.to_iso8601(projection.local_date),
        "entity_incarnation" => Integer.to_string(projection.entity_incarnation),
        "count" => Integer.to_string(projection.count)
      }
    }
  end

  defp conflict_record({conflict, revision, entity_type, entity_id}) do
    payload = %{
      "entity_type" => entity_type,
      "entity_id" => entity_id,
      "command_id" => conflict.command_id,
      "base_version" => Integer.to_string(conflict.base_version),
      "resolved" => not is_nil(conflict.resolved_at),
      "resolved_at" => if(conflict.resolved_at, do: DateTime.to_iso8601(conflict.resolved_at))
    }

    payload =
      if conflict.resolved_at,
        do: payload,
        else: Map.put(payload, "proposed_document", conflict.proposed_document)

    %{
      "kind" => "conflict",
      "id" => conflict.id,
      "sync_revision" => Integer.to_string(revision),
      "payload" => payload
    }
  end

  defp session_response(session) do
    %{
      "transfer_id" => session.id,
      "kind" => session.kind,
      "through_revision" => Integer.to_string(session.to_revision),
      "generation" => Integer.to_string(session.generation),
      "cursor" => encode_cursor(session.user_id, session.generation, session.to_revision),
      "page_count" => session.page_count,
      "record_count" => session.record_count,
      "checksum" => Base.encode16(session.checksum, case: :lower),
      "expires_at" => DateTime.to_iso8601(session.expires_at)
    }
  end

  defp unchanged_response(head) do
    %{
      "status" => "unchanged",
      "kind" => "delta",
      "through_revision" => Integer.to_string(head.revision),
      "generation" => Integer.to_string(head.generation),
      "cursor" => encode_cursor(head.user_id, head.generation, head.revision)
    }
  end

  defp page_response(session, page) do
    %{
      "transfer_id" => session.id,
      "page" => page.page_number,
      "checksum" => Base.encode16(page.checksum, case: :lower),
      "records" => page.payload["records"]
    }
  end

  defp cursor_position("snapshot", nil, _user_id), do: {:ok, 0, nil}

  defp cursor_position("snapshot", _cursor, _user_id),
    do: {:error, :snapshot_cursor_not_allowed}

  defp cursor_position("delta", cursor, user_id) when is_binary(cursor) do
    case Phoenix.Token.verify(AwradApiWeb.Endpoint, @cursor_salt, cursor,
           max_age: 365 * 24 * 60 * 60
         ) do
      {:ok, %{"user_id" => ^user_id, "generation" => generation, "revision" => revision}}
      when is_integer(generation) and generation > 0 and is_integer(revision) and revision >= 0 ->
        {:ok, revision, generation}

      _ ->
        {:error, :invalid_cursor}
    end
  end

  defp cursor_position("delta", _cursor, _user_id), do: {:error, :invalid_cursor}

  defp encode_cursor(user_id, generation, revision) do
    Phoenix.Token.sign(AwradApiWeb.Endpoint, @cursor_salt, %{
      "user_id" => user_id,
      "generation" => generation,
      "revision" => revision
    })
  end

  defp ensure_head!(user_id) do
    %Head{user_id: user_id}
    |> Head.changeset(%{})
    |> Repo.insert!(on_conflict: :nothing, conflict_target: :user_id)

    Repo.one!(from head in Head, where: head.user_id == ^user_id)
  end

  defp ensure_page([]), do: [[]]
  defp ensure_page(pages), do: pages

  # The session digest is intentionally a digest of the ordered immutable page
  # digests plus the record count. Clients can persist these tiny values across
  # process death and verify the whole transfer before atomically installing it.
  defp session_checksum(pages, record_count) do
    material =
      pages
      |> Enum.map(&Base.encode16(&1.checksum, case: :lower))
      |> Enum.join()
      |> Kernel.<>(":#{record_count}")

    :crypto.hash(:sha256, material)
  end

  defp integer_revision(value), do: String.to_integer(value)
  defp dependency_order("custom_dhikr"), do: 0
  defp dependency_order("goal"), do: 1
  defp dependency_order("count_projection"), do: 2
  defp dependency_order("conflict"), do: 3
  defp dependency_order(_tombstone_or_fence), do: 4
  defp normalize_transaction({:ok, response}), do: {:ok, response}
  defp normalize_transaction({:error, reason}), do: {:error, reason}
end
