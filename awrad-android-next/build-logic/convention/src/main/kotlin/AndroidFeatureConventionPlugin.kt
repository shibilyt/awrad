import org.gradle.api.Plugin
import org.gradle.api.Project
import org.gradle.kotlin.dsl.dependencies
import org.gradle.kotlin.dsl.project

/**
 * A feature sees the domain's ports and the design system, nothing else.
 * Adapters (Room, DataStore, network) are wired by :app through Hilt.
 */
class AndroidFeatureConventionPlugin : Plugin<Project> {
    override fun apply(target: Project) = with(target) {
        pluginManager.apply("awrad.android.library")
        pluginManager.apply("awrad.android.compose")
        pluginManager.apply("awrad.android.hilt")
        pluginManager.apply("org.jetbrains.kotlin.plugin.serialization")
        dependencies {
            add("implementation", project(":core:domain"))
            add("implementation", project(":core:designsystem"))
            add("implementation", libs.lib("androidx-lifecycle-runtime-compose"))
            add("implementation", libs.lib("androidx-lifecycle-viewmodel-compose"))
            add("implementation", libs.lib("androidx-navigation-compose"))
            add("implementation", libs.lib("hilt-navigation-compose"))
            add("implementation", libs.lib("kotlinx-serialization-json"))
            add("testImplementation", project(":core:testing"))
        }
    }
}
