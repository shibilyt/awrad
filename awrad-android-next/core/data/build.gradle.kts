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
    testImplementation(libs.kotlinx.serialization.json)
}

tasks.withType<Test>().configureEach {
    // ProblemCodeMappingTest reads every documented error code from the spec.
    inputs.files(fileTree(rootDir.resolve("../contracts/api")) { include("openapi.bundled.json") })
        .withPropertyName("apiSpec")
        .withPathSensitivity(PathSensitivity.RELATIVE)
}
