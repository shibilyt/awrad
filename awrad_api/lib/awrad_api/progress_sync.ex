defmodule AwradApi.ProgressSync do
  @moduledoc """
  Transactional ordering and idempotency boundary for progress synchronization.

  This context is deliberately transport-agnostic. Future authenticated sync
  controllers must pass the current scope and may not accept ownership fields
  from a request payload.
  """

  import Ecto.Query

  alias AwradApi.Accounts.{Scope, User}

  alias AwradApi.ProgressSync.{
    Actor,
    CanonicalJSON,
    CommandReceipt,
    CountLedger,
    EntityStore,
    Head,
    Maintenance,
    ReceiptAdoption
  }

  alias AwradApi.Repo

  @actor_lease_seconds 90 * 24 * 60 * 60
  @max_active_actors_per_user 32
  @max_int64 9_223_372_036_854_775_807

  @doc """
  Registers one actor for an installation and creates the user's revision head.

  Re-registering the same actor is safe. If an app reinstall or local-database
  recovery presents a new actor UUID for the same installation, the server
  allocates the next installation incarnation. Prior leased actors remain
  valid, which also makes a cloned device backup converge instead of causing
  the two clients to retire each other repeatedly.
  The client cannot choose that incarnation. Reusing an actor UUID for another
  installation or user is rejected as an identity collision.
  """
  def register_actor(%Scope{user: %User{id: user_id}}, attrs) when is_map(attrs) do
    now = DateTime.utc_now(:second)
    lease_expires_at = DateTime.add(now, @actor_lease_seconds, :second)

    Repo.transaction(fn ->
      ensure_head!(user_id)
      registration = drop_ownership(attrs)

      with {:ok, actor_id} <- uuid_v4(value(registration, :id)),
           {:ok, installation_id} <- uuid_v4(value(registration, :installation_id)),
           {:ok, starting_sequence} <-
             positive_integer(value(registration, :starting_sequence) || 1) do
        # Serialize the whole actor registry for one account. This protects the
        # empty-set incarnation race and makes the active-actor quota exact even
        # when different installations register concurrently.
        Repo.query!(
          "SELECT pg_advisory_xact_lock(hashtextextended($1, 0))",
          ["sync-actors:" <> to_string(user_id)]
        )

        existing = Repo.get(Actor, actor_id, lock: "FOR UPDATE")

        cond do
          existing &&
              (existing.user_id != user_id || existing.installation_id != installation_id) ->
            Repo.rollback(:actor_identity_collision)

          existing &&
              (not is_nil(existing.retired_at) or
                 DateTime.compare(existing.lease_expires_at, now) != :gt) ->
            Repo.rollback(:actor_fork)

          existing ->
            existing
            |> Ecto.Changeset.change(
              last_seen_at: now,
              lease_expires_at: lease_expires_at
            )
            |> Repo.update!()

          true ->
            active_actor_count =
              Repo.aggregate(
                from(actor in Actor,
                  where:
                    actor.user_id == ^user_id and is_nil(actor.retired_at) and
                      actor.lease_expires_at > ^now
                ),
                :count
              )

            if active_actor_count >= @max_active_actors_per_user,
              do: Repo.rollback(:actor_quota_exceeded)

            prior =
              Repo.all(
                from actor in Actor,
                  where: actor.user_id == ^user_id and actor.installation_id == ^installation_id,
                  lock: "FOR UPDATE"
              )

            incarnation = Enum.max(Enum.map(prior, & &1.incarnation), fn -> 0 end) + 1

            changeset =
              Actor.registration_changeset(
                %Actor{},
                %{id: actor_id, installation_id: installation_id, incarnation: incarnation},
                user_id,
                now,
                lease_expires_at
              )

            changeset =
              Ecto.Changeset.put_change(changeset, :next_expected_sequence, starting_sequence)

            case Repo.insert(changeset) do
              {:ok, actor} -> actor
              {:error, changeset} -> Repo.rollback(changeset)
            end
        end
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  @doc """
  Applies one command at the next sequence for an actor.

  The handler executes inside the same database transaction and receives the
  revision being assigned. It must return `{:ok, canonical_effect}`. The effect
  is stored with the receipt so an exact retry returns the original result
  without re-running the mutation.
  """
  def execute_command(%Scope{user: %User{id: user_id}}, attrs, handler)
      when is_map(attrs) and is_function(handler, 1) do
    with {:ok, command_id} <- uuid_v4(value(attrs, :command_id)),
         {:ok, actor_id} <- uuid_v4(value(attrs, :actor_id)),
         {:ok, actor_sequence} <- positive_integer(value(attrs, :actor_sequence)),
         payload when is_map(payload) <- value(attrs, :payload),
         {:ok, payload_hash} <- CanonicalJSON.hash(payload) do
      Repo.transaction(fn ->
        execute_locked(
          user_id,
          command_id,
          actor_id,
          actor_sequence,
          payload_hash,
          handler
        )
      end)
      |> normalize_transaction()
    else
      nil -> {:error, :invalid_command}
      {:error, reason} -> {:error, reason}
      _other -> {:error, :invalid_command}
    end
  end

  @doc """
  Executes one canonical count command through the immutable credit ledger.

  Invalid or stale commands receive durable terminal receipts and advance the
  actor stream. Retryable server/checkpoint failures leave the sequence open.
  """
  def execute_count_command(%Scope{user: %User{id: user_id}} = scope, attrs)
      when is_map(attrs) do
    execute_command(scope, attrs, fn revision ->
      case CountLedger.apply(user_id, attrs, revision) do
        {:ok, effect} ->
          {:ok, effect}

        {:reject, status, effect} ->
          {:reject, status, effect}

        {:error, reason} when reason in [:entity_deleted, :entity_gone] ->
          terminal_rejection(:gone, reason)

        {:error, reason}
        when reason in [
               :invalid_count_payload,
               :unsupported_count_command,
               :invalid_count_bucket,
               :unsupported_entity_incarnation,
               :invalid_basis_revision,
               :invalid_local_date,
               :invalid_int64,
               :invalid_uuid_v4,
               :invalid_observed_credits,
               :duplicate_observed_credit,
               :count_overflow
             ] ->
          terminal_rejection(:invalid, reason)

        {:error, :checkpoint_required} = error ->
          Maintenance.trigger()
          error

        {:error, reason} ->
          {:error, reason}
      end
    end)
  end

  @doc "Executes one v1 count or entity command through the shared ordering boundary."
  def execute_progress_command(%Scope{} = scope, attrs) when is_map(attrs) do
    case attrs |> value(:payload) |> then(&value(&1 || %{}, :type)) do
      type when type in ["increment", "decrement_bucket", "reset_bucket_observed"] ->
        execute_count_command(scope, attrs)

      type
      when type in [
             "entity_upsert",
             "entity_delete",
             "entity_restore",
             "entity_accept_canonical",
             "manual_complete",
             "manual_reopen"
           ] ->
        execute_entity_command(scope, attrs)

      _ ->
        {:error, :unsupported_progress_command}
    end
  end

  defp execute_entity_command(%Scope{user: %User{id: user_id}} = scope, attrs) do
    execute_command(scope, attrs, fn revision ->
      case EntityStore.apply(user_id, attrs, revision) do
        {:ok, effect} ->
          {:ok, effect}

        {:reject, status, effect} ->
          {:reject, status, effect}

        {:reject_with_revision, status, effect} ->
          {:reject_with_revision, status, effect}

        {:error, :blocked_dependency} ->
          terminal_rejection(:blocked_dependency, :blocked_dependency)

        {:error, reason} when reason in [:entity_not_found, :entity_gone, :entity_deleted] ->
          terminal_rejection(:gone, reason)

        {:error, reason}
        when reason in [
               :invalid_entity_document,
               :invalid_entity_command,
               :unsupported_entity_command,
               :invalid_create_version,
               :future_entity_version,
               :invalid_uuid_v4,
               :invalid_entity_version,
               :invalid_entity_incarnation,
               :invalid_dhikr_reference,
               :slot_removal_requires_archive,
               :entity_identity_collision
             ] ->
          terminal_rejection(:invalid, reason)

        {:error, %Ecto.Changeset{}} ->
          terminal_rejection(:invalid, :invalid_entity_document)

        {:error, reason} ->
          {:error, reason}
      end
    end)
  end

  @doc """
  Rebuilds a derived count projection from immutable ledger state.

  A changed repair advances the user's revision so future deltas can carry the
  corrected projection. An unchanged repair is revision-neutral.
  """
  def repair_count_projection(%Scope{user: %User{id: user_id}}, bucket_attrs)
      when is_map(bucket_attrs) do
    CountLedger.repair_projection(user_id, bucket_attrs)
  end

  @doc """
  Records one actor's durable apply/compaction frontier and renews its lease.

  Both frontiers are monotonic. The safe frontier may not exceed the applied
  revision or the account's current server revision.
  """
  def acknowledge_actor(%Scope{user: %User{id: user_id}}, actor_id, attrs)
      when is_map(attrs) do
    with {:ok, actor_id} <- uuid_v4(actor_id),
         {:ok, applied_revision} <- non_negative_integer(value(attrs, :applied_revision)),
         {:ok, safe_revision} <- non_negative_integer(value(attrs, :safe_compaction_revision)),
         true <- safe_revision <= applied_revision do
      Repo.transaction(fn ->
        head = lock_head!(user_id)
        actor = lock_actor(user_id, actor_id)

        cond do
          is_nil(actor) ->
            Repo.rollback(:unknown_actor)

          applied_revision > head.revision ->
            Repo.rollback(:future_applied_revision)

          applied_revision < actor.applied_revision or
              safe_revision < actor.safe_compaction_revision ->
            Repo.rollback(:actor_frontier_regression)

          true ->
            now = DateTime.utc_now(:second)

            actor
            |> Ecto.Changeset.change(
              applied_revision: applied_revision,
              safe_compaction_revision: safe_revision,
              last_seen_at: now,
              lease_expires_at: DateTime.add(now, @actor_lease_seconds, :second)
            )
            |> Repo.update!()
        end
      end)
    else
      false -> {:error, :invalid_compaction_frontier}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Folds one bucket's immutable tail into a checkpoint when all active actors
  have declared the current account revision safe.
  """
  def compact_count_bucket(%Scope{user: %User{id: user_id}}, bucket_attrs)
      when is_map(bucket_attrs) do
    CountLedger.compact_bucket(user_id, bucket_attrs)
  end

  @doc "Invalidates existing transfer cursors without changing canonical state."
  def bump_generation(%Scope{user: %User{id: user_id}}) do
    Repo.transaction(fn ->
      head = lock_head!(user_id)
      head |> Ecto.Changeset.change(generation: head.generation + 1) |> Repo.update!()
    end)
  end

  defp execute_locked(user_id, command_id, actor_id, actor_sequence, payload_hash, handler) do
    # All paths that need both rows lock the per-user head before an actor. The
    # acknowledgement path uses the same order, preventing actor/head deadlocks.
    ensure_head!(user_id)
    head = lock_head!(user_id)

    case lock_actor(user_id, actor_id) do
      nil ->
        Repo.rollback(:unknown_actor)

      actor ->
        case receipt_for_command(user_id, command_id) do
          %CommandReceipt{} = receipt ->
            replay_or_adopt(receipt, actor, actor_sequence, payload_hash)

          nil ->
            sequence_or_apply(
              actor,
              command_id,
              actor_sequence,
              payload_hash,
              head,
              handler
            )
        end
    end
  end

  defp replay_or_adopt(receipt, actor, actor_sequence, payload_hash) do
    cond do
      receipt.actor_id == actor.id ->
        exact_replay_or_reject(receipt, actor_sequence, payload_hash)

      adopted_receipt?(receipt, actor, actor_sequence, payload_hash) ->
        replay_response(receipt)

      adoptable_receipt?(receipt, actor, actor_sequence, payload_hash) ->
        adopt_receipt!(receipt, actor, actor_sequence)
        replay_response(receipt)

      true ->
        Repo.rollback(:idempotency_collision)
    end
  end

  defp exact_replay_or_reject(receipt, actor_sequence, payload_hash) do
    if receipt.actor_sequence == actor_sequence and receipt.canonical_payload_hash == payload_hash,
      do: replay_response(receipt),
      else: Repo.rollback(:idempotency_collision)
  end

  defp adopted_receipt?(receipt, actor, actor_sequence, payload_hash) do
    receipt.actor_sequence == actor_sequence and receipt.canonical_payload_hash == payload_hash and
      Repo.exists?(
        from adoption in ReceiptAdoption,
          where:
            adoption.user_id == ^actor.user_id and adoption.actor_id == ^actor.id and
              adoption.command_id == ^receipt.command_id and
              adoption.actor_sequence == ^actor_sequence
      )
  end

  defp adoptable_receipt?(receipt, actor, actor_sequence, payload_hash) do
    original_actor =
      Repo.one(
        from original in Actor,
          where: original.id == ^receipt.actor_id and original.user_id == ^actor.user_id
      )

    not is_nil(original_actor) and receipt.actor_sequence == actor_sequence and
      receipt.canonical_payload_hash == payload_hash and
      actor.next_expected_sequence == actor_sequence and
      actor.installation_id == original_actor.installation_id and
      actor.incarnation > original_actor.incarnation
  end

  defp adopt_receipt!(receipt, actor, actor_sequence) do
    %ReceiptAdoption{}
    |> ReceiptAdoption.changeset(
      %{actor_sequence: actor_sequence},
      actor.user_id,
      actor.id,
      receipt.command_id
    )
    |> Repo.insert!()

    actor
    |> Ecto.Changeset.change(
      next_expected_sequence: actor_sequence + 1,
      last_seen_at: DateTime.utc_now(:second)
    )
    |> Repo.update!()

    :ok
  end

  # `duplicate` is safe only for an originally accepted command. Replaying a
  # durable rejection preserves that rejection, including through adoption.
  defp replay_response(receipt) do
    status =
      if receipt.status == "accepted",
        do: :duplicate,
        else: String.to_existing_atom(receipt.status)

    response(status, receipt)
  end

  defp sequence_or_apply(actor, command_id, actor_sequence, payload_hash, head, handler) do
    cond do
      actor_sequence < actor.next_expected_sequence ->
        Repo.rollback(:actor_fork)

      actor_sequence > actor.next_expected_sequence ->
        Repo.rollback({:sequence_gap, actor.next_expected_sequence})

      true ->
        apply_next_command(actor, command_id, actor_sequence, payload_hash, head, handler)
    end
  end

  defp apply_next_command(actor, command_id, actor_sequence, payload_hash, head, handler) do
    next_revision = head.revision + 1

    case handler.(next_revision) do
      {:ok, effect} when is_map(effect) ->
        with {:ok, effect_hash} <- CanonicalJSON.hash(effect),
             {:ok, receipt} <-
               insert_receipt("accepted", %{
                 command_id: command_id,
                 user_id: actor.user_id,
                 actor_id: actor.id,
                 actor_sequence: actor_sequence,
                 canonical_payload_hash: payload_hash,
                 result_revision: next_revision,
                 canonical_effect: effect,
                 canonical_effect_hash: effect_hash
               }) do
          actor
          |> Ecto.Changeset.change(
            next_expected_sequence: actor_sequence + 1,
            last_seen_at: DateTime.utc_now(:second)
          )
          |> Repo.update!()

          head
          |> Ecto.Changeset.change(revision: next_revision)
          |> Repo.update!()

          response(:accepted, receipt)
        else
          {:error, %Ecto.Changeset{}} -> Repo.rollback(:command_identity_collision)
          {:error, reason} -> Repo.rollback(reason)
        end

      {:reject, status, effect} when is_atom(status) and is_map(effect) ->
        with {:ok, effect_hash} <- CanonicalJSON.hash(effect),
             {:ok, receipt} <-
               insert_receipt(Atom.to_string(status), %{
                 command_id: command_id,
                 user_id: actor.user_id,
                 actor_id: actor.id,
                 actor_sequence: actor_sequence,
                 canonical_payload_hash: payload_hash,
                 result_revision: head.revision,
                 canonical_effect: effect,
                 canonical_effect_hash: effect_hash
               }) do
          actor
          |> Ecto.Changeset.change(
            next_expected_sequence: actor_sequence + 1,
            last_seen_at: DateTime.utc_now(:second)
          )
          |> Repo.update!()

          response(status, receipt)
        else
          {:error, %Ecto.Changeset{}} -> Repo.rollback(:command_identity_collision)
          {:error, reason} -> Repo.rollback(reason)
        end

      {:reject_with_revision, status, effect} when is_atom(status) and is_map(effect) ->
        with {:ok, effect_hash} <- CanonicalJSON.hash(effect),
             {:ok, receipt} <-
               insert_receipt(Atom.to_string(status), %{
                 command_id: command_id,
                 user_id: actor.user_id,
                 actor_id: actor.id,
                 actor_sequence: actor_sequence,
                 canonical_payload_hash: payload_hash,
                 result_revision: next_revision,
                 canonical_effect: effect,
                 canonical_effect_hash: effect_hash
               }) do
          actor
          |> Ecto.Changeset.change(
            next_expected_sequence: actor_sequence + 1,
            last_seen_at: DateTime.utc_now(:second)
          )
          |> Repo.update!()

          head
          |> Ecto.Changeset.change(revision: next_revision)
          |> Repo.update!()

          response(status, receipt)
        else
          {:error, %Ecto.Changeset{}} -> Repo.rollback(:command_identity_collision)
          {:error, reason} -> Repo.rollback(reason)
        end

      {:error, reason} ->
        Repo.rollback(reason)

      _other ->
        Repo.rollback(:invalid_handler_result)
    end
  end

  defp insert_receipt(status, attrs) do
    %CommandReceipt{}
    |> CommandReceipt.terminal_changeset(attrs, attrs.user_id, attrs.actor_id, status)
    |> Repo.insert()
  end

  defp ensure_head!(user_id) do
    %Head{user_id: user_id}
    |> Head.changeset(%{})
    |> Repo.insert!(on_conflict: :nothing, conflict_target: :user_id)
  end

  defp lock_head!(user_id) do
    Repo.one!(from head in Head, where: head.user_id == ^user_id, lock: "FOR UPDATE")
  end

  defp lock_actor(user_id, actor_id) do
    Repo.one(
      from actor in Actor,
        where: actor.id == ^actor_id and actor.user_id == ^user_id,
        lock: "FOR UPDATE"
    )
  end

  defp receipt_for_command(user_id, command_id) do
    Repo.one(
      from receipt in CommandReceipt,
        where: receipt.command_id == ^command_id and receipt.user_id == ^user_id
    )
  end

  defp response(status, receipt) do
    %{
      status: status,
      command_id: receipt.command_id,
      revision: receipt.result_revision,
      effect: receipt.canonical_effect
    }
  end

  defp normalize_transaction({:ok, response}), do: {:ok, response}
  defp normalize_transaction({:error, reason}), do: {:error, reason}

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
      _other -> {:error, :invalid_uuid_v4}
    end
  end

  defp uuid_v4(_value), do: {:error, :invalid_uuid_v4}

  defp positive_integer(value) when is_integer(value) and value > 0 and value <= @max_int64,
    do: {:ok, value}

  defp positive_integer(value) when is_binary(value) do
    if byte_size(value) <= 19 and Regex.match?(~r/\A[1-9][0-9]*\z/, value) do
      value |> String.to_integer() |> positive_integer()
    else
      {:error, :invalid_actor_sequence}
    end
  end

  defp positive_integer(_value), do: {:error, :invalid_actor_sequence}

  defp non_negative_integer(value) when is_integer(value) and value >= 0 and value <= @max_int64,
    do: {:ok, value}

  defp non_negative_integer(value) when is_binary(value) do
    if byte_size(value) <= 19 and Regex.match?(~r/\A(0|[1-9][0-9]*)\z/, value) do
      value |> String.to_integer() |> non_negative_integer()
    else
      {:error, :invalid_revision}
    end
  end

  defp non_negative_integer(_value), do: {:error, :invalid_revision}

  defp terminal_rejection(status, reason) do
    {:reject, status, %{"reason" => Atom.to_string(reason)}}
  end

  defp drop_ownership(attrs) do
    Map.drop(attrs, [:user_id, "user_id", :next_expected_sequence, "next_expected_sequence"])
  end

  defp value(attrs, key), do: Map.get(attrs, key) || Map.get(attrs, Atom.to_string(key))
end
