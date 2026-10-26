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

    buildFeatures.buildConfig = true

    buildTypes {
        debug {
            // A local awrad-server-next: the emulator reaches the host's localhost as 10.0.2.2.
            // Override with -Pawrad.apiBaseUrl=http://localhost:4000 (device + `adb reverse tcp:4000 tcp:4000`).
            val apiBaseUrl = providers.gradleProperty("awrad.apiBaseUrl").getOrElse("http://10.0.2.2:4000")
            buildConfigField("String", "API_BASE_URL", "\"$apiBaseUrl\"")
        }
        release {
            // Reserved .invalid host until the server is deployed, so a release build never reaches a dev server.
            buildConfigField("String", "API_BASE_URL", "\"https://api.awrad.invalid\"")
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

dependencies {
    implementation(project(":core:domain"))
    implementation(project(":core:data"))
    implementation(project(":core:designsystem"))
    implementation(project(":core:network"))
    implementation(project(":feature:onboarding"))
    implementation(project(":feature:account"))

    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.navigation.compose)
    implementation(libs.hilt.navigation.compose)
    implementation(libs.kotlinx.serialization.json)

    testImplementation(project(":core:testing"))
}
