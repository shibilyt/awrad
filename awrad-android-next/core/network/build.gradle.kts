plugins {
    id("awrad.android.library")
    id("awrad.android.hilt")
    alias(libs.plugins.kotlin.serialization)
}

android {
    namespace = "app.awrad.core.network"
}

dependencies {
    api(libs.kotlinx.coroutines.core)
    implementation(libs.kotlinx.serialization.json)
    implementation(libs.okhttp)
}

tasks.withType<Test>().configureEach {
    // The contract test round-trips the spec's examples, so editing the spec re-runs it.
    inputs.files(fileTree(rootDir.resolve("../contracts/api")) { include("openapi.bundled.json") })
        .withPropertyName("apiSpec")
        .withPathSensitivity(PathSensitivity.RELATIVE)
    testLogging.exceptionFormat = org.gradle.api.tasks.testing.logging.TestExceptionFormat.FULL
}
