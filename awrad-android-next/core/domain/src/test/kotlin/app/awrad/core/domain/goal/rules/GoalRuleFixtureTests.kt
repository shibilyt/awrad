package app.awrad.core.domain.goal.rules

import app.awrad.core.domain.AwradId
import app.awrad.core.domain.goal.GoalOrder
import app.awrad.core.domain.goal.withEdit
import app.awrad.core.testing.fixtures.FixtureRunner
import app.awrad.core.testing.fixtures.countLog
import app.awrad.core.testing.fixtures.counts
import app.awrad.core.testing.fixtures.date
import app.awrad.core.testing.fixtures.goalCounts
import app.awrad.core.testing.fixtures.goalDocument
import app.awrad.core.testing.fixtures.goalInput
import app.awrad.core.testing.fixtures.goalOrder
import app.awrad.core.testing.fixtures.hijriCorrections
import app.awrad.core.testing.fixtures.settings
import app.awrad.core.testing.fixtures.string
import app.awrad.core.testing.fixtures.toFixtureName
import app.awrad.core.testing.fixtures.toJson
import app.awrad.core.testing.fixtures.versions
import app.awrad.core.testing.fixtures.weekStart
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.add
import kotlinx.serialization.json.addJsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonArray
import kotlin.test.Test

/** Slice 4a's goal-model rules, one runner per fixture file. */
class GoalVersionOnDayFixtureTest {

    @Test
    fun `every goal_version_on_day fixture case passes`() {
        FixtureRunner.runGoalModel("goal_version_on_day") { given ->
            val timeline = given.goalDocument().timeline
            val date = given.date("date")
            buildJsonObject {
                put("version", timeline.versionIndexOn(date))
                put("goal", timeline.goalOn(date).toJson())
            }
        }
    }
}

class GoalVersionAddFixtureTest {

    @Test
    fun `every goal_version_add fixture case passes`() {
        FixtureRunner.runGoalModel("goal_version_add") { given ->
            val versions = given.versions().withEdit(given.settings(), given.date("today"))
            buildJsonObject { put("versions", JsonArray(versions.map { it.toJson() })) }
        }
    }
}

class CountAttributionFixtureTest {

    @Test
    fun `every count_attribution fixture case passes`() {
        FixtureRunner.runGoalModel("count_attribution") { given ->
            val log = given.countLog()
            buildJsonObject {
                putJsonArray("goals") {
                    given.getValue("goals").jsonArray.map { it.jsonObject }.forEach { goal ->
                        val id = AwradId(goal.string("id"))
                        val counts = attributedCounts(
                            goalId = id,
                            dhikrId = AwradId(goal.string("dhikr_id")),
                            counts = goal.goalCounts(),
                            timeline = goal.goalInput(),
                            log = log,
                        )
                        addJsonObject {
                            put("id", id.value)
                            put("counts", JsonArray(counts.map { it.toJson() }))
                        }
                    }
                }
            }
        }
    }
}

class MakeUpFixtureTest {

    @Test
    fun `every make_up fixture case passes`() {
        FixtureRunner.runGoalModel("make_up") { given ->
            val from = given.date("from")
            val days = given.goalInput().dueDaysOn(given.date("date"), given.counts(), given.hijriCorrections())
            buildJsonObject {
                putJsonArray("days") {
                    days.filterNot { it.date.isBefore(from) }.forEach { day ->
                        addJsonObject {
                            put("date", day.date.toString())
                            put("count", day.count)
                            put("filled", day.filled)
                            put("status", day.status.toFixtureName())
                        }
                    }
                }
            }
        }
    }
}

class ExcusedDaysFixtureTest {

    @Test
    fun `every excused_days fixture case passes`() {
        FixtureRunner.runGoalModel("excused_days") { given ->
            val timeline = given.goalInput()
            val day = given.date("day")
            val today = given.date("date")
            val refusal = when (val action = given.string("action")) {
                "excuse" -> timeline.excuseRefusal(day, today, given.counts(), given.hijriCorrections())
                "unexcuse" -> timeline.unexcuseRefusal(day, today)
                else -> error("Unknown action: $action")
            }
            buildJsonObject {
                put("allowed", refusal == null)
                put("reason", refusal?.toFixtureName())
            }
        }
    }
}

class ConsistencyFixtureTest {

    @Test
    fun `every consistency fixture case passes`() {
        FixtureRunner.runGoalModel("consistency") { given ->
            val consistency = given.goalInput()
                .consistencyOn(given.date("date"), given.counts(), given.weekStart(), given.hijriCorrections())
            buildJsonObject {
                put("basis", consistency.basis.toFixtureName())
                put("met", consistency.met)
                put("out_of", consistency.outOf)
                put("tag", consistency.tag?.toFixtureName())
                put("show", consistency.show.toFixtureName())
            }
        }
    }
}

class DailyPaceFixtureTest {

    @Test
    fun `every daily_pace fixture case passes`() {
        FixtureRunner.runGoalModel("daily_pace") { given ->
            val pace = given.goalInput().dailyPaceOn(given.date("date"), given.counts(), given.hijriCorrections())
            buildJsonObject {
                put("pace", pace.pace)
                put("remaining", pace.remaining)
                put("due_days_left", pace.dueDaysLeft)
            }
        }
    }
}

class TodayRingFixtureTest {

    @Test
    fun `every today_ring fixture case passes`() {
        FixtureRunner.runGoalModel("today_ring") { given ->
            val ring = given.goalInput()
                .todayRing(given.date("date"), given.counts(), given.weekStart(), given.hijriCorrections())
            buildJsonObject {
                put("ring", ring.kind.toFixtureName())
                put("progress", ring.progress)
                put("goal", ring.goal)
            }
        }
    }
}

class GoalListPlacementFixtureTest {

    @Test
    fun `every goal_list_placement fixture case passes`() {
        FixtureRunner.runGoalModel("goal_list_placement") { given ->
            val goals = given.getValue("goals").jsonArray.map { it.jsonObject }.map { goal ->
                PlacementGoal(AwradId(goal.string("id")), goal.goalInput(), goal.counts())
            }
            val order = GoalOrder(given.getValue("order").jsonArray.map { AwradId(it.jsonPrimitive.content) })
            placeGoals(goals, order, given.date("date"), given.hijriCorrections()).toJson()
        }
    }

    private fun GoalLists.toJson(): JsonObject = buildJsonObject {
        putJsonArray("today") { today.forEach { add(it.value) } }
        putJsonArray("upcoming") {
            upcoming.forEach { goal ->
                addJsonObject {
                    put("id", goal.id.value)
                    put("next_due", goal.nextDue?.toString())
                }
            }
        }
        putJsonArray("tracking") { tracking.forEach { add(it.value) } }
        putJsonArray("paused") { paused.forEach { add(it.value) } }
        putJsonArray("history") {
            history.forEach { goal ->
                addJsonObject {
                    put("id", goal.id.value)
                    put("finished", goal.finish.toFixtureName())
                    put("on", goal.on.toString())
                }
            }
        }
    }
}

class GoalOrderMergeFixtureTest {

    @Test
    fun `every goal_order_merge fixture case passes`() {
        FixtureRunner.runGoalModel("goal_order_merge") { given ->
            val merged = GoalOrderMerge.merge(
                base = given.goalOrder("base"),
                mine = given.goalOrder("mine"),
                theirs = given.goalOrder("theirs"),
            )
            buildJsonObject {
                put("document", merged.order.toJson())
                put("requeue", merged.requeue)
            }
        }
    }
}
