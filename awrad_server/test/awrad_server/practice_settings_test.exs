defmodule AwradServer.PracticeSettingsTest do
  use AwradServer.DataCase, async: true

  alias AwradServer.PracticeSettings

  import AwradServer.AccountsFixtures

  test "creates one default account policy for a user" do
    scope = user_scope_fixture()

    assert %{policy: policy, device_context: nil} =
             PracticeSettings.snapshot(scope, Ecto.UUID.generate())

    assert policy == %{
             day_reset: "midnight",
             calculation_method: "karachi",
             madhab: "shafi",
             revision: 1
           }
  end

  test "updates the shared policy and advances its revision" do
    scope = user_scope_fixture()

    assert {:ok, policy} =
             PracticeSettings.update_policy(scope, %{
               "day_reset" => "maghrib",
               "calculation_method" => "umm_al_qura",
               "madhab" => "hanafi"
             })

    assert policy.day_reset == "maghrib"
    assert policy.calculation_method == "umm_al_qura"
    assert policy.madhab == "hanafi"
    assert policy.revision == 2
  end

  test "stores browser location per account and installation" do
    first_scope = user_scope_fixture()
    second_scope = user_scope_fixture()
    installation_id = Ecto.UUID.generate()

    attrs = %{
      "latitude" => 10.1234,
      "longitude" => 76.5678,
      "timezone" => "Asia/Kolkata",
      "location_source" => "browser",
      "accuracy_m" => 18.5,
      "location_name" => "Kochi, Kerala, India"
    }

    assert {:ok, context} =
             PracticeSettings.upsert_device_context(first_scope, installation_id, attrs)

    assert context.latitude == 10.1234
    assert context.longitude == 76.5678
    assert context.timezone == "Asia/Kolkata"
    assert context.location_name == "Kochi, Kerala, India"
    assert context.revision == 1

    assert %{
             device_context: %{
               latitude: 10.1234,
               location_name: "Kochi, Kerala, India",
               revision: 1
             }
           } =
             PracticeSettings.snapshot(first_scope, installation_id)

    assert %{device_context: nil} = PracticeSettings.snapshot(second_scope, installation_id)

    assert {:ok, unchanged} =
             PracticeSettings.upsert_device_context(first_scope, installation_id, attrs)

    assert unchanged.revision == 1

    assert {:ok, updated} =
             PracticeSettings.upsert_device_context(
               first_scope,
               installation_id,
               Map.put(attrs, "latitude", 11.0)
             )

    assert updated.latitude == 11.0
    assert updated.revision == 2
  end

  test "rejects an invalid browser location" do
    scope = user_scope_fixture()

    assert {:error, changeset} =
             PracticeSettings.upsert_device_context(scope, Ecto.UUID.generate(), %{
               "latitude" => 91.0,
               "longitude" => 181.0,
               "timezone" => "Asia/Kolkata"
             })

    errors = errors_on(changeset)
    assert errors.latitude != []
    assert errors.longitude != []
  end
end
