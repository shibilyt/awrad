import org.gradle.api.Plugin
import org.gradle.api.Project
import org.gradle.kotlin.dsl.dependencies

/** Pure Kotlin module: no Android, tests run on the JVM. */
class JvmLibraryConventionPlugin : Plugin<Project> {
    override fun apply(target: Project) = with(target) {
        pluginManager.apply("org.jetbrains.kotlin.jvm")
        configureKotlinJvm()
        configureDetekt()
        dependencies {
            add("testImplementation", libs.lib("kotlin-test"))
            add("testImplementation", libs.lib("kotlinx-coroutines-test"))
        }
    }
}
