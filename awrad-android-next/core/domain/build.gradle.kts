plugins {
    id("awrad.jvm.library")
}

dependencies {
    api(libs.kotlinx.coroutines.core)
    api(libs.javax.inject)
    testImplementation(project(":core:testing"))
}

tasks.test {
    // The shared goal-model fixtures are the spec these tests run, so editing a case re-runs them.
    inputs.files(fileTree(rootDir.resolve("../contracts/goal-model")))
        .withPropertyName("goalModelFixtures")
        .withPathSensitivity(PathSensitivity.RELATIVE)
    // Print the whole assertion, which names every failing case id, in the build log.
    testLogging.exceptionFormat = org.gradle.api.tasks.testing.logging.TestExceptionFormat.FULL
}
