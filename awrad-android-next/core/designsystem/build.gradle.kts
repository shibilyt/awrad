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
    // WindowCompat: dialogs and sheets lay their window out under the system bars.
    implementation(libs.androidx.core.ktx)
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

// Shapes, spacing, type and motion ship as committed source too (ARCHITECTURE.md, "Design tokens").
val tokensDirectory = rootDir.resolve("../contracts/design-tokens/v1")
val themeSources = "src/main/kotlin/app/awrad/core/designsystem/theme"

fun AwradTokensTask.configureTokens(verify: Boolean) {
    shapeContract.set(tokensDirectory.resolve("shape.json"))
    spacingContract.set(tokensDirectory.resolve("spacing.json"))
    typographyContract.set(tokensDirectory.resolve("typography.json"))
    motionContract.set(tokensDirectory.resolve("motion.json"))
    colorsContract.set(tokensDirectory.resolve("colors.json"))
    shapeSource.set(file("$themeSources/AwradShapes.kt"))
    spacingSource.set(file("$themeSources/AwradSpacing.kt"))
    typeSource.set(file("$themeSources/AwradType.kt"))
    motionSource.set(file("$themeSources/AwradMotionTokens.kt"))
    packageName.set("app.awrad.core.designsystem.theme")
    // The contract's font family → the FontFamily in Type.kt that bundles its files.
    fontFamilies.put("Google Sans Flex Rounded", "InterfaceFontFamily")
    fontFamilies.put("Noto Naskh Arabic", "ArabicScriptFontFamily")
    verifyOnly.set(verify)
    regenerateCommand.set("./gradlew :core:designsystem:generateAwradTokens")
}

tasks.register<AwradTokensTask>("generateAwradTokens") {
    description = "Regenerates the shape, spacing, type and motion tokens from contracts/design-tokens."
    configureTokens(verify = false)
}

val verifyAwradTokens = tasks.register<AwradTokensTask>("verifyAwradTokens") {
    description = "Fails when the bundled shape, spacing, type or motion tokens differ from contracts/design-tokens."
    group = "verification"
    configureTokens(verify = true)
}

// The bundled fonts are byte-for-byte the shared ones (ARCHITECTURE.md, "Fonts").
val verifyAwradFonts = tasks.register<AwradFontsTask>("verifyAwradFonts") {
    description = "Fails when a bundled font differs from contracts/design-tokens/v1/fonts (SHA256SUMS)."
    group = "verification"
    checksums.set(rootDir.resolve("../contracts/design-tokens/v1/fonts/SHA256SUMS"))
    fontDirectory.set(file("src/main/res/font"))
}

// The shared icons ship as committed vector drawables and accessors (ARCHITECTURE.md, "Icons").
fun AwradIconsTask.configureIcons(verify: Boolean) {
    contract.set(tokensDirectory.resolve("icons.json"))
    svgDirectory.set(tokensDirectory.resolve("icons"))
    drawableDirectory.set(file("src/main/res/drawable"))
    source.set(file("src/main/kotlin/app/awrad/core/designsystem/icon/AwradIcons.kt"))
    packageName.set("app.awrad.core.designsystem.icon")
    resourcePackage.set(android.namespace)
    verifyOnly.set(verify)
    regenerateCommand.set("./gradlew :core:designsystem:generateAwradIcons")
}

tasks.register<AwradIconsTask>("generateAwradIcons") {
    description = "Regenerates the awrad_ic_* vector drawables and AwradIcons from contracts/design-tokens."
    configureIcons(verify = false)
}

val verifyAwradIcons = tasks.register<AwradIconsTask>("verifyAwradIcons") {
    description = "Fails when the bundled icons differ from contracts/design-tokens/v1/icons.json and its SVGs."
    group = "verification"
    configureIcons(verify = true)
    // The generator's own tests (mirroring, unknown keys, SVGs it can't convert) run with the check.
    dependsOn(gradle.includedBuild("build-logic").task(":convention:test"))
}

// The unit tests (testDebugUnitTest in the validation command) and lint read the bundled tokens, fonts and icons,
// so they must be the contract's. detekt runs them too, like the colour and design literal checks.
val verifyDesignTokens = listOf(verifyAwradColors, verifyAwradTokens, verifyAwradFonts, verifyAwradIcons)
tasks.named("check") { dependsOn(verifyDesignTokens) }
tasks.withType<Test>().configureEach { dependsOn(verifyDesignTokens) }
tasks.matching { it.name.startsWith("lint") || it.name == "detekt" }.configureEach { dependsOn(verifyDesignTokens) }
