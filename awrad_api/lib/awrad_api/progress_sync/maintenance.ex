defmodule AwradApi.ProgressSync.Maintenance do
  @moduledoc """
  Bounded, idempotent retention and count-compaction maintenance.

  Row locks with `SKIP LOCKED` make concurrent application nodes safe; each
  pass is deliberately small so maintenance cannot monopolize the database.
  """

  use GenServer
  import Ecto.Query

  alias AwradApi.ProgressSync.{
    Actor,
    CanonicalJSON,
    CommandReceipt,
    CountCheckpoint,
    CountConsumption,
    CountCredit,
    CountLedger,
    CountProjection,
    EntityConflict,
    EntityRecord,
    Head,
    Materializer,
    TransferSession
  }

  alias AwradApi.Repo

  @interval_ms :timer.minutes(15)
  @purge_batch 50
  @compaction_batch 25
  @compaction_threshold 800
  @actor_retirement_batch 200

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  def trigger do
    if pid = Process.whereis(__MODULE__), do: GenServer.cast(pid, :trigger)
    :ok
  end

  def run_once(now \\ DateTime.utc_now(:second)) do
    %{
      expired_transfers: expire_transfers(now),
      retired_actors: retire_expired_actors(now),
      purged_entities: purge_due_entities(now),
      compacted: compact_due_buckets()
    }
  end

  @impl true
  def init(:ok) do
    {:ok, schedule(%{timer_ref: nil, token: nil}, 1_000)}
  end

  @impl true
  def handle_cast(:trigger, state) do
    if state.timer_ref, do: Process.cancel_timer(state.timer_ref)
    {:noreply, schedule(%{state | timer_ref: nil, token: nil}, 0)}
  end

  @impl true
  def handle_info({:run, token}, %{token: token} = state) do
    try do
      _ = run_once()
    rescue
      error ->
        require Logger
        Logger.error("progress sync maintenance failed: #{Exception.message(error)}")
    end

    {:noreply, schedule(%{state | timer_ref: nil, token: nil}, interval_ms())}
  end

  def handle_info({:run, _stale_token}, state), do: {:noreply, state}

  defp schedule(state, delay) do
    token = make_ref()
    %{state | token: token, timer_ref: Process.send_after(self(), {:run, token}, delay)}
  end

  defp interval_ms,
    do: Application.get_env(:awrad_api, :progress_sync_maintenance_interval_ms, @interval_ms)

  defp expire_transfers(now) do
    {count, _} =
      Repo.delete_all(from session in TransferSession, where: session.expires_at <= ^now)

    count
  end

  defp retire_expired_actors(now) do
    ids =
      Repo.all(
        from actor in Actor,
          where: is_nil(actor.retired_at) and actor.lease_expires_at <= ^now,
          order_by: [asc: actor.lease_expires_at, asc: actor.id],
          limit: @actor_retirement_batch,
          select: actor.id
      )

    {count, _} =
      Repo.update_all(
        from(actor in Actor,
          where: actor.id in ^ids and is_nil(actor.retired_at) and actor.lease_expires_at <= ^now
        ),
        set: [retired_at: now, updated_at: now]
      )

    count
  end

  defp purge_due_entities(now) do
    ids =
      Repo.all(
        from entity in EntityRecord,
          where: entity.state == "deleted" and entity.purge_after <= ^now,
          order_by: [asc: entity.purge_after, asc: entity.id],
          limit: @purge_batch,
          select: entity.id
      )

    Enum.count(ids, &(purge_entity(&1, now) == :ok))
  end

  defp purge_entity(id, now) do
    user_id =
      Repo.one(from entity in EntityRecord, where: entity.id == ^id, select: entity.user_id)

    if is_nil(user_id) do
      {:error, :already_handled}
    else
      Repo.transaction(fn ->
        # Match command/ack lock order: the account head is always acquired
        # before an entity row.
        head =
          Repo.one!(from head in Head, where: head.user_id == ^user_id, lock: "FOR UPDATE")

        entity =
          Repo.one(
            from entity in EntityRecord,
              where:
                entity.id == ^id and entity.user_id == ^user_id and entity.state == "deleted" and
                  entity.purge_after <= ^now,
              lock: "FOR UPDATE SKIP LOCKED"
          )

        if is_nil(entity), do: Repo.rollback(:already_handled)

        purge_private_state(entity)

        case Materializer.purge(entity.entity_type, entity.entity_id, entity.user_id) do
          :ok -> :ok
          {:error, _reason} -> Repo.rollback(:materialized_dependency)
        end

        next_revision = head.revision + 1

        purged =
          entity
          |> Ecto.Changeset.change(
            state: "purged",
            document: nil,
            purged_at: now,
            version: entity.version + 1,
            sync_revision: next_revision
          )
          |> Repo.update!()

        # A command response can be lost immediately before the entity is
        # deleted and later purged. Redact every historical receipt only after
        # the deletion fence has its final version/revision so an ordinary or
        # adopted replay cannot resurrect private payload or stale active state.
        redact_receipts(purged)

        head |> Ecto.Changeset.change(revision: next_revision) |> Repo.update!()
      end)
      |> case do
        {:ok, _} -> :ok
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp purge_private_state(entity) do
    Repo.delete_all(
      from conflict in EntityConflict, where: conflict.entity_record_id == ^entity.id
    )

    if entity.entity_type == "goal" do
      credit_ids =
        from credit in CountCredit,
          where: credit.user_id == ^entity.user_id and credit.goal_id == ^entity.entity_id,
          select: credit.id

      Repo.delete_all(
        from consumption in CountConsumption,
          where: consumption.credit_id in subquery(credit_ids)
      )

      Repo.delete_all(
        from checkpoint in CountCheckpoint,
          where: checkpoint.user_id == ^entity.user_id and checkpoint.goal_id == ^entity.entity_id
      )

      Repo.delete_all(
        from projection in CountProjection,
          where: projection.user_id == ^entity.user_id and projection.goal_id == ^entity.entity_id
      )

      Repo.delete_all(
        from credit in CountCredit,
          where: credit.user_id == ^entity.user_id and credit.goal_id == ^entity.entity_id
      )
    end
  end

  defp redact_receipts(entity) do
    Repo.all(from receipt in CommandReceipt, where: receipt.user_id == ^entity.user_id)
    |> Enum.filter(fn receipt ->
      effect = receipt.canonical_effect
      effect["entity_id"] == entity.entity_id or effect["goal_id"] == entity.entity_id
    end)
    |> Enum.each(fn receipt ->
      effect = %{
        "kind" => "deletion_fence",
        "purged" => true,
        "entity_id" => entity.entity_id,
        "entity_type" => entity.entity_type,
        "entity_incarnation" => Integer.to_string(entity.incarnation),
        "entity_version" => Integer.to_string(entity.version),
        "state" => "purged",
        "document" => nil
      }

      {:ok, hash} = CanonicalJSON.hash(effect)

      receipt
      |> Ecto.Changeset.change(
        status: "gone",
        result_revision: entity.sync_revision,
        canonical_effect: effect,
        canonical_effect_hash: hash
      )
      |> Repo.update!()
    end)
  end

  defp compact_due_buckets do
    buckets =
      Repo.all(
        from credit in CountCredit,
          where: credit.kind == "increment",
          group_by: [
            credit.user_id,
            credit.goal_id,
            credit.slot_id,
            credit.local_date,
            credit.entity_incarnation
          ],
          having: count(credit.id) >= @compaction_threshold,
          limit: @compaction_batch,
          select: %{
            user_id: credit.user_id,
            goal_id: credit.goal_id,
            slot_id: credit.slot_id,
            local_date: credit.local_date,
            entity_incarnation: credit.entity_incarnation
          }
      )

    Enum.count(buckets, fn bucket ->
      attrs = Map.drop(bucket, [:user_id])
      match?({:ok, %{status: :compacted}}, CountLedger.compact_bucket(bucket.user_id, attrs))
    end)
  end
end
