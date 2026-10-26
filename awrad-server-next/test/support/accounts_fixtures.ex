defmodule Awrad.AccountsFixtures do
  @moduledoc """
  Accounts test helpers: accounts, devices, grants, emailed codes and JSON
  requests.
  """

  # Test support sits outside the production boundaries (Awrad, AwradWeb).
  use Boundary, top_level?: true, check: [in: false, out: false]

  import ExUnit.Assertions

  alias Awrad.Accounts.{DeviceSessions, User}
  alias Awrad.Repo

  @password "a long passphrase for tests"

  def unique_email, do: "user#{System.unique_integer([:positive])}@example.com"
  def valid_password, do: @password

  @doc "A verified account with `valid_password/0`, inserted directly."
  def user_fixture(attrs \\ %{}) do
    Repo.insert!(%User{
      email: attrs[:email] || unique_email(),
      hashed_password: User.hash(attrs[:password] || @password),
      confirmed_at: Map.get(attrs, :confirmed_at, DateTime.utc_now(:second))
    })
  end

  def unconfirmed_user_fixture(attrs \\ %{}), do: user_fixture(Map.put(attrs, :confirmed_at, nil))

  def device(attrs \\ %{}) do
    Map.merge(
      %{installation_id: Ecto.UUID.generate(), name: "Pixel 9", platform: :android},
      attrs
    )
  end

  def device_params(attrs \\ %{}) do
    Map.merge(
      %{"installation_id" => Ecto.UUID.generate(), "name" => "Pixel 9", "platform" => "android"},
      attrs
    )
  end

  @doc "A signed-in device session of `user`."
  def grant_fixture(user \\ user_fixture(), device \\ device()),
    do: DeviceSessions.create(user, device)

  @doc "Waits for the code email sent to `to` (emails go out from a task) and returns it."
  def assert_code_email(to) do
    assert_receive {:email, %Swoosh.Email{to: [{_, ^to}]} = email}, 1_000
    email
  end

  @doc "Waits for the code email sent to `to` and returns the 6-digit code."
  def code_from_email(to) do
    %Swoosh.Email{text_body: body} = assert_code_email(to)
    [code] = Regex.run(~r/\b(\d{6})\b/, body, capture: :all_but_first)
    code
  end

  @doc "Asserts no email arrives within a short wait."
  def refute_email do
    refute_receive {:email, _}, 200
  end

  @doc """
  A browser's next request after `conn`: cookies carried over
  (`Phoenix.ConnTest.recycle/1`) and CSRF protection enforced, which
  `Phoenix.ConnTest` otherwise skips.
  """
  def next_request(conn) do
    conn
    |> Phoenix.ConnTest.recycle()
    |> Plug.Conn.put_private(:plug_skip_csrf_protection, false)
  end

  @doc "A JSON request body with the content type set, and optional extra headers."
  def json_conn(conn, headers \\ []) do
    Enum.reduce(
      [{"content-type", "application/json"} | headers],
      conn,
      fn {name, value}, conn -> Plug.Conn.put_req_header(conn, name, value) end
    )
  end
end
