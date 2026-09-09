defmodule AwradServerWeb.Api.PracticeSettingsControllerTest do
  use AwradServerWeb.ConnCase, async: false

  import AwradServer.AccountsFixtures

  alias AwradServer.Accounts.Token

  @installation_id "66a855c8-047d-4ee7-937f-3f565c8420ec"

  setup do
    user = user_fixture()

    {:ok, {_session, access_token, _refresh_token}} =
      Token.create_session(user, %{
        "installation_id" => @installation_id,
        "name" => "Test Pixel",
        "platform" => "android"
      })

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{access_token}")

    %{conn: conn, user: user}
  end

  test "returns the shared policy and the requested device context", %{conn: conn} do
    conn = get(conn, "/api/sync/v1/practice-settings?installation_id=#{@installation_id}")
    body = json_response(conn, 200)

    assert body["policy"] == %{
             "day_reset" => "midnight",
             "calculation_method" => "karachi",
             "madhab" => "shafi",
             "revision" => 1
           }

    assert body["device_context"] == nil
  end

  test "updates policy with an expected revision and rejects stale writes", %{conn: conn} do
    update = %{
      "installation_id" => @installation_id,
      "expected_revision" => 1,
      "policy" => %{
        "day_reset" => "maghrib",
        "calculation_method" => "umm_al_qura",
        "madhab" => "hanafi"
      }
    }

    updated = put(conn, "/api/sync/v1/practice-settings/policy", update)
    updated_body = json_response(updated, 200)

    assert updated_body["policy"] == %{
             "day_reset" => "maghrib",
             "calculation_method" => "umm_al_qura",
             "madhab" => "hanafi",
             "revision" => 2
           }

    stale = put(conn, "/api/sync/v1/practice-settings/policy", update)
    stale_body = json_response(stale, 409)

    assert stale_body["error"] == "practice_policy_conflict"
    assert stale_body["policy"]["revision"] == 2
    assert stale_body["policy"]["day_reset"] == "maghrib"
  end

  test "updates only the current installation device context", %{conn: conn} do
    request = %{
      "installation_id" => @installation_id,
      "device_context" => %{
        "timezone" => "Asia/Kolkata",
        "latitude" => 12.9716,
        "longitude" => 77.5946,
        "accuracy_m" => 8.5,
        "location_name" => "Bengaluru, Karnataka, India",
        "location_source" => "manual"
      }
    }

    updated = put(conn, "/api/sync/v1/practice-settings/device-context", request)
    body = json_response(updated, 200)

    assert body["device_context"]["installation_id"] == @installation_id
    assert body["device_context"]["timezone"] == "Asia/Kolkata"
    assert body["device_context"]["latitude"] == 12.9716
    assert body["device_context"]["location_name"] == "Bengaluru, Karnataka, India"
    assert body["device_context"]["location_source"] == "manual"

    fetched = get(conn, "/api/sync/v1/practice-settings?installation_id=#{@installation_id}")
    assert json_response(fetched, 200)["device_context"]["revision"] == 1
  end

  test "does not accept a different installation identity", %{conn: conn} do
    other_installation_id = "7e3d5c9a-4c2c-4b9e-ae2f-8a46d4cf0c11"

    conn = get(conn, "/api/sync/v1/practice-settings?installation_id=#{other_installation_id}")

    assert json_response(conn, 422) == %{"error" => "installation_mismatch"}
  end

  test "requires a verified bearer session" do
    conn = get(build_conn(), "/api/sync/v1/practice-settings?installation_id=#{@installation_id}")

    assert json_response(conn, 401) == %{"error" => "unauthorized"}
  end
end
