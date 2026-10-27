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

// The shared colour roles ship as committed source (ARCHITECTURE.md, "Colours").
val colorsContract = rootDir.resolve("../contracts/design-tokens/v1/colors.json")

fun AwradColorsTask.configureColors(verify: Boolean) {
    contract.set(colorsContract)
    source.set(file("src/main/kotlin/app/awrad/core/designsystem/theme/AwradColors.kt"))
    lightResource.set(file("src/main/res/values/awrad_colors.xml"))
    darkResource.set(file("src/main/res/values-night/awrad_colors.xml"))
    packageName.set("app.awrad.core.designsystem.theme")
    verifyOnly.set(verify)
    regenerateCommand.set("./gradlew :core:designsystem:generateAwradColors")
}

tasks.register<AwradColorsTask>("generateAwradColors") {
    description = "Regenerates AwradColors and the colour resources from contracts/design-tokens."
    configureColors(verify = false)
}

val verifyAwradColors = tasks.register<AwradColorsTask>("verifyAwradColors") {
    description = "Fails when the bundled colours differ from contracts/design-tokens."
    group = "verification"
    configureColors(verify = true)
}

// The bundled fonts are byte-for-byte the shared ones (ARCHITECTURE.md, "Fonts").
val verifyAwradFonts = tasks.register<AwradFontsTask>("verifyAwradFonts") {
    description = "Fails when a bundled font differs from contracts/design-tokens/v1/fonts (SHA256SUMS)."
    group = "verification"
    checksums.set(rootDir.resolve("../contracts/design-tokens/v1/fonts/SHA256SUMS"))
    fontDirectory.set(file("src/main/res/font"))
}

// The unit tests (testDebugUnitTest in the validation command) and lint read the bundled colours and fonts, so
// they must be the contract's.
val verifyDesignTokens = listOf(verifyAwradColors, verifyAwradFonts)
tasks.named("check") { dependsOn(verifyDesignTokens) }
tasks.withType<Test>().configureEach { dependsOn(verifyDesignTokens) }
tasks.matching { it.name.startsWith("lint") }.configureEach { dependsOn(verifyDesignTokens) }
