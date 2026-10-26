defmodule Awrad.Accounts.Scope do
  @moduledoc """
  Defines the scope of the caller to be used throughout the app
  (`phx.gen.auth`). Ownership always comes from here, never from request
  parameters (`contracts/api/STYLE.md` §4).

  Deliberate change: the scope names the caller's own session, so the session
  list can mark it and "sign out of all other devices" can keep it.
  `device_session` is set when the caller authenticated with a mobile access
  token; `browser_session_id` (the `users_tokens` row) when it authenticated
  with the browser cookie. At most one of them is set.
  """

  alias Awrad.Accounts.{DeviceSession, User}

  @type t :: %__MODULE__{
          user: User.t() | nil,
          device_session: DeviceSession.t() | nil,
          browser_session_id: Ecto.UUID.t() | nil
        }

  defstruct user: nil, device_session: nil, browser_session_id: nil

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

  @doc "Creates a scope for a user signed in on the browser session `session_id`."
  @spec for_browser_session(User.t(), Ecto.UUID.t()) :: t()
  def for_browser_session(%User{} = user, session_id) when is_binary(session_id) do
    %__MODULE__{user: user, browser_session_id: session_id}
  end

  @doc "The ID of the caller's own session, of either kind, or `nil`."
  @spec current_session_id(t()) :: Ecto.UUID.t() | nil
  def current_session_id(%__MODULE__{device_session: %DeviceSession{id: id}}), do: id
  def current_session_id(%__MODULE__{browser_session_id: id}), do: id
end
