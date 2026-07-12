import java.net.URI
import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.ksp)
    alias(libs.plugins.hilt.android)
    alias(libs.plugins.kotlin.serialization)
}

fun String.toBuildConfigString(): String = "\"" + replace("\\", "\\\\").replace("\"", "\\\"") + "\""

fun validateApiBaseUrl(value: String, allowHttp: Boolean): String {
    val normalized = if (value.endsWith("/")) value else "$value/"
    val uri = URI(normalized)
    val scheme = uri.scheme?.lowercase()
    require(scheme == "https" || (allowHttp && scheme == "http")) {
        "API base URL must use HTTPS${if (allowHttp) " or HTTP for debug" else ""}: $value"
    }
    require(!uri.host.isNullOrBlank()) {
        "API base URL must include a host: $value"
    }
    return normalized
}

fun configuredValue(name: String): String? =
    providers.gradleProperty(name)
        .orElse(providers.environmentVariable(name))
        .orNull
        ?.trim()
        ?.takeIf { it.isNotEmpty() }

fun parseAppVersionCode(value: String?): Int {
    if (value == null) return 1
    val parsed = value.toIntOrNull()
    require(parsed != null && parsed > 0) {
        "AWRAD_VERSION_CODE must be a positive integer: $value"
    }
    return parsed
}

fun parseAppVersionName(value: String?): String {
    if (value == null) return "1.0"
    require(value.matches(Regex("""\d+(\.\d+){1,3}([+-][A-Za-z0-9][A-Za-z0-9._-]*)?"""))) {
        "AWRAD_VERSION_NAME must look like a release version, for example 1.2.0: $value"
    }
    return value
}

val appVersionCodeValue = configuredValue("AWRAD_VERSION_CODE")
val appVersionNameValue = configuredValue("AWRAD_VERSION_NAME")
val resolvedAppVersionCode = parseAppVersionCode(appVersionCodeValue)
val resolvedAppVersionName = parseAppVersionName(appVersionNameValue)

val debugApiBaseUrl = validateApiBaseUrl(
    providers.gradleProperty("AWRAD_DEBUG_API_BASE_URL")
        .orElse(providers.environmentVariable("AWRAD_DEBUG_API_BASE_URL"))
        .getOrElse("http://10.0.2.2:4000/"),
    allowHttp = true,
)
val releaseApiBaseUrl = providers.gradleProperty("AWRAD_RELEASE_API_BASE_URL")
    .orElse(providers.environmentVariable("AWRAD_RELEASE_API_BASE_URL"))
    .orNull
    ?.trim()
val normalizedReleaseApiBaseUrl = releaseApiBaseUrl
    ?.takeIf { it.isNotBlank() }
    ?.let { validateApiBaseUrl(it, allowHttp = false) }
    ?: "https://invalid.awrad.local/"
gradle.taskGraph.whenReady {
    val releaseTaskRequested = allTasks.any { task ->
        task.project == project && task.name.contains("Release", ignoreCase = true)
    }
    if (releaseTaskRequested && releaseApiBaseUrl.isNullOrBlank()) {
        throw GradleException(
            "Release builds require AWRAD_RELEASE_API_BASE_URL as a Gradle property or environment variable.",
        )
    }
    if (releaseTaskRequested && (appVersionCodeValue == null || appVersionNameValue == null)) {
        throw GradleException(
            "Release builds require explicit app version values. " +
                "Pass -PAWRAD_VERSION_CODE=<next integer> -PAWRAD_VERSION_NAME=<version>, " +
                "or set AWRAD_VERSION_CODE and AWRAD_VERSION_NAME in the environment.",
        )
    }
}

// Release signing comes from keystore.properties (gitignored, not committed). Absent in CI/dev
// environments that don't produce signed release builds — the release signingConfig is then skipped.
val keystorePropertiesFile = rootProject.file("keystore.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}

android {
    namespace = "app.awrad.awrad_dhikrgoalstracker"
    compileSdk {
        version = release(36)
    }

    defaultConfig {
        applicationId = "app.awrad.awrad_dhikrgoalstracker"
        minSdk = 26
        targetSdk = 36
        versionCode = resolvedAppVersionCode
        versionName = resolvedAppVersionName

        testInstrumentationRunner = "app.awrad.awrad_dhikrgoalstracker.HiltTestRunner"

        ksp {
            arg("room.schemaLocation", "$projectDir/schemas")
        }
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        debug {
            buildConfigField("String", "API_BASE_URL", debugApiBaseUrl.toBuildConfigString())
        }
        release {
            buildConfigField("String", "API_BASE_URL", normalizedReleaseApiBaseUrl.toBuildConfigString())
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    kotlinOptions {
        jvmTarget = "11"
    }
    buildFeatures {
        compose = true
        buildConfig = true
    }
    sourceSets {
        getByName("androidTest").assets.srcDir("$projectDir/schemas")
    }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.core.splashscreen)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.appcompat)
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.graphics)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.material.icons.extended)

    // Hilt
    implementation(libs.hilt.android)
    ksp(libs.hilt.android.compiler)
    implementation(libs.hilt.navigation.compose)

    // Room
    implementation(libs.room.runtime)
    ksp(libs.room.compiler)
    implementation(libs.room.ktx)

    implementation(libs.kotlinx.serialization.json)

    // Media3
    implementation(libs.media3.exoplayer)
    implementation(libs.media3.session)
    implementation(libs.media3.ui)

    // Navigation
    implementation(libs.navigation.compose)

    // DataStore
    implementation(libs.datastore.preferences)
    implementation(libs.androidx.security.crypto)

    // Gson
    implementation(libs.gson)

    // Retrofit + OkHttp
    implementation(libs.retrofit)
    implementation(libs.retrofit.converter.gson)
    implementation(libs.okhttp)
    implementation(libs.okhttp.logging.interceptor)

    // Adhan (prayer time calculation)
    implementation(libs.adhan)

    // WorkManager
    implementation(libs.work.runtime.ktx)
    implementation(libs.hilt.work)
    ksp(libs.hilt.work.compiler)

    // Lifecycle
    implementation(libs.lifecycle.viewmodel.compose)
    implementation(libs.lifecycle.runtime.compose)

    testImplementation(libs.junit)
    testImplementation(libs.kotlinx.coroutines.test)
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(libs.androidx.espresso.core)
    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.compose.ui.test.junit4)
    debugImplementation(libs.androidx.compose.ui.tooling)
    debugImplementation(libs.androidx.compose.ui.test.manifest)

    // Hilt testing
    androidTestImplementation(libs.hilt.android.testing)
    kspAndroidTest(libs.hilt.android.compiler)

    // Coroutines testing
    androidTestImplementation(libs.kotlinx.coroutines.test)

    // Room testing
    androidTestImplementation(libs.room.testing)
    androidTestImplementation(libs.androidx.test.rules)
}
