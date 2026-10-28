package app.awrad.core.domain.sync

import app.awrad.core.testing.fixtures.FixtureModel
import app.awrad.core.testing.fixtures.FixtureRunner
import kotlinx.serialization.json.JsonObject

/** Runs every case of the sync [rule] (contracts/sync/v1/fixtures) and prints the count; fails on any failure. */
internal fun runSyncFixture(rule: String, evaluate: (given: JsonObject) -> JsonObject): Int =
    FixtureRunner.run(FixtureRunner.cases(FixtureModel.SYNC, rule), evaluate)
        .also { println("sync/$rule: $it of $it cases passed") }
