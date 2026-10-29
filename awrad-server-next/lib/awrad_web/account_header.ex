defmodule AwradWeb.AccountHeader do
  @moduledoc """
  `X-Awrad-Account` (`contracts/api/openapi.yaml`, `AwradAccount`): the account
  a phone or browser believes it's signed in to, on the change queue and the
  audio operations. Checked after `AccountAuth` and before anything is read
  or written: missing, repeated or not an ID is `400 malformed_request`;
  another account is `409 account_mismatch`.
  """

  import Plug.Conn, only: [get_req_header: 2]

  @doc "`{:ok, user_id}` when the header names the signed-in account, else the fallback's error."
  @spec account(Plug.Conn.t()) :: {:ok, Ecto.UUID.t()} | {:error, :account_mismatch | String.t()}
  def account(conn) do
    %{id: user_id} = conn.assigns.current_scope.user

    case get_req_header(conn, "x-awrad-account") do
      [^user_id] ->
        {:ok, user_id}

      [value] ->
        if Awrad.ID.valid?(value), do: {:error, :account_mismatch}, else: invalid()

      _none_or_many ->
        invalid()
    end
  end

  defp invalid, do: {:error, "X-Awrad-Account must be one lowercase account ID"}
end
