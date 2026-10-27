import com.android.build.api.dsl.CommonExtension
import io.gitlab.arturbosch.detekt.extensions.DetektExtension
import org.gradle.api.JavaVersion
import org.gradle.api.Project
import org.gradle.api.artifacts.VersionCatalog
import org.gradle.api.artifacts.VersionCatalogsExtension
import org.gradle.kotlin.dsl.configure
import org.gradle.kotlin.dsl.dependencies
import org.gradle.kotlin.dsl.getByType
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension
import org.jetbrains.kotlin.gradle.dsl.KotlinJvmProjectExtension

/** Shared numbers for every Android module. Change them here, never per module. */
internal object AwradSdk {
    const val COMPILE = 36
    const val MIN = 26
    const val TARGET = 36
    val java = JavaVersion.VERSION_17
    val jvmTarget = JvmTarget.JVM_17
}

internal val Project.libs: VersionCatalog
    get() = extensions.getByType<VersionCatalogsExtension>().named("libs")

internal fun VersionCatalog.lib(alias: String) = findLibrary(alias).get()

internal fun Project.configureAndroidCommon(extension: CommonExtension<*, *, *, *, *, *>) {
    extension.apply {
        compileSdk = AwradSdk.COMPILE
        defaultConfig.minSdk = AwradSdk.MIN
        compileOptions {
            sourceCompatibility = AwradSdk.java
            targetCompatibility = AwradSdk.java
        }
        testOptions.unitTests.isReturnDefaultValues = true
        lint {
            warningsAsErrors = true
            abortOnError = true
            checkDependencies = true
            // Version bumps are a deliberate, repo-wide decision (see libs.versions.toml).
            disable += setOf("GradleDependency", "NewerVersionAvailable", "AndroidGradlePluginVersion")
        }
    }
}

/**
 * Library modules use explicit API mode: every public declaration states its
 * visibility, so a module's interface is a deliberate choice, not an accident.
 */
internal fun Project.configureKotlinAndroid(explicitApi: Boolean) {
    extensions.configure<KotlinAndroidProjectExtension> {
        if (explicitApi) explicitApi()
        compilerOptions {
            jvmTarget.set(AwradSdk.jvmTarget)
            allWarningsAsErrors.set(true)
        }
    }
}

internal fun Project.configureKotlinJvm() {
    extensions.configure<KotlinJvmProjectExtension> {
        explicitApi()
        jvmToolchain(17)
        compilerOptions {
            allWarningsAsErrors.set(true)
        }
    }
}

internal const val MAX_SOURCE_FILE_LINES = 400

internal fun Project.configureSourceFileSize() {
    val verify = tasks.register("verifySourceFileSize", SourceFileSizeTask::class.java) {
        sources.from(fileTree("src") { include("main/**/*.kt", "debug/**/*.kt") })
        maxLines.set(MAX_SOURCE_FILE_LINES)
    }
    tasks.matching { it.name == "check" }.configureEach { dependsOn(verify) }
}

/**
 * Colours come only from the generated design tokens. Besides `check`, `detekt` runs this, so the
 * validation command catches a hex value without running `check`.
 */
internal fun Project.configureColorLiterals() {
    val verify = tasks.register("verifyColorLiterals", ColorLiteralTask::class.java) {
        // `debug` holds the debug-only component gallery, which uses the tokens like any screen.
        sources.from(
            fileTree("src") {
                include("main/**/*.kt", "main/res/**/*.xml", "debug/**/*.kt", "debug/res/**/*.xml")
                // Generated from contracts/design-tokens (AwradColorsTask).
                exclude("main/**/designsystem/theme/AwradColors.kt", "main/res/values*/awrad_colors.xml")
                // The launcher icon's background is part of the icon artwork, not a UI colour.
                exclude("main/res/values/ic_launcher_background.xml")
            },
        )
    }
    tasks.matching { it.name == "check" || it.name == "detekt" }.configureEach { dependsOn(verify) }
}

/**
 * Spacing, sizes, radii, text styles and motion come only from the generated design tokens, outside
 * `:core:designsystem` (which turns the tokens into components). Like [configureColorLiterals], `detekt` runs it.
 */
internal fun Project.configureDesignLiterals() {
    if (path == DESIGN_SYSTEM) return
    val verify = tasks.register("verifyDesignLiterals", DesignLiteralTask::class.java) {
        sources.from(fileTree("src") { include("main/**/*.kt", "debug/**/*.kt") })
        // Genuinely structural values, as "<path suffix>: <matched text>", each with the reason. None yet.
        allowed.set(emptyList<String>())
    }
    tasks.matching { it.name == "check" || it.name == "detekt" }.configureEach { dependsOn(verify) }
}

private const val DESIGN_SYSTEM = ":core:designsystem"

internal fun Project.configureDetekt() {
    configureSourceFileSize()
    configureColorLiterals()
    configureDesignLiterals()
    pluginManager.apply("io.gitlab.arturbosch.detekt")
    extensions.configure<DetektExtension> {
        buildUponDefaultConfig = true
        allRules = false
        config.setFrom(rootProject.file("config/detekt/detekt.yml"))
        // The design system may wrap the Material components detekt.yml bans, but not Material Icons: its own
        // file overrides that rule (a later config file wins over an earlier one).
        if (path == DESIGN_SYSTEM) config.from(rootProject.file("config/detekt/designsystem.yml"))
        // The debug-only component gallery is held to the same rules.
        source.from(files("src/debug/kotlin"))
        parallel = true
    }
    dependencies {
        add("detektPlugins", libs.lib("detekt-formatting"))
        add("detektPlugins", libs.lib("compose-rules-detekt"))
    }
}
