defmodule AwradServerWeb.Api.PracticeSettingsController do
  use AwradServerWeb, :controller

  alias AwradServer.Accounts.AuthRateLimiter
  alias AwradServer.PracticeSettings

  def show(conn, %{"installation_id" => installation_id}) do
    with {:ok, installation_id} <- uuid_v4(installation_id),
         :ok <- installation_matches_session(conn, installation_id) do
      json(conn, PracticeSettings.snapshot(conn.assigns.current_scope, installation_id))
    else
      {:error, :installation_mismatch} -> error(conn, 422, "installation_mismatch")
      {:error, :invalid_uuid_v4} -> error(conn, 422, "invalid_installation_id")
      _ -> error(conn, 422, "invalid_installation_id")
    end
  end

  def show(conn, _params), do: error(conn, 422, "invalid_installation_id")

  def update_policy(conn, params) do
    with {:ok, installation_id} <- uuid_v4(params["installation_id"]),
         :ok <- installation_matches_session(conn, installation_id),
         {:ok, expected_revision} <- positive_integer(params["expected_revision"]),
         policy when is_map(policy) <- params["policy"],
         {:ok, _updated} <-
           PracticeSettings.update_policy(
             conn.assigns.current_scope,
             policy,
             expected_revision
           ) do
      json(conn, PracticeSettings.snapshot(conn.assigns.current_scope, installation_id))
    else
      {:error, {:policy_conflict, policy}} ->
        error(conn, 409, "practice_policy_conflict", %{policy: policy})

      {:error, %Ecto.Changeset{} = changeset} ->
        error(conn, 422, "invalid_practice_policy", %{errors: changeset_errors(changeset)})

      {:error, :installation_mismatch} ->
        error(conn, 422, "installation_mismatch")

      {:error, :invalid_uuid_v4} ->
        error(conn, 422, "invalid_installation_id")

      {:error, :invalid_installation_id} ->
        error(conn, 422, "invalid_installation_id")

      {:error, :invalid_policy_revision} ->
        error(conn, 422, "invalid_policy_revision")

      _ ->
        error(conn, 422, "invalid_practice_policy")
    end
  end

  def update_device_context(conn, params) do
    with {:ok, installation_id} <- uuid_v4(params["installation_id"]),
         :ok <- installation_matches_session(conn, installation_id),
         context when is_map(context) <- params["device_context"],
         {:ok, _updated} <-
           PracticeSettings.upsert_device_context(
             conn.assigns.current_scope,
             installation_id,
             context
           ) do
      json(conn, PracticeSettings.snapshot(conn.assigns.current_scope, installation_id))
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        error(conn, 422, "invalid_device_context", %{errors: changeset_errors(changeset)})

      {:error, :installation_mismatch} ->
        error(conn, 422, "installation_mismatch")

      {:error, :invalid_uuid_v4} ->
        error(conn, 422, "invalid_installation_id")

      {:error, :invalid_installation_id} ->
        error(conn, 422, "invalid_installation_id")

      _ ->
        error(conn, 422, "invalid_device_context")
    end
  end

  defp positive_integer(value) when is_integer(value) and value > 0, do: {:ok, value}

  defp positive_integer(value) when is_binary(value) and byte_size(value) <= 9 do
    case Integer.parse(value) do
      {value, ""} when value > 0 -> {:ok, value}
      _ -> {:error, :invalid_policy_revision}
    end
  end

  defp positive_integer(_value), do: {:error, :invalid_policy_revision}

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

  defp uuid_v4(_value), do: {:error, :invalid_uuid_v4}

  defp installation_matches_session(conn, installation_id) do
    expected = AuthRateLimiter.subject_hash("device:" <> installation_id)

    if conn.assigns.current_session.device_id_hash == expected,
      do: :ok,
      else: {:error, :installation_mismatch}
  end

  defp changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, options} ->
      Enum.reduce(options, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  defp error(conn, status, code, details \\ %{}) do
    conn
    |> put_status(status)
    |> json(Map.merge(%{error: code}, details))
  end
end
