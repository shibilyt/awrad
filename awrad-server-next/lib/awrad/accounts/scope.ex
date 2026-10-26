defmodule Awrad.Accounts.Scope do
  @moduledoc """
  Defines the scope of the caller to be used throughout the app
  (`phx.gen.auth`). Ownership always comes from here, never from request
  parameters (`contracts/api/STYLE.md` §4).

  Deliberate change: `device_session` is set when the caller authenticated
  with a mobile access token, and `nil` for a browser session.
  """

  alias Awrad.Accounts.{DeviceSession, User}

  @type t :: %__MODULE__{user: User.t() | nil, device_session: DeviceSession.t() | nil}

  defstruct user: nil, device_session: nil

  @doc """
  Creates a scope for the given user.

  Returns nil if no user is given.
  """
  @spec for_user(User.t() | nil) :: t() | nil
  def for_user(%User{} = user) do
    %__MODULE__{user: user}
  end

  def for_user(nil), do: nil

  @doc "Creates a scope for a user signed in on a mobile device session."
  @spec for_device_session(User.t(), DeviceSession.t()) :: t()
  def for_device_session(%User{} = user, %DeviceSession{} = session) do
    %__MODULE__{user: user, device_session: session}
  end
end
