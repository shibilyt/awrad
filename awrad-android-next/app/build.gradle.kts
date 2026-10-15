plugins {
    id("awrad.android.application")
    id("awrad.android.compose")
    id("awrad.android.hilt")
    alias(libs.plugins.kotlin.serialization)
}

android {
    namespace = "app.awrad.next"

    defaultConfig {
        // Distinct from awrad-android so both install side by side.
        applicationId = "app.awrad.awrad_dhikrgoalstracker.next"
        versionCode = 1
        versionName = "0.1.0-poc"
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

dependencies {
    implementation(project(":core:domain"))
    implementation(project(":core:data"))
    implementation(project(":core:designsystem"))
    implementation(project(":feature:onboarding"))

    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.navigation.compose)
    implementation(libs.hilt.navigation.compose)
    implementation(libs.kotlinx.serialization.json)

    testImplementation(project(":core:testing"))
}
