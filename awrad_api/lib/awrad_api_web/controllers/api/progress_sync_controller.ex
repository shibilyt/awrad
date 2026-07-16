defmodule AwradApiWeb.Api.ProgressSyncController do
  use AwradApiWeb, :controller

  alias AwradApi.ProgressSync
  alias AwradApi.ProgressSync.Transfer
  alias AwradApi.Accounts.AuthRateLimiter
  alias AwradApi.Repo

  @max_commands 100
  @max_capabilities 32

  def commands(conn, params) do
    with :ok <- enabled(),
         :ok <- header(params["header"]),
         {:ok, installation_id} <- uuid_v4(params["installation_id"]),
         :ok <- installation_matches_session(conn, installation_id),
         commands when is_list(commands) <- params["commands"],
         true <- commands != [] and length(commands) <= @max_commands,
         {:ok, internal_commands} <- normalize_commands(commands),
         :ok <- register_actors(conn.assigns.current_scope, installation_id, internal_commands),
         {:ok, receipts} <- execute_commands(conn.assigns.current_scope, internal_commands) do
      json(conn, %{
        header: response_header(),
        receipts: receipts
      })
    else
      false ->
        error(conn, 422, "invalid_command_batch")

      nil ->
        error(conn, 422, "invalid_command_batch")

      {:error, {:sequence_gap, expected}} ->
        error(conn, 409, "sequence_gap", %{expected_sequence: Integer.to_string(expected)})

      {:error, reason} ->
        command_error(conn, reason)

      _ ->
        error(conn, 422, "invalid_command_batch")
    end
  end

  def snapshot(conn, params), do: start_transfer(conn, params, "snapshot")
  def delta(conn, params), do: start_transfer(conn, params, "delta")

  def acknowledge(conn, params) do
    with :ok <- enabled(),
         :ok <- header(params["header"]),
         {:ok, actor_id} <- uuid_v4(params["actor_id"]),
         {:ok, installation_id} <- uuid_v4(params["installation_id"]),
         {:ok, starting_sequence} <- int64(params["starting_sequence"], 1),
         :ok <- installation_matches_session(conn, installation_id),
         {:ok, _actor} <-
           ProgressSync.register_actor(conn.assigns.current_scope, %{
             id: actor_id,
             installation_id: installation_id,
             incarnation: 1,
             starting_sequence: starting_sequence
           }),
         {:ok, actor} <-
           ProgressSync.acknowledge_actor(conn.assigns.current_scope, actor_id, %{
             applied_revision: params["applied_revision"],
             safe_compaction_revision: params["safe_compaction_revision"]
           }) do
      json(conn, %{
        header: response_header(),
        actor_id: actor.id,
        applied_revision: Integer.to_string(actor.applied_revision),
        safe_compaction_revision: Integer.to_string(actor.safe_compaction_revision)
      })
    else
      {:error, reason} -> command_error(conn, reason)
      _ -> error(conn, 422, "invalid_actor_acknowledgement")
    end
  end

  def page(conn, %{"id" => id, "page" => page}) do
    with :ok <- enabled(),
         {:ok, id} <- uuid_v4(id),
         {page, ""} when page > 0 <- Integer.parse(page),
         {:ok, response} <- Transfer.page(conn.assigns.current_scope, id, page) do
      json(conn, Map.put(response, "header", response_header()))
    else
      {:error, :sync_disabled} -> error(conn, 503, "sync_disabled")
      {:error, :transfer_not_found} -> error(conn, 410, "transfer_expired_or_missing")
      _ -> error(conn, 422, "invalid_transfer_page")
    end
  end

  defp start_transfer(conn, params, kind) do
    with :ok <- enabled(),
         :ok <- header(params["header"]),
         true <- is_nil(params["kind"]) or params["kind"] == kind,
         {:ok, response} <-
           Transfer.start(conn.assigns.current_scope, kind, params["cursor"],
             allow_unchanged:
               kind == "delta" and
                 "unchanged_delta" in params["header"]["capabilities"]
           ) do
      json(conn, Map.put(response, "header", response_header()))
    else
      false ->
        error(conn, 422, "invalid_transfer_kind")

      {:error, reason} when reason in [:generation_reset, :invalid_cursor, :future_cursor] ->
        error(conn, 409, "generation_reset")

      {:error, reason}
      when reason in [:snapshot_cursor_not_allowed] ->
        error(conn, 422, Atom.to_string(reason))

      {:error, :transfer_quota_exceeded} ->
        error(conn, 429, "transfer_quota_exceeded")

      {:error, :transfer_too_large} ->
        error(conn, 413, "transfer_too_large")

      {:error, reason} ->
        error(conn, 503, Atom.to_string(reason))
    end
  end

  defp normalize_commands(commands) do
    Enum.reduce_while(commands, {:ok, []}, fn command, {:ok, acc} ->
      with true <- is_map(command),
           {:ok, command_id} <- uuid_v4(command["command_id"]),
           {:ok, actor_id} <- uuid_v4(command["actor_id"]),
           {:ok, actor_sequence} <- int64(command["actor_sequence"], 1),
           type when is_binary(type) <- command["type"] do
        payload = Map.drop(command, ~w(command_id actor_id actor_sequence))

        normalized = %{
          command_id: command_id,
          actor_id: actor_id,
          actor_sequence: Integer.to_string(actor_sequence),
          payload: payload
        }

        {:cont, {:ok, [normalized | acc]}}
      else
        _ -> {:halt, {:error, :invalid_command_identity}}
      end
    end)
    |> case do
      {:ok, normalized} -> {:ok, Enum.reverse(normalized)}
      error -> error
    end
  end

  defp register_actors(scope, installation_id, commands) do
    commands
    |> Enum.group_by(& &1.actor_id)
    |> Enum.reduce_while(:ok, fn {actor_id, actor_commands}, :ok ->
      starting_sequence =
        actor_commands |> Enum.map(&String.to_integer(&1.actor_sequence)) |> Enum.min()

      case ProgressSync.register_actor(scope, %{
             id: actor_id,
             installation_id: installation_id,
             incarnation: 1,
             starting_sequence: starting_sequence
           }) do
        {:ok, _actor} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp execute_commands(scope, commands) do
    Repo.transaction(fn ->
      Enum.reduce_while(commands, [], fn command, receipts ->
        case ProgressSync.execute_progress_command(scope, command) do
          {:ok, receipt} -> {:cont, [receipt_json(receipt) | receipts]}
          {:error, reason} -> Repo.rollback(reason)
        end
      end)
      |> Enum.reverse()
    end)
    |> case do
      {:ok, receipts} -> {:ok, receipts}
      {:error, reason} -> {:error, reason}
    end
  end

  defp receipt_json(receipt) do
    %{
      command_id: receipt.command_id,
      status: Atom.to_string(receipt.status),
      result_revision: Integer.to_string(receipt.revision),
      canonical_effect: receipt.effect
    }
  end

  defp header(%{
         "protocol_version" => 1,
         "progress_model_version" => 1,
         "capabilities" => capabilities
       })
       when is_list(capabilities) and length(capabilities) <= @max_capabilities do
    if Enum.uniq(capabilities) == capabilities and
         Enum.all?(
           capabilities,
           &(is_binary(&1) and byte_size(&1) <= 64 and Regex.match?(~r/\A[a-z0-9_]+\z/, &1))
         ) do
      :ok
    else
      {:error, :invalid_protocol_header}
    end
  end

  defp header(_), do: {:error, :invalid_protocol_header}

  defp response_header do
    %{
      protocol_version: 1,
      progress_model_version: 1,
      capabilities: [
        "count_ledger",
        "entity_occ",
        "materialized_transfers",
        "unchanged_delta"
      ]
    }
  end

  defp enabled do
    if Application.get_env(:awrad_api, :progress_sync_enabled, true),
      do: :ok,
      else: {:error, :sync_disabled}
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
  defp int64(value, minimum) when is_integer(value) and value >= minimum, do: {:ok, value}

  defp int64(value, minimum) when is_binary(value) and byte_size(value) <= 19 do
    case Integer.parse(value) do
      {integer, ""} when integer >= minimum and integer <= 9_223_372_036_854_775_807 ->
        {:ok, integer}

      _ ->
        {:error, :invalid_int64}
    end
  end

  defp int64(_, _), do: {:error, :invalid_int64}

  defp command_error(conn, reason)
       when reason in [:actor_fork, :idempotency_collision, :actor_identity_collision] do
    error(conn, 409, Atom.to_string(reason))
  end

  defp command_error(conn, reason)
       when reason in [:checkpoint_required, :sync_disabled] do
    error(conn, 503, Atom.to_string(reason))
  end

  defp command_error(conn, :actor_quota_exceeded),
    do: error(conn, 429, "actor_quota_exceeded")

  defp command_error(conn, reason), do: error(conn, 422, Atom.to_string(reason))

  defp installation_matches_session(conn, installation_id) do
    expected = AuthRateLimiter.subject_hash("device:" <> installation_id)

    if conn.assigns.current_session.device_id_hash == expected,
      do: :ok,
      else: {:error, :installation_mismatch}
  end

  defp error(conn, status, code, details \\ %{}) do
    conn
    |> put_status(status)
    |> json(Map.merge(%{error: code}, details))
  end
end
