plugins {
    id("awrad.jvm.library")
    alias(libs.plugins.kotlin.serialization)
}

dependencies {
    api(libs.kotlinx.coroutines.core)
    api(libs.javax.inject)
    // DhikrCatalog.parse reads the bundled catalog.json; the change queue's documents are JSON objects
    // (contracts/sync/v1), so the sync types expose kotlinx.serialization's JsonObject.
    api(libs.kotlinx.serialization.json)
    // Maghrib for the day reset (contracts/practice-settings/v1, maghrib_time): adhan-kotlin, plain JVM.
    implementation(libs.adhan)
    testImplementation(project(":core:testing"))
}

// The shared Umm al-Qura table ships as committed Kotlin source (ARCHITECTURE.md, "Hijri calendar").
val ummAlQuraContract = rootDir.resolve("../contracts/hijri-calendar/v1/umm-al-qura.json")
val ummAlQuraSource = file("src/main/kotlin/app/awrad/core/domain/hijri/UmmAlQuraTable.kt")

fun UmmAlQuraTableTask.configureTable(verify: Boolean) {
    contract.set(ummAlQuraContract)
    source.set(ummAlQuraSource)
    packageName.set("app.awrad.core.domain.hijri")
    verifyOnly.set(verify)
    regenerateCommand.set("./gradlew :core:domain:generateUmmAlQuraTable")
}

tasks.register<UmmAlQuraTableTask>("generateUmmAlQuraTable") {
    description = "Regenerates the bundled Umm al-Qura table from contracts/hijri-calendar."
    configureTable(verify = false)
}

val verifyUmmAlQuraTable = tasks.register<UmmAlQuraTableTask>("verifyUmmAlQuraTable") {
    description = "Fails when the bundled Umm al-Qura table differs from contracts/hijri-calendar."
    group = "verification"
    configureTable(verify = true)
}

tasks.named("check") { dependsOn(verifyUmmAlQuraTable) }

tasks.test {
    // The tests run the shared fixtures against the bundled table, so it must be the contract's.
    dependsOn(verifyUmmAlQuraTable)
    // The shared fixtures are the spec these tests run, so editing a case re-runs them.
    inputs.files(fileTree(rootDir.resolve("../contracts/goal-model")))
        .withPropertyName("goalModelFixtures")
        .withPathSensitivity(PathSensitivity.RELATIVE)
    inputs.files(fileTree(rootDir.resolve("../contracts/hijri-calendar")))
        .withPropertyName("hijriCalendarFixtures")
        .withPathSensitivity(PathSensitivity.RELATIVE)
    inputs.files(fileTree(rootDir.resolve("../contracts/account-model")))
        .withPropertyName("accountModelFixtures")
        .withPathSensitivity(PathSensitivity.RELATIVE)
    inputs.files(fileTree(rootDir.resolve("../contracts/identity")))
        .withPropertyName("identityFixtures")
        .withPathSensitivity(PathSensitivity.RELATIVE)
    inputs.files(fileTree(rootDir.resolve("../contracts/sync")))
        .withPropertyName("syncFixtures")
        .withPathSensitivity(PathSensitivity.RELATIVE)
    inputs.files(fileTree(rootDir.resolve("../contracts/practice-settings")))
        .withPropertyName("practiceSettingsFixtures")
        .withPathSensitivity(PathSensitivity.RELATIVE)
    // The city search fixtures run over the contract's cities.json.
    inputs.files(fileTree(rootDir.resolve("../contracts/places")))
        .withPropertyName("places")
        .withPathSensitivity(PathSensitivity.RELATIVE)
    // The dhikr search fixtures run over the contract's catalog.json, which the catalog tests parse too.
    inputs.files(fileTree(rootDir.resolve("../contracts/dhikr-catalog")))
        .withPropertyName("dhikrCatalog")
        .withPathSensitivity(PathSensitivity.RELATIVE)
    // Print the whole assertion, which names every failing case id, in the build log.
    testLogging.exceptionFormat = org.gradle.api.tasks.testing.logging.TestExceptionFormat.FULL
}
