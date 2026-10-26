defmodule Awrad.Accounts.Grant do
  @moduledoc """
  What a mobile sign-in or refresh returns (`DeviceSessionGrant` in
  `contracts/api/openapi.yaml`): the account, its device session, a 15-minute
  access token and a single-use refresh token.
  """

  alias Awrad.Accounts.{DeviceSession, User}

  @enforce_keys [:user, :session, :access_token, :access_token_expires_at, :refresh_token]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          user: User.t(),
          session: DeviceSession.t(),
          access_token: String.t(),
          access_token_expires_at: DateTime.t(),
          refresh_token: String.t()
        }

  @doc false
  @spec new(User.t(), DeviceSession.t(), String.t(), DateTime.t(), String.t()) :: t()
  def new(user, session, access_token, access_token_expires_at, refresh_token) do
    %__MODULE__{
      user: user,
      session: session,
      access_token: access_token,
      access_token_expires_at: access_token_expires_at,
      refresh_token: refresh_token
    }
  end
end
