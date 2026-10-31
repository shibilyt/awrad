defmodule Awrad.SharedFixturesTest do
  @moduledoc """
  The server runs every shared rule file, and its copies of the Hijri table
  and the dhikr catalog are the contracts ones.
  """
  use ExUnit.Case, async: true

  alias Awrad.Fixtures

  # Each model's fixture files and the directory of their runners: one
  # `<rule>_test.exs` per `<rule>.json`, loading that file.
  @runners %{
    "account-model/v1" => "test/awrad/accounts",
    "audio/v1" => "test/awrad/audio",
    "goal-model/v1" => "test/awrad/goals/rules",
    "hijri-calendar/v1" => "test/awrad/hijri",
    "identity/v1" => "test/awrad/identity",
    "practice-settings/v1" => "test/awrad/sync",
    "sync/v1" => "test/awrad/sync"
  }

  # Client-only rules the server deliberately doesn't run, with the reason.
  @client_only %{
    "account-model/v1" => %{
      # The server accepts only the API's EmailCode form (six ASCII digits) and
      # answers `validation_failed` (`code_invalid`) for anything else. Clients
      # normalise what the user typed (spaces, hyphens, Arabic-Indic and
      # fullwidth digits) before sending, so there's nothing for the server to run.
      "email_code_input" => "the server accepts ASCII digits only; clients normalise"
    },
    # The phones merge a conflicting goal order (goal-model/v1 README, "The
    # goal order"); the server keeps the first write and conflicts the rest.
    "goal-model/v1" => %{
      "goal_order_merge" => "the phones merge a conflicting goal order; the server only conflicts"
    },
    # The server only stores and validates the practice policy (slice 3d); the
    # clients merge it, choose it at the first sign-in and compute Maghrib.
    "practice-settings/v1" => %{
      "practice_policy_merge" => "clients merge a conflicting policy; the server only conflicts",
      "practice_policy_first_sign_in" => "the phones' first sign-in; the server has no profiles",
      "maghrib_time" => "the server never computes Maghrib (API STYLE §6)"
    },
    # The phones' side of the change queue (contracts/sync/v1/README.md,
    # "Fixtures"): their outbox, how they apply receipts and pages, and their
    # local profiles. The server's side is sync_receipts and sync_changes_feed.
    "sync/v1" => %{
      "outbox_enqueue" => "the phones' outbox; the web and the server have none",
      "apply_changes" => "how a phone applies receipts and pages to its local state",
      "profile_switch" => "local profiles exist only on phones"
    }
  }

  for {model, dir} <- @runners do
    @model model
    @dir dir
    test "every #{model} rule file has a runner" do
      rules = Fixtures.rules(@model)
      assert rules != []

      for rule <- rules, not Map.has_key?(Map.get(@client_only, @model, %{}), rule) do
        runner = Path.join(@dir, rule <> "_test.exs")
        assert File.exists?(runner), "no runner for #{@model}/fixtures/#{rule}.json: #{runner}"

        assert File.read!(runner) =~ ~s|Fixtures.cases!("#{@model}", "#{rule}")|,
               "#{runner} doesn't load #{@model}/fixtures/#{rule}.json"
      end
    end
  end

  test "client-only rules still exist, so an exemption can't go stale" do
    for {model, rules} <- @client_only, {rule, _reason} <- rules do
      assert rule in Fixtures.rules(model),
             "#{model}/fixtures/#{rule}.json is gone; drop its exemption"
    end
  end

  # The release compiles the table from priv/ (Awrad.Hijri.Table) and never
  # reads contracts/, so this copy must stay identical to the contracts file.
  test "the server's Hijri table is the contracts one" do
    copy = Path.expand("priv/hijri-calendar/umm-al-qura.json")
    source = Fixtures.contracts_path("hijri-calendar/v1/umm-al-qura.json")

    assert File.read!(copy) == File.read!(source), """
    #{copy} differs from #{source}. Refresh the server's copy:

        cp ../contracts/hijri-calendar/v1/umm-al-qura.json priv/hijri-calendar/
    """
  end

  # Awrad.Dhikrs.Catalog compiles from this copy the same way (ADR 0004).
  test "the server's dhikr catalog is the contracts one" do
    copy = Path.expand("priv/dhikr-catalog/catalog.json")
    source = Fixtures.contracts_path("dhikr-catalog/v1/catalog.json")

    assert File.read!(copy) == File.read!(source), """
    #{copy} differs from #{source}. Refresh the server's copy:

        cp ../contracts/dhikr-catalog/v1/catalog.json priv/dhikr-catalog/
    """
  end
end
