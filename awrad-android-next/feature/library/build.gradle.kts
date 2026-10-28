plugins {
    id("awrad.android.feature")
}

android {
    namespace = "app.awrad.feature.library"
    // The fast-typing test composes real screens on Robolectric, which needs the module's resources.
    testOptions.unitTests.isIncludeAndroidResources = true
}

dependencies {
    // Compose UI tests on Robolectric (FastTypingTest); the test manifest supplies their host activity.
    testImplementation(platform(libs.androidx.compose.bom))
    testImplementation(libs.androidx.compose.ui.test.junit4)
    testImplementation(libs.robolectric)
    debugImplementation(libs.androidx.compose.ui.test.manifest)
}

tasks.withType<Test>().configureEach {
    // The ViewModel tests run over the shared catalog (FakeDhikrCatalogSource), so a catalog change re-runs them.
    inputs.files(fileTree(rootDir.resolve("../contracts/dhikr-catalog")))
        .withPropertyName("dhikrCatalog")
        .withPathSensitivity(PathSensitivity.RELATIVE)
}
