plugins {
    id("awrad.android.library")
    id("awrad.android.compose")
}

android {
    namespace = "app.awrad.core.designsystem"
}

dependencies {
    api(platform(libs.androidx.compose.bom))
    api(libs.androidx.compose.material3)
    api(libs.androidx.compose.material.icons.extended)
}
