plugins {
    `kotlin-dsl`
}

java {
    toolchain.languageVersion.set(JavaLanguageVersion.of(17))
}

dependencies {
    compileOnly(libs.android.gradle.plugin)
    compileOnly(libs.kotlin.gradle.plugin)
    compileOnly(libs.compose.gradle.plugin)
    compileOnly(libs.ksp.gradle.plugin)
    compileOnly(libs.detekt.gradle.plugin)
    // The generators' tests (AwradIconsTest). :core:designsystem's verifyAwradIcons runs them.
    testImplementation(libs.kotlin.test)
}

gradlePlugin {
    plugins {
        register("jvmLibrary") {
            id = "awrad.jvm.library"
            implementationClass = "JvmLibraryConventionPlugin"
        }
        register("androidLibrary") {
            id = "awrad.android.library"
            implementationClass = "AndroidLibraryConventionPlugin"
        }
        register("androidCompose") {
            id = "awrad.android.compose"
            implementationClass = "AndroidComposeConventionPlugin"
        }
        register("androidHilt") {
            id = "awrad.android.hilt"
            implementationClass = "AndroidHiltConventionPlugin"
        }
        register("androidFeature") {
            id = "awrad.android.feature"
            implementationClass = "AndroidFeatureConventionPlugin"
        }
        register("androidApplication") {
            id = "awrad.android.application"
            implementationClass = "AndroidApplicationConventionPlugin"
        }
        register("moduleRules") {
            id = "awrad.module-rules"
            implementationClass = "ModuleRulesConventionPlugin"
        }
    }
}
