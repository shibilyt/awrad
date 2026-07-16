defmodule AwradApi.ProgressSync.CountLedger do
  @moduledoc false

  import Ecto.Query

  alias AwradApi.ProgressSync.{
    Actor,
    CountCheckpoint,
    CountConsumption,
    CountCredit,
    CountProjection,
    CompletionProjector,
    EntityStore,
    Head,
    ReceiptAdoption
  }

  alias AwradApi.Repo
  alias AwradApi.Tracking.{Goal, GoalSlot}

  @max_int64 9_223_372_036_854_775_807
  @max_active_credits 1_000
  @max_compaction_credits 10_000

  def apply(user_id, command_attrs, revision) do
    payload = value(command_attrs, :payload)

    with true <- is_map(payload),
         {:ok, command_id} <- uuid_v4(value(command_attrs, :command_id)),
         {:ok, actor_id} <- uuid_v4(value(command_attrs, :actor_id)),
         {:ok, actor_sequence} <- integer(value(command_attrs, :actor_sequence), positive: true),
         {:ok, bucket} <- bucket(payload),
         :ok <- supported_incarnation(user_id, bucket),
         :ok <- owned_bucket(user_id, bucket) do
      case value(payload, :type) do
        "increment" ->
          apply_increment(
            user_id,
            command_id,
            actor_id,
            actor_sequence,
            bucket,
            payload,
            revision
          )

        type when type in ["decrement_bucket", "reset_bucket_observed"] ->
          case apply_correction(
                 user_id,
                 command_id,
                 actor_id,
                 actor_sequence,
                 bucket,
                 payload,
                 revision,
                 type
               ) do
            {:error, :stale_basis} ->
              {:reject, :stale_basis, current_effect(user_id, bucket, type, "stale_basis")}

            result ->
              result
          end

        _other ->
          {:error, :unsupported_count_command}
      end
    else
      false -> {:error, :invalid_count_payload}
      {:error, reason} -> {:error, reason}
    end
  end

  def repair_projection(user_id, bucket_attrs) do
    with {:ok, bucket} <- bucket(bucket_attrs) do
      Repo.transaction(fn ->
        with :ok <- supported_incarnation(user_id, bucket),
             :ok <- owned_bucket(user_id, bucket),
             %Head{} = head <-
               Repo.one(from head in Head, where: head.user_id == ^user_id, lock: "FOR UPDATE"),
             projection <- projection!(user_id, bucket),
             {:ok, state} <- ledger_state(user_id, bucket),
             {:ok, count} <- ledger_total(state) do
          if projection.count == count do
            %{status: :unchanged, revision: head.revision, count: count}
          else
            revision = head.revision + 1

            projection
            |> CountProjection.update_changeset(count, revision)
            |> Repo.update!()

            :ok =
              CompletionProjector.refresh(
                user_id,
                bucket.goal_id,
                bucket.entity_incarnation,
                revision
              )

            head
            |> Ecto.Changeset.change(revision: revision)
            |> Repo.update!()

            %{status: :repaired, revision: revision, count: count}
          end
        else
          nil -> Repo.rollback(:sync_not_initialized)
          {:error, reason} -> Repo.rollback(reason)
        end
      end)
    end
  end

  def compact_bucket(user_id, bucket_attrs) do
    with {:ok, bucket} <- bucket(bucket_attrs) do
      Repo.transaction(fn ->
        with :ok <- supported_incarnation(user_id, bucket),
             :ok <- owned_bucket(user_id, bucket),
             %Head{} = head <-
               Repo.one(from head in Head, where: head.user_id == ^user_id, lock: "FOR UPDATE"),
             :ok <- actors_caught_up(user_id, head.revision),
             {:ok, result} <- compact_locked(user_id, bucket, head.revision) do
          result
        else
          nil -> Repo.rollback(:sync_not_initialized)
          {:error, reason} -> Repo.rollback(reason)
        end
      end)
    end
  end

  defp apply_increment(
         user_id,
         command_id,
         actor_id,
         actor_sequence,
         bucket,
         payload,
         revision
       ) do
    with {:ok, amount} <- integer(value(payload, :amount), positive: true) do
      projection = projection!(user_id, bucket)

      if projection.count > @max_int64 - amount do
        {:error, :count_overflow}
      else
        attrs =
          Map.merge(bucket, %{
            id: command_id,
            kind: "increment",
            actor_id: actor_id,
            actor_sequence: actor_sequence,
            accepted_revision: revision,
            amount: amount
          })

        with {:ok, _credit} <-
               %CountCredit{}
               |> CountCredit.increment_changeset(attrs, user_id)
               |> Repo.insert() do
          count = projection.count + amount

          projection
          |> CountProjection.update_changeset(count, revision)
          |> Repo.update!()

          :ok =
            CompletionProjector.refresh(
              user_id,
              bucket.goal_id,
              bucket.entity_incarnation,
              revision
            )

          {:ok,
           %{
             "type" => "increment",
             "goal_id" => bucket.goal_id,
             "slot_id" => bucket.slot_id,
             "local_date" => Date.to_iso8601(bucket.local_date),
             "entity_incarnation" => Integer.to_string(bucket.entity_incarnation),
             "applied_amount" => Integer.to_string(amount),
             "count" => Integer.to_string(count)
           }}
        end
      end
    end
  end

  defp apply_correction(
         user_id,
         command_id,
         actor_id,
         actor_sequence,
         bucket,
         payload,
         revision,
         type
       ) do
    with {:ok, basis_revision} <- integer(value(payload, :basis_revision)),
         true <- basis_revision < revision,
         {:ok, local_frontier} <- integer(value(payload, :local_frontier_sequence)),
         true <- local_frontier < actor_sequence,
         {:ok, requested} <- requested_amount(type, payload),
         {:ok, state} <- ledger_state(user_id, bucket),
         {:ok, observed_ids} <-
           observed_credit_ids(value(payload, :observed_local_credit_ids), state.sources),
         adopted_ids <-
           adopted_credit_ids(user_id, actor_id, local_frontier, state.sources),
         :ok <- valid_basis(state.checkpoint, basis_revision),
         {:ok, total_before} <- ledger_total(state) do
      eligible =
        eligible_sources(
          state,
          actor_id,
          basis_revision,
          local_frontier,
          observed_ids,
          adopted_ids
        )

      requested =
        if type == "reset_bucket_observed", do: remaining_total(eligible), else: requested

      applied = consume(user_id, command_id, eligible, requested, revision)
      count = total_before - applied
      projection = projection!(user_id, bucket)

      projection
      |> CountProjection.update_changeset(count, revision)
      |> Repo.update!()

      :ok =
        CompletionProjector.refresh(user_id, bucket.goal_id, bucket.entity_incarnation, revision)

      {:ok,
       %{
         "type" => type,
         "goal_id" => bucket.goal_id,
         "slot_id" => bucket.slot_id,
         "local_date" => Date.to_iso8601(bucket.local_date),
         "entity_incarnation" => Integer.to_string(bucket.entity_incarnation),
         "requested_amount" => Integer.to_string(requested),
         "applied_amount" => Integer.to_string(applied),
         "unapplied_amount" => Integer.to_string(requested - applied),
         "count" => Integer.to_string(count)
       }}
    else
      false -> {:error, :invalid_basis_revision}
      {:error, reason} -> {:error, reason}
    end
  end

  defp ledger_state(user_id, bucket) do
    checkpoint =
      Repo.one(
        from checkpoint in CountCheckpoint,
          where:
            checkpoint.user_id == ^user_id and checkpoint.goal_id == ^bucket.goal_id and
              checkpoint.slot_id == ^bucket.slot_id and
              checkpoint.local_date == ^bucket.local_date and
              checkpoint.entity_incarnation == ^bucket.entity_incarnation,
          lock: "FOR UPDATE"
      )

    through_revision = if checkpoint, do: checkpoint.through_revision, else: -1

    credits =
      Repo.all(
        from credit in CountCredit,
          where:
            credit.user_id == ^user_id and credit.goal_id == ^bucket.goal_id and
              credit.slot_id == ^bucket.slot_id and credit.local_date == ^bucket.local_date and
              credit.entity_incarnation == ^bucket.entity_incarnation and
              credit.kind == "increment" and credit.accepted_revision > ^through_revision,
          order_by: [asc: credit.accepted_revision, asc: credit.id],
          limit: ^(@max_active_credits + 1),
          lock: "FOR UPDATE"
      )

    if length(credits) > @max_active_credits do
      {:error, :checkpoint_required}
    else
      with {:ok, checkpoint_credit} <- checkpoint_credit(checkpoint, user_id, bucket) do
        sources = if checkpoint_credit, do: [checkpoint_credit | credits], else: credits

        with {:ok, remaining} <- remaining_sources(sources) do
          {:ok, %{checkpoint: checkpoint, sources: remaining}}
        end
      end
    end
  end

  defp compact_locked(user_id, bucket, revision) do
    checkpoint =
      Repo.one(
        from checkpoint in CountCheckpoint,
          where:
            checkpoint.user_id == ^user_id and checkpoint.goal_id == ^bucket.goal_id and
              checkpoint.slot_id == ^bucket.slot_id and
              checkpoint.local_date == ^bucket.local_date and
              checkpoint.entity_incarnation == ^bucket.entity_incarnation,
          lock: "FOR UPDATE"
      )

    through_revision = if checkpoint, do: checkpoint.through_revision, else: -1

    credits =
      Repo.all(
        from credit in CountCredit,
          where:
            credit.user_id == ^user_id and credit.goal_id == ^bucket.goal_id and
              credit.slot_id == ^bucket.slot_id and credit.local_date == ^bucket.local_date and
              credit.entity_incarnation == ^bucket.entity_incarnation and
              credit.kind == "increment" and credit.accepted_revision > ^through_revision and
              credit.accepted_revision <= ^revision,
          order_by: [asc: credit.accepted_revision, asc: credit.id],
          limit: ^(@max_compaction_credits + 1),
          lock: "FOR UPDATE"
      )

    cond do
      length(credits) > @max_compaction_credits ->
        {:error, :compaction_batch_required}

      checkpoint && checkpoint.through_revision == revision && credits == [] ->
        {:ok, %{status: :unchanged, through_revision: revision}}

      true ->
        with {:ok, checkpoint_credit} <- checkpoint_credit(checkpoint, user_id, bucket),
             sources <- if(checkpoint_credit, do: [checkpoint_credit | credits], else: credits),
             {:ok, remaining} <- remaining_sources(sources),
             {:ok, total} <- ledger_total(%{sources: remaining}),
             projection <- projection!(user_id, bucket),
             true <- projection.count == total do
          if sources == [] do
            {:ok, %{status: :unchanged, through_revision: through_revision}}
          else
            install_checkpoint(user_id, bucket, checkpoint, sources, total, revision)
          end
        else
          false -> {:error, :projection_repair_required}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp install_checkpoint(user_id, bucket, checkpoint, sources, total, revision) do
    checkpoint_credit_id = Ecto.UUID.generate()

    %CountCredit{}
    |> CountCredit.checkpoint_changeset(
      Map.merge(bucket, %{
        id: checkpoint_credit_id,
        kind: "checkpoint",
        accepted_revision: revision,
        amount: total
      }),
      user_id
    )
    |> Repo.insert!()

    checkpoint_attrs =
      Map.merge(bucket, %{through_revision: revision, credit_id: checkpoint_credit_id})

    if checkpoint do
      checkpoint
      |> CountCheckpoint.advance_changeset(revision, checkpoint_credit_id)
      |> Repo.update!()
    else
      %CountCheckpoint{}
      |> CountCheckpoint.create_changeset(checkpoint_attrs, user_id)
      |> Repo.insert!()
    end

    old_credit_ids = Enum.map(sources, & &1.id)

    from(consumption in CountConsumption, where: consumption.credit_id in ^old_credit_ids)
    |> Repo.delete_all()

    from(credit in CountCredit, where: credit.id in ^old_credit_ids)
    |> Repo.delete_all()

    {:ok,
     %{
       status: :compacted,
       through_revision: revision,
       count: total,
       compacted_credit_count: length(old_credit_ids)
     }}
  end

  defp actors_caught_up(user_id, revision) do
    now = DateTime.utc_now(:second)

    minimum_safe_revision =
      Repo.one(
        from actor in Actor,
          where:
            actor.user_id == ^user_id and is_nil(actor.retired_at) and
              actor.lease_expires_at > ^now,
          select: min(actor.safe_compaction_revision)
      )

    if is_nil(minimum_safe_revision) or minimum_safe_revision == revision,
      do: :ok,
      else: {:error, {:actors_not_caught_up, minimum_safe_revision, revision}}
  end

  defp remaining_sources(sources) do
    credit_ids = Enum.map(sources, & &1.id)

    consumed =
      if credit_ids == [] do
        %{}
      else
        Repo.all(
          from consumption in CountConsumption,
            where: consumption.credit_id in ^credit_ids,
            group_by: consumption.credit_id,
            select: {consumption.credit_id, sum(consumption.amount)}
        )
        |> Map.new(fn {credit_id, amount} -> {credit_id, Decimal.to_integer(amount)} end)
      end

    remaining =
      Enum.map(sources, fn credit ->
        %{credit: credit, remaining: credit.amount - Map.get(consumed, credit.id, 0)}
      end)

    if Enum.any?(remaining, &(&1.remaining < 0)),
      do: {:error, :count_ledger_corrupt},
      else: {:ok, remaining}
  end

  defp checkpoint_credit(nil, _user_id, _bucket), do: {:ok, nil}

  defp checkpoint_credit(checkpoint, user_id, bucket) do
    credit =
      Repo.one(
        from credit in CountCredit,
          where:
            credit.id == ^checkpoint.credit_id and credit.user_id == ^user_id and
              credit.goal_id == ^bucket.goal_id and credit.slot_id == ^bucket.slot_id and
              credit.local_date == ^bucket.local_date and
              credit.entity_incarnation == ^bucket.entity_incarnation and
              credit.kind == "checkpoint" and
              credit.accepted_revision == ^checkpoint.through_revision,
          lock: "FOR UPDATE"
      )

    if credit, do: {:ok, credit}, else: {:error, :count_ledger_corrupt}
  end

  defp eligible_sources(
         state,
         actor_id,
         basis_revision,
         local_frontier,
         observed_ids,
         adopted_ids
       ) do
    Enum.filter(state.sources, fn %{credit: credit, remaining: remaining} ->
      remaining > 0 and
        (credit.accepted_revision <= basis_revision or MapSet.member?(observed_ids, credit.id) or
           MapSet.member?(adopted_ids, credit.id) or
           (credit.kind == "increment" and credit.actor_id == actor_id and
              credit.actor_sequence <= local_frontier))
    end)
  end

  # Recovery actors inherit only the exact immutable commands they durably
  # adopted. Intersecting adoption rows with the bounded active ledger tail
  # avoids loading an installation's unbounded command history.
  defp adopted_credit_ids(user_id, actor_id, local_frontier, sources) do
    active_credit_ids =
      sources
      |> Enum.filter(&(&1.credit.kind == "increment"))
      |> Enum.map(& &1.credit.id)

    if active_credit_ids == [] do
      MapSet.new()
    else
      Repo.all(
        from adoption in ReceiptAdoption,
          where:
            adoption.user_id == ^user_id and adoption.actor_id == ^actor_id and
              adoption.actor_sequence <= ^local_frontier and
              adoption.command_id in ^active_credit_ids,
          select: adoption.command_id
      )
      |> MapSet.new()
    end
  end

  defp consume(user_id, command_id, sources, requested, revision) do
    {applied, _remaining_request} =
      Enum.reduce_while(sources, {0, requested}, fn
        _source, {applied, 0} ->
          {:halt, {applied, 0}}

        %{credit: credit, remaining: remaining}, {applied, request_left} ->
          amount = min(remaining, request_left)

          %CountConsumption{}
          |> CountConsumption.changeset(
            %{
              correction_command_id: command_id,
              credit_id: credit.id,
              accepted_revision: revision,
              amount: amount
            },
            user_id
          )
          |> Repo.insert!()

          {:cont, {applied + amount, request_left - amount}}
      end)

    applied
  end

  defp projection!(user_id, bucket) do
    query =
      from projection in CountProjection,
        where:
          projection.user_id == ^user_id and projection.goal_id == ^bucket.goal_id and
            projection.slot_id == ^bucket.slot_id and
            projection.local_date == ^bucket.local_date and
            projection.entity_incarnation == ^bucket.entity_incarnation,
        lock: "FOR UPDATE"

    case Repo.one(query) do
      nil ->
        %CountProjection{}
        |> CountProjection.create_changeset(
          Map.merge(bucket, %{count: 0, sync_revision: 0}),
          user_id
        )
        |> Repo.insert!()

      projection ->
        projection
    end
  end

  defp owned_bucket(user_id, bucket) do
    exists? =
      Repo.exists?(
        from slot in GoalSlot,
          join: goal in Goal,
          on: goal.id == slot.goal_id,
          where:
            goal.id == ^bucket.goal_id and goal.user_id == ^user_id and
              is_nil(goal.deleted_at) and slot.id == ^bucket.slot_id
      )

    if exists?, do: :ok, else: {:error, :invalid_count_bucket}
  end

  defp bucket(attrs) when is_map(attrs) do
    with {:ok, goal_id} <- uuid_v4(value(attrs, :goal_id)),
         {:ok, slot_id} <- uuid_v4(value(attrs, :slot_id)),
         {:ok, local_date} <- local_date(value(attrs, :local_date)),
         {:ok, incarnation} <- integer(value(attrs, :entity_incarnation), positive: true) do
      {:ok,
       %{
         goal_id: goal_id,
         slot_id: slot_id,
         local_date: local_date,
         entity_incarnation: incarnation
       }}
    end
  end

  defp bucket(_attrs), do: {:error, :invalid_count_bucket}

  defp requested_amount("decrement_bucket", payload),
    do: integer(value(payload, :amount), positive: true)

  defp requested_amount("reset_bucket_observed", payload) do
    if is_nil(value(payload, :amount)), do: {:ok, 0}, else: {:error, :invalid_count_payload}
  end

  defp valid_basis(nil, _basis_revision), do: :ok

  defp valid_basis(checkpoint, basis_revision) do
    if basis_revision >= checkpoint.through_revision, do: :ok, else: {:error, :stale_basis}
  end

  defp ledger_total(state) do
    total = remaining_total(state.sources)
    if total <= @max_int64, do: {:ok, total}, else: {:error, :count_overflow}
  end

  defp remaining_total(sources), do: Enum.reduce(sources, 0, &(&1.remaining + &2))

  defp current_effect(user_id, bucket, type, reason) do
    count =
      Repo.one(
        from projection in CountProjection,
          where:
            projection.user_id == ^user_id and projection.goal_id == ^bucket.goal_id and
              projection.slot_id == ^bucket.slot_id and
              projection.local_date == ^bucket.local_date and
              projection.entity_incarnation == ^bucket.entity_incarnation,
          select: projection.count
      ) || 0

    %{
      "type" => type,
      "reason" => reason,
      "goal_id" => bucket.goal_id,
      "slot_id" => bucket.slot_id,
      "local_date" => Date.to_iso8601(bucket.local_date),
      "entity_incarnation" => Integer.to_string(bucket.entity_incarnation),
      "count" => Integer.to_string(count)
    }
  end

  defp supported_incarnation(user_id, bucket) do
    case EntityStore.active_incarnation(user_id, bucket.goal_id) do
      {:ok, incarnation} when incarnation == bucket.entity_incarnation -> :ok
      {:ok, _other} -> {:error, :unsupported_entity_incarnation}
      {:error, :entity_missing} -> {:error, :invalid_count_bucket}
      {:error, reason} -> {:error, reason}
    end
  end

  defp local_date(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> {:ok, date}
      {:error, _reason} -> {:error, :invalid_local_date}
    end
  end

  defp local_date(%Date{} = value), do: {:ok, value}
  defp local_date(_value), do: {:error, :invalid_local_date}

  defp integer(value, options \\ [])

  defp integer(value, options) when is_integer(value) do
    positive? = Keyword.get(options, :positive, false)

    if value >= 0 and value <= @max_int64 and (not positive? or value > 0),
      do: {:ok, value},
      else: {:error, :invalid_int64}
  end

  defp integer(value, options) when is_binary(value) do
    if byte_size(value) <= 19 and Regex.match?(~r/\A(0|[1-9][0-9]*)\z/, value) do
      integer(String.to_integer(value), options)
    else
      {:error, :invalid_int64}
    end
  end

  defp integer(_value, _options), do: {:error, :invalid_int64}

  # Explicit observations are needed only for foreign or otherwise unordered
  # credits. Validate every wire UUID, but retain only IDs from the bounded
  # active ledger tail so request cardinality cannot force unbounded server
  # state and clients never get stuck behind an arbitrary item-count limit.
  defp observed_credit_ids(values, sources) when is_list(values) do
    active_credit_ids = MapSet.new(sources, & &1.credit.id)

    Enum.reduce_while(values, {:ok, MapSet.new()}, fn value, {:ok, ids} ->
      case uuid_v4(value) do
        {:ok, id} ->
          retained =
            if MapSet.member?(active_credit_ids, id), do: MapSet.put(ids, id), else: ids

          {:cont, {:ok, retained}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  defp observed_credit_ids(_values, _sources), do: {:error, :invalid_observed_credits}

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

  defp value(attrs, key), do: Map.get(attrs, key) || Map.get(attrs, Atom.to_string(key))
end
