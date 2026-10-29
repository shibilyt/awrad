plugins {
    id("awrad.android.feature")
}

android {
    namespace = "app.awrad.feature.practice"
}

tasks.withType<Test>().configureEach {
    // The ViewModel tests search the shared city list (FakeCitySource), so a list change re-runs them.
    inputs.files(fileTree(rootDir.resolve("../contracts/places")))
        .withPropertyName("places")
        .withPathSensitivity(PathSensitivity.RELATIVE)
}
