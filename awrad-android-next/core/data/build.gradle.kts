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
    implementation(libs.androidx.datastore.preferences)
}
