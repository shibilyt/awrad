defmodule Awrad.Sync.GoalSyncTest do
  @moduledoc """
  The goal rules of the change queue the shared fixtures leave out
  (contracts/sync/v1/README.md): the 300 and 2,000 goal limits, schema errors
  in goal documents, and every goal rule's field error ("Goal rules as field
  errors"). The fixtures (`sync_receipts_test.exs`) cover the rest.
  """
  use Awrad.DataCase, async: true

  import Awrad.AccountsFixtures

  alias Awrad.Sync
  alias Awrad.Sync.Entity

  @isthighfar "3285e014-551b-46a4-aedc-8b6664b59bc7"

  @version %{
    "from" => "2026-10-14",
    "schedule" => %{"kind" => "every_day"},
    "active_period" => %{"start_date" => "2026-10-01", "end_date" => nil, "duration_days" => nil},
    "count_policy" => %{
      "minimum" => nil,
      "target" => 100,
      "maximum" => nil,
      "streak_threshold" => "target"
    },
    "sessions" => [],
    "requirement" => %{"type" => "per_due_date"},
    "completion" => "never",
    "make_up" => %{"window" => "off", "fill" => "streak"}
  }

  @goal %{
    "dhikr_id" => @isthighfar,
    "dhikr_snapshot" => %{
      "title" => %{"en" => "Isthighfar", "ar" => nil, "ml" => nil},
      "arabic" => "أَسْتَغْفِرُ ٱللَّٰهَ",
      "kind" => "dhikr"
    },
    "name" => nil,
    "counts" => "shared",
    "created_on" => "2026-10-14",
    "versions" => [@version],
    "paused" => [],
    "excused" => [],
    "ended" => nil
  }

  @ended %{@goal | "ended" => %{"on" => "2026-10-20", "reason" => "user"}}

  defp put(document, id \\ Awrad.UUIDv7.generate(), base_version \\ 0) do
    %{
      "command_id" => Awrad.UUIDv7.generate(),
      "entity_type" => "goal",
      "entity_id" => id,
      "op" => "put",
      "base_version" => base_version,
      "document" => document
    }
  end

  defp insert_goals(user_id, count, document) do
    now = DateTime.utc_now(:second)

    rows =
      for n <- 1..count//1 do
        %{
          id: Awrad.UUIDv7.generate(),
          user_id: user_id,
          entity_type: "goal",
          entity_id: Awrad.UUIDv7.generate(),
          version: 1,
          revision: n,
          state: if(document, do: "active", else: "deleted"),
          document: document,
          inserted_at: now,
          updated_at: now
        }
      end

    Repo.insert_all(Entity, rows)
  end

  defp fields(document) do
    %{receipts: [receipt]} = Sync.apply_batch(user_fixture().id, [put(document)])
    assert %{"status" => "rejected", "code" => "document_invalid"} = receipt
    Enum.map(receipt["fields"], &{&1["field"], &1["code"]})
  end

  defp with_version(changes), do: %{@goal | "versions" => [Map.merge(@version, changes)]}

  describe "goal limits" do
    test "at most 300 goals that haven't ended; ended and deleted ones don't count" do
      %{id: user_id} = user_fixture()
      insert_goals(user_id, 299, @goal)
      insert_goals(user_id, 10, @ended)
      insert_goals(user_id, 10, nil)

      %{receipts: [applied, rejected, ended]} =
        Sync.apply_batch(user_id, [put(@goal), put(@goal), put(@ended)])

      assert %{"status" => "applied"} = applied

      assert %{"status" => "rejected", "code" => "goal_limit_reached", "current" => nil} =
               rejected

      assert %{"status" => "applied"} = ended
    end

    test "ending a goal is never refused, and an edit of a running goal fits" do
      %{id: user_id} = user_fixture()
      insert_goals(user_id, 299, @goal)
      id = Awrad.UUIDv7.generate()
      %{receipts: [%{"status" => "applied"}]} = Sync.apply_batch(user_id, [put(@goal, id)])

      edited = put_in(@goal, ["name"], "Morning")

      %{receipts: [edit, finish]} =
        Sync.apply_batch(user_id, [put(edited, id, 1), put(@ended, id, 2)])

      assert %{"status" => "applied", "version" => 2} = edit
      assert %{"status" => "applied", "version" => 3} = finish
    end

    test "at most 2,000 goals in all, ended ones included" do
      %{id: user_id} = user_fixture()
      insert_goals(user_id, 1_999, @ended)

      %{receipts: [applied, rejected]} = Sync.apply_batch(user_id, [put(@ended), put(@ended)])

      assert %{"status" => "applied"} = applied
      assert %{"status" => "rejected", "code" => "goal_limit_reached"} = rejected
    end
  end

  describe "schema errors" do
    test "missing, unknown and mistyped members" do
      document =
        @goal
        |> Map.delete("counts")
        |> Map.put("colour", "green")
        |> Map.put("created_on", "2026-02-30")
        |> put_in(["dhikr_snapshot", "kind"], "story")

      assert fields(document) == [
               {"/document/colour", "not_allowed"},
               {"/document/counts", "required"},
               {"/document/created_on", "invalid"},
               {"/document/dhikr_snapshot/kind", "invalid"}
             ]
    end

    test "inside a version: kinds, ranges and days that don't exist" do
      document =
        with_version(%{
          "schedule" => %{
            "kind" => "yearly",
            "calendar" => "gregorian",
            "ranges" => [
              %{"start" => %{"month" => 4, "day" => 31}, "end" => %{"month" => 5, "day" => 2}}
            ]
          },
          "sessions" => [
            %{"id" => "at_0630", "kind" => "at_time", "time" => "6:30", "target" => 33}
          ],
          "requirement" => %{"type" => "period_total"},
          "count_policy" => %{@version["count_policy"] | "streak_threshold" => %{"amount" => 0}}
        })

      assert fields(document) == [
               {"/document/versions/0/count_policy/streak_threshold/amount", "invalid"},
               {"/document/versions/0/requirement/period", "required"},
               {"/document/versions/0/schedule/ranges/0/start", "invalid"},
               {"/document/versions/0/sessions/0/time", "invalid"}
             ]
    end

    test "a snapshot without any title, no versions, a repeated excused day" do
      document =
        @goal
        |> put_in(["dhikr_snapshot", "title", "en"], nil)
        |> Map.put("versions", [])
        |> Map.put("excused", ["2026-10-15", "2026-10-15"])

      assert fields(document) == [
               {"/document/dhikr_snapshot/title", "required"},
               {"/document/excused", "duplicate"},
               {"/document/versions", "required"}
             ]
    end
  end

  describe "goal rules as field errors" do
    test "sessions with a minimum and a cap, a repeated session, an empty window" do
      session = %{
        "id" => "after_fajr",
        "kind" => "after_prayer",
        "prayer" => "fajr",
        "target" => 33
      }

      between = %{
        "id" => "between_2100_2100",
        "kind" => "between",
        "from" => "21:00",
        "to" => "21:00",
        "target" => 10
      }

      document =
        with_version(%{
          "count_policy" => %{
            "minimum" => 10,
            "target" => nil,
            "maximum" => 200,
            "streak_threshold" => "target"
          },
          "sessions" => [session, session, between]
        })

      assert fields(document) == [
               {"/document/versions/0/count_policy/maximum", "not_allowed"},
               {"/document/versions/0/count_policy/minimum", "not_allowed"},
               {"/document/versions/0/sessions/1/id", "duplicate"},
               {"/document/versions/0/sessions/2/to", "range"}
             ]
    end

    test "targets, thresholds, ends and make-up" do
      document =
        with_version(%{
          "active_period" => %{
            "start_date" => "2026-10-01",
            "end_date" => "2026-12-31",
            "duration_days" => 30
          },
          "count_policy" => %{
            "minimum" => nil,
            "target" => nil,
            "maximum" => nil,
            "streak_threshold" => "daily_pace"
          },
          "requirement" => %{"type" => "period_total", "period" => "week"},
          "make_up" => %{"window" => "next_day", "fill" => "streak"},
          "sessions" => []
        })

      assert fields(document) == [
               {"/document/versions/0/active_period/duration_days", "not_allowed"},
               {"/document/versions/0/count_policy/streak_threshold", "invalid"},
               {"/document/versions/0/count_policy/target", "required"},
               {"/document/versions/0/make_up/window", "not_allowed"}
             ]
    end

    test "versions out of order, not from created_on, a session ID not derived" do
      second = %{
        @version
        | "from" => "2026-10-12",
          "sessions" => [%{"id" => "fajr", "kind" => "anytime", "target" => 5}]
      }

      document = %{@goal | "created_on" => "2026-10-13", "versions" => [@version, second]}

      assert fields(document) == [
               {"/document/versions/0/from", "mismatch"},
               {"/document/versions/1/from", "range"},
               {"/document/versions/1/sessions/0/id", "mismatch"}
             ]
    end
  end

  test "a goal order drops goals that aren't the account's, and can't be repeated" do
    %{id: user_id} = user_fixture()
    goal_id = Awrad.UUIDv7.generate()
    other = Awrad.UUIDv7.generate()

    order = fn ids, base ->
      %{
        "command_id" => Awrad.UUIDv7.generate(),
        "entity_type" => "goal_order",
        "entity_id" => user_id,
        "op" => "put",
        "base_version" => base,
        "document" => %{"goal_ids" => ids}
      }
    end

    %{receipts: [_goal, applied, repeated]} =
      Sync.apply_batch(user_id, [
        put(@goal, goal_id),
        order.([other, goal_id], 0),
        order.([goal_id, goal_id], 1)
      ])

    assert %{"status" => "applied", "version" => 1} = applied

    assert %{
             "code" => "document_invalid",
             "fields" => [%{"field" => "/document/goal_ids", "code" => "duplicate"}]
           } =
             repeated

    assert %Entity{document: %{"goal_ids" => [^goal_id]}} =
             Repo.get_by!(Entity, user_id: user_id, entity_type: "goal_order")
  end
end
