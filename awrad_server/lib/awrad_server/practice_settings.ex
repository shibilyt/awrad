defmodule AwradServer.PracticeSettings do
  @moduledoc """
  Canonical account practice policy and per-installation device context.

  The policy is shared across a user's devices. Location, timezone, and
  browser location metadata are owned by the `(user_id, installation_id)`
  device context and are never copied into the account policy.
  """

  import Ecto.Query
  import Ecto.Changeset

  alias AwradServer.Accounts.{Scope, User}
  alias AwradServer.PracticeSettings.{AccountPracticePolicy, DeviceContext}
  alias AwradServer.Repo

  @uuid_v4 ~r/\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i

  @doc "Returns the account policy and the context for one browser installation."
  def snapshot(%Scope{user: %User{id: user_id}} = scope, installation_id) do
    policy = get_or_create_policy(scope)
    device_context = get_device_context(user_id, installation_id)

    %{
      policy: policy_view(policy),
      device_context: device_context && device_context_view(device_context)
    }
  end

  def snapshot(_scope, _installation_id), do: %{policy: default_policy(), device_context: nil}

  @doc "Returns the persisted shared account policy."
  def policy(%Scope{user: %User{}} = scope), do: get_or_create_policy(scope)
  def policy(_scope), do: nil

  @doc "Returns the shared policy changeset for the authenticated account."
  def policy_changeset(%AccountPracticePolicy{} = policy, attrs),
    do: AccountPracticePolicy.changeset(policy, attrs)

  @doc "Updates the shared policy and increments its canonical revision."
  def update_policy(%Scope{user: %User{id: user_id}} = scope, attrs) when is_map(attrs) do
    Repo.transaction(fn ->
      _policy = get_or_create_policy(scope)

      policy =
        Repo.one!(
          from policy in AccountPracticePolicy,
            where: policy.user_id == ^user_id,
            lock: "FOR UPDATE"
        )

      changeset = policy |> AccountPracticePolicy.changeset(attrs)
      next_revision = if changeset.changes == %{}, do: policy.revision, else: policy.revision + 1
      changeset = put_change(changeset, :revision, next_revision)

      case Repo.update(changeset) do
        {:ok, policy} -> policy
        {:error, changeset} -> Repo.rollback({:error, changeset})
      end
    end)
    |> unwrap_transaction()
  end

  def update_policy(_scope, _attrs), do: {:error, :unauthenticated}

  @doc "Updates the shared policy only when the caller still has the expected revision."
  def update_policy(
        %Scope{user: %User{id: user_id}} = scope,
        attrs,
        expected_revision
      )
      when is_map(attrs) and is_integer(expected_revision) and expected_revision > 0 do
    Repo.transaction(fn ->
      _policy = get_or_create_policy(scope)

      policy =
        Repo.one!(
          from policy in AccountPracticePolicy,
            where: policy.user_id == ^user_id,
            lock: "FOR UPDATE"
        )

      if policy.revision != expected_revision do
        Repo.rollback({:policy_conflict, policy_view(policy)})
      end

      changeset = policy |> AccountPracticePolicy.changeset(attrs)
      next_revision = if changeset.changes == %{}, do: policy.revision, else: policy.revision + 1
      changeset = put_change(changeset, :revision, next_revision)

      case Repo.update(changeset) do
        {:ok, policy} -> policy
        {:error, changeset} -> Repo.rollback({:error, changeset})
      end
    end)
    |> unwrap_transaction()
  end

  def update_policy(_scope, _attrs, _expected_revision), do: {:error, :invalid_policy_revision}

  @doc "Upserts this installation's timezone and optional browser location."
  def upsert_device_context(
        %Scope{user: %User{id: user_id}},
        installation_id,
        attrs
      )
      when is_map(attrs) do
    with {:ok, installation_id} <- uuid_v4(installation_id) do
      Repo.transaction(fn ->
        existing =
          Repo.one(
            from context in DeviceContext,
              where: context.user_id == ^user_id and context.installation_id == ^installation_id,
              lock: "FOR UPDATE"
          )

        now = DateTime.utc_now(:second)

        context_attrs =
          attrs
          |> normalize_context_attrs()
          |> Map.put(:last_seen_at, now)

        changeset =
          (existing ||
             %DeviceContext{
               user_id: user_id,
               installation_id: installation_id,
               revision: 1,
               last_seen_at: now
             })
          |> DeviceContext.changeset(context_attrs)
          |> put_change(:user_id, user_id)
          |> put_change(:installation_id, installation_id)
          |> put_change(:last_seen_at, now)

        semantic_fields = [
          :timezone,
          :latitude,
          :longitude,
          :accuracy_m,
          :location_name,
          :location_source
        ]

        semantic_change? = Enum.any?(semantic_fields, &Map.has_key?(changeset.changes, &1))

        next_revision =
          cond do
            is_nil(existing) -> 1
            semantic_change? -> existing.revision + 1
            true -> existing.revision
          end

        changeset = put_change(changeset, :revision, next_revision)

        case Repo.insert_or_update(changeset) do
          {:ok, context} -> context
          {:error, changeset} -> Repo.rollback({:error, changeset})
        end
      end)
      |> unwrap_transaction()
    end
  end

  def upsert_device_context(_scope, _installation_id, _attrs), do: {:error, :unauthenticated}

  @doc false
  def default_policy do
    %{day_reset: "midnight", calculation_method: "karachi", madhab: "shafi", revision: 1}
  end

  @doc false
  def device_context_view(%DeviceContext{} = context) do
    %{
      installation_id: context.installation_id,
      timezone: context.timezone,
      latitude: context.latitude,
      longitude: context.longitude,
      accuracy_m: context.accuracy_m,
      location_name: context.location_name,
      location_source: context.location_source,
      revision: context.revision,
      last_seen_at: context.last_seen_at
    }
  end

  defp get_or_create_policy(%Scope{user: %User{id: user_id}}) do
    case Repo.get_by(AccountPracticePolicy, user_id: user_id) do
      %AccountPracticePolicy{} = policy ->
        policy

      nil ->
        %AccountPracticePolicy{user_id: user_id}
        |> AccountPracticePolicy.changeset(%{})
        |> Repo.insert(on_conflict: :nothing, conflict_target: [:user_id])
        |> case do
          {:ok, %AccountPracticePolicy{id: nil}} ->
            Repo.get_by!(AccountPracticePolicy, user_id: user_id)

          {:ok, policy} ->
            policy

          {:error, _changeset} ->
            Repo.get_by!(AccountPracticePolicy, user_id: user_id)
        end
    end
  end

  defp get_device_context(user_id, installation_id) do
    case uuid_v4(installation_id) do
      {:ok, installation_id} ->
        Repo.get_by(DeviceContext, user_id: user_id, installation_id: installation_id)

      {:error, _reason} ->
        nil
    end
  end

  @doc "Returns an explicit JSON-safe view of the shared policy."
  def policy_view(%AccountPracticePolicy{} = policy) do
    %{
      day_reset: policy.day_reset,
      calculation_method: policy.calculation_method,
      madhab: policy.madhab,
      revision: policy.revision
    }
  end

  defp normalize_context_attrs(attrs) do
    Enum.reduce(attrs, %{}, fn
      {"timezone", value}, acc -> Map.put(acc, :timezone, value)
      {"latitude", value}, acc -> Map.put(acc, :latitude, value)
      {"longitude", value}, acc -> Map.put(acc, :longitude, value)
      {"accuracy_m", value}, acc -> Map.put(acc, :accuracy_m, value)
      {"location_name", value}, acc -> Map.put(acc, :location_name, value)
      {"location_source", value}, acc -> Map.put(acc, :location_source, value)
      {:timezone, value}, acc -> Map.put(acc, :timezone, value)
      {:latitude, value}, acc -> Map.put(acc, :latitude, value)
      {:longitude, value}, acc -> Map.put(acc, :longitude, value)
      {:accuracy_m, value}, acc -> Map.put(acc, :accuracy_m, value)
      {:location_name, value}, acc -> Map.put(acc, :location_name, value)
      {:location_source, value}, acc -> Map.put(acc, :location_source, value)
      {_key, _value}, acc -> acc
    end)
  end

  defp uuid_v4(value) when is_binary(value) do
    with {:ok, normalized} <- Ecto.UUID.cast(value),
         true <- Regex.match?(@uuid_v4, normalized) do
      {:ok, normalized}
    else
      _other -> {:error, :invalid_installation_id}
    end
  end

  defp uuid_v4(_value), do: {:error, :invalid_installation_id}

  defp unwrap_transaction({:ok, value}), do: {:ok, value}
  defp unwrap_transaction({:error, {:error, value}}), do: {:error, value}
  defp unwrap_transaction({:error, value}), do: {:error, value}
end
