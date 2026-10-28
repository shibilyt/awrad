plugins {
    id("awrad.android.library")
    id("awrad.android.hilt")
}

android {
    namespace = "app.awrad.core.data"
}

dependencies {
    api(project(":core:domain"))
    implementation(project(":core:database"))
    implementation(project(":core:network"))
    implementation(libs.androidx.datastore.preferences)
    // Uri helpers for imported recordings.
    implementation(libs.androidx.core.ktx)
    // Dhikr audio: ExoPlayer streams the catalog's recordings (ExoAudioPlayer).
    implementation(libs.media3.exoplayer)
    testImplementation(libs.kotlinx.serialization.json)
    // Room runs on Robolectric in the unit tests (DAO, transaction, engine and profile tests).
    testImplementation(project(":core:testing"))
    testImplementation(libs.robolectric)
    testImplementation(libs.androidx.test.core)
}

tasks.withType<Test>().configureEach {
    // ProblemCodeMappingTest reads every documented error code from the spec.
    inputs.files(fileTree(rootDir.resolve("../contracts/api")) { include("openapi.bundled.json") })
        .withPropertyName("apiSpec")
        .withPathSensitivity(PathSensitivity.RELATIVE)
    // The Room store runs the shared sync fixtures too.
    inputs.files(fileTree(rootDir.resolve("../contracts/sync")))
        .withPropertyName("syncFixtures")
        .withPathSensitivity(PathSensitivity.RELATIVE)
    testLogging.exceptionFormat = org.gradle.api.tasks.testing.logging.TestExceptionFormat.FULL
}

// The shared dhikr catalog ships as a committed asset (ARCHITECTURE.md, "Dhikr catalog").
fun DhikrCatalogTask.configureCatalog(verify: Boolean) {
    contract.set(rootDir.resolve("../contracts/dhikr-catalog/v1/catalog.json"))
    asset.set(file("src/main/assets/dhikr-catalog.json"))
    verifyOnly.set(verify)
    regenerateCommand.set("./gradlew :core:data:generateDhikrCatalog")
}

tasks.register<DhikrCatalogTask>("generateDhikrCatalog") {
    description = "Regenerates the bundled dhikr catalog from contracts/dhikr-catalog."
    configureCatalog(verify = false)
}

val verifyDhikrCatalog = tasks.register<DhikrCatalogTask>("verifyDhikrCatalog") {
    description = "Fails when the bundled dhikr catalog differs from contracts/dhikr-catalog or has unknown keys."
    group = "verification"
    configureCatalog(verify = true)
    // The shape check's own tests (unknown keys, kinds, reference types; the real contract) run with it.
    dependsOn(gradle.includedBuild("build-logic").task(":convention:test"))
}

// Like the design tokens: check, the unit tests, lint and detekt all run it, so the validation command catches drift.
tasks.named("check") { dependsOn(verifyDhikrCatalog) }
tasks.withType<Test>().configureEach { dependsOn(verifyDhikrCatalog) }
tasks.matching { it.name.startsWith("lint") || it.name == "detekt" }.configureEach { dependsOn(verifyDhikrCatalog) }
