defmodule AwradServerWeb.PracticeLiveTest do
  use AwradServerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias AwradServer.Dhikr.Dhikr
  alias AwradServer.Accounts.Scope
  alias AwradServer.PracticeSettings.DeviceContext
  alias AwradServer.PracticeSettings
  alias AwradServer.ProgressSync.EntityRecord
  alias AwradServer.Tracking
  alias AwradServer.AccountsFixtures
  alias AwradServer.Repo

  setup :register_and_log_in_user

  test "requires a browser session for the home page" do
    conn = get(build_conn(), ~p"/home")

    assert redirected_to(conn) == ~p"/users/log-in"
  end

  test "renders the authenticated home and navigation", %{conn: conn, user: user} do
    {:ok, _view, html} = live(conn, ~p"/home")

    assert html =~ "Today"
    assert html =~ user.email
    assert html =~ ~p"/goals"
    assert html =~ ~p"/library"
  end

  test "mirrors the mobile home with today's goals, featured wirds, and categories", %{conn: conn} do
    %Dhikr{}
    |> Dhikr.changeset(%{arabic: "ذِكْر الصباح", catalog_key: "home-morning", category: "morning"})
    |> Repo.insert!()

    {:ok, view, html} = live(conn, ~p"/home")

    assert has_element?(view, "#due-goals-heading", "Today's goals")
    assert html =~ "Today"
    assert html =~ "Featured Wirds"
    assert html =~ "Categories"
    assert has_element?(view, "#home-todays-goals")
    assert has_element?(view, "#home-wirds")
    assert has_element?(view, "#home-categories")
    assert has_element?(view, "[data-wird-slug=\"dalail-al-khayrat\"]")
    assert has_element?(view, "[data-category-key=\"morning\"]")
  end

  test "keeps the sidebar while placing home content in a compact mobile hierarchy", %{conn: conn} do
    {:ok, view, html} = live(conn, ~p"/home")

    assert has_element?(view, "#awrad-app-shell .awrad-sidebar")
    assert has_element?(view, "#main-content .awrad-home-content")
    assert has_element?(view, "#main-content .awrad-home-content .awrad-home-quick-stats")
    assert has_element?(view, "#main-content .awrad-home-content .awrad-home-goal-stack")
    refute has_element?(view, "#main-content .awrad-home-content .awrad-home-summary")
    assert has_element?(view, "#main-content .awrad-home-content #due-goals-heading")

    {goals_index, _} = :binary.match(html, "home-todays-goals")
    {categories_index, _} = :binary.match(html, "home-categories")
    {wirds_index, _} = :binary.match(html, "home-wirds")

    assert goals_index < categories_index
    assert categories_index < wirds_index
  end

  test "renders due goals as compact mobile-style count rows", %{conn: conn, user: user} do
    dhikr =
      %Dhikr{}
      |> Dhikr.changeset(%{arabic: "ذِكْر", catalog_key: "compact-home-goal"})
      |> Repo.insert!()

    {:ok, goal} =
      Tracking.create_goal(Scope.for_user(user), %{
        id: Ecto.UUID.generate(),
        dhikr_id: dhikr.id,
        start_date: ~D[2026-07-01],
        target_count: 10
      })

    {:ok, _slot} = Tracking.create_slot(Scope.for_user(user), goal.id, %{target_count: 10})

    Repo.insert!(%EntityRecord{
      user_id: user.id,
      entity_type: "goal",
      entity_id: goal.id,
      incarnation: 1,
      version: 1,
      sync_revision: 1,
      document: %{},
      state: "active"
    })

    {:ok, view, _html} = live(conn, ~p"/home")

    assert has_element?(view, ".awrad-home-goal-stack")
    assert has_element?(view, ".awrad-home-goal-row", "compact-home-goal")
    assert has_element?(view, ".awrad-home-goal-ring[role=progressbar]")
  end

  test "renders an empty state for a user without goals", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/goals")

    assert html =~ "No goals yet"
    assert html =~ ~p"/library"
  end

  test "renders the read-only library", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/library")

    assert html =~ "Dhikr library"
    assert html =~ "Search"
  end

  test "renders a dhikr detail page", %{conn: conn} do
    dhikr =
      %Dhikr{}
      |> Dhikr.changeset(%{arabic: "سُبْحَانَ اللَّهِ", catalog_key: "subhanallah"})
      |> Repo.insert!()

    {:ok, _view, html} = live(conn, ~p"/library/#{dhikr.id}")

    assert html =~ "سُبْحَانَ اللَّهِ"
    assert html =~ "Back to library"
  end

  test "counts through the canonical browser sync path", %{conn: conn, user: user} do
    dhikr =
      %Dhikr{}
      |> Dhikr.changeset(%{arabic: "ذِكْر"})
      |> Repo.insert!()

    {:ok, goal} =
      Tracking.create_goal(Scope.for_user(user), %{
        dhikr_id: dhikr.id,
        start_date: ~D[2026-07-01],
        target_count: 3
      })

    {:ok, slot} = Tracking.create_slot(Scope.for_user(user), goal.id, %{target_count: 3})

    Repo.insert!(%EntityRecord{
      user_id: user.id,
      entity_type: "goal",
      entity_id: goal.id,
      incarnation: 1,
      version: 1,
      sync_revision: 1,
      document: %{},
      state: "active"
    })

    {:ok, view, html} = live(conn, ~p"/count/#{goal.id}")
    assert html =~ "Ready to count"

    render_hook(view, "browser_context", %{
      "date" => "2026-07-16",
      "timezone" => "Asia/Kolkata"
    })

    render_click(element(view, "#count-increment"))
    html = render(view)

    assert html =~ "Saved to your account"
    assert html =~ "1/3"
    assert slot.id
  end

  test "persists browser location as device context without sharing it across accounts", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/home")

    render_hook(view, "browser_context", %{
      "date" => "2026-07-16",
      "timezone" => "Asia/Kolkata",
      "latitude" => 10.1234,
      "longitude" => 76.5678,
      "accuracy_m" => 18.5,
      "location_source" => "browser"
    })

    html = render(view)

    assert has_element?(view, "#browser-location")
    assert html =~ "10.1234"
    assert html =~ "Asia/Kolkata"
  end

  test "renders mobile-style prayer times for the selected browser location", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/home")

    render_hook(view, "browser_context", %{
      "date" => "2026-09-09",
      "timezone" => "Asia/Kolkata",
      "latitude" => 11.4408,
      "longitude" => 75.6954,
      "location_name" => "Koyilandy, Kerala, India",
      "prayer_times" => [
        %{
          "name" => "Fajr",
          "time" => "5:03 AM",
          "at" => "2026-09-09T23:33:00.000Z",
          "is_complete" => true,
          "is_next" => false
        },
        %{
          "name" => "Dhuhr",
          "time" => "12:22 PM",
          "at" => "2026-09-09T06:52:00.000Z",
          "is_complete" => true,
          "is_next" => false
        },
        %{
          "name" => "Asr",
          "time" => "3:45 PM",
          "at" => "2026-09-09T10:15:00.000Z",
          "is_complete" => false,
          "is_next" => true
        },
        %{
          "name" => "Maghrib",
          "time" => "6:32 PM",
          "at" => "2026-09-09T13:02:00.000Z",
          "is_complete" => false,
          "is_next" => false
        },
        %{
          "name" => "Isha",
          "time" => "7:48 PM",
          "at" => "2026-09-09T14:18:00.000Z",
          "is_complete" => false,
          "is_next" => false
        }
      ],
      "next_prayer" => %{
        "name" => "Asr",
        "time" => "3:45 PM",
        "at" => "2026-09-09T10:15:00.000Z",
        "countdown" => "in 2h 15m"
      }
    })

    assert has_element?(view, "#home-prayer-times", "Prayer times")
    assert has_element?(view, "#home-prayer-times", "Koyilandy, Kerala, India")
    assert has_element?(view, "#home-prayer-times [data-prayer-name=\"Asr\"]", "Asr")
    assert has_element?(view, "#home-prayer-times [data-prayer-time=\"Asr\"]", "3:45 PM")
    assert has_element?(view, "#home-prayer-times .is-next", "Next prayer")
    assert render(view) =~ "in 2h 15m"
  end

  test "uses the browser Maghrib boundary for the account's practice date", %{
    conn: conn,
    user: user
  } do
    scope = Scope.for_user(user)
    assert {:ok, _policy} = PracticeSettings.update_policy(scope, %{day_reset: "maghrib"})

    civil_date = Date.utc_today()
    maghrib_at = DateTime.add(DateTime.utc_now(:second), -60, :second)
    {:ok, view, _html} = live(conn, ~p"/home")

    render_hook(view, "browser_context", %{
      "date" => Date.to_iso8601(civil_date),
      "timezone" => "UTC",
      "latitude" => 12.9716,
      "longitude" => 77.5946,
      "maghrib_at" => DateTime.to_iso8601(maghrib_at)
    })

    assert render(view) =~ Calendar.strftime(Date.add(civil_date, 1), "%A, %B %-d, %Y")
  end

  test "allows manual coordinates when browser location is unavailable", %{conn: conn, user: user} do
    {:ok, view, _html} = live(conn, ~p"/home")

    render_hook(view, "browser_context", %{
      "date" => "2026-07-16",
      "timezone" => "Asia/Kolkata"
    })

    render_submit(element(view, "#manual-browser-location"), %{
      "latitude" => "10.1234",
      "longitude" => "76.5678"
    })

    assert render(view) =~ "10.1234"

    assert %DeviceContext{
             latitude: 10.1234,
             longitude: 76.5678,
             location_source: "manual"
           } = Repo.get_by!(DeviceContext, user_id: user.id)
  end

  test "shows the verification gate for an unconfirmed account", %{conn: conn} do
    user = AccountsFixtures.unconfirmed_user_fixture()
    conn = AwradServerWeb.ConnCase.log_in_user(conn, user)

    assert {:error, {:redirect, %{to: "/users/verification-required"}}} =
             live(conn, ~p"/home")
  end

  test "renders a browser-friendly verification resend state", %{conn: conn} do
    user = AccountsFixtures.unconfirmed_user_fixture()
    conn = AwradServerWeb.ConnCase.log_in_user(conn, user)

    {:ok, _view, html} = live(conn, ~p"/users/verification-required")

    assert html =~ "Verify your email"
    assert html =~ user.email
    assert html =~ "Send a new verification email"
  end
end
