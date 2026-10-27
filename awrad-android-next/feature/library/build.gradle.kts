plugins {
    id("awrad.android.feature")
}

android {
    namespace = "app.awrad.feature.library"
}

tasks.withType<Test>().configureEach {
    // The ViewModel tests run over the shared catalog (FakeDhikrCatalogSource), so a catalog change re-runs them.
    inputs.files(fileTree(rootDir.resolve("../contracts/dhikr-catalog")))
        .withPropertyName("dhikrCatalog")
        .withPathSensitivity(PathSensitivity.RELATIVE)
}
