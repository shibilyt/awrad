import org.gradle.api.GradleException
import org.gradle.api.Plugin
import org.gradle.api.Project
import org.gradle.api.artifacts.ProjectDependency

/**
 * Enforces the module dependency graph at configuration time. A forbidden
 * edge fails every build, so seams cannot erode one import at a time.
 *
 * Applied once, to the root project.
 */
class ModuleRulesConventionPlugin : Plugin<Project> {

    override fun apply(target: Project) {
        require(target == target.rootProject) { "awrad.module-rules belongs on the root project" }
        target.gradle.projectsEvaluated {
            val violations = target.subprojects.flatMap(::violationsOf)
            if (violations.isNotEmpty()) {
                throw GradleException(
                    "Module dependency rules violated (see ARCHITECTURE.md):\n" +
                        violations.joinToString("\n") { "  - $it" },
                )
            }
        }
    }

    private fun violationsOf(project: Project): List<String> {
        val allowed = allowedDependencies(project.path)
            ?: return listOf("${project.path} has no rule. Add one to ModuleRulesConventionPlugin.")
        return project.configurations
            .filter { it.name in CHECKED_CONFIGURATIONS || it.name in TEST_CONFIGURATIONS }
            .flatMap { configuration ->
                val permitted = if (configuration.name in TEST_CONFIGURATIONS) allowed + TEST_ONLY else allowed
                configuration.dependencies
                    .filterIsInstance<ProjectDependency>()
                    .map { it.path }
                    .filter { it != project.path && it !in permitted && ANY !in permitted }
                    .map { "${project.path} -(${configuration.name})-> $it is not allowed" }
            }
    }

    private fun allowedDependencies(path: String): Set<String>? = when {
        path == ":app" -> setOf(ANY)
        path.startsWith(":feature:") -> setOf(":core:domain", ":core:designsystem")
        path == ":core:data" -> setOf(":core:domain", ":core:database", ":core:network")
        path == ":core:testing" -> setOf(":core:domain")
        path in LEAF_MODULES -> emptySet()
        // Grouping projects (":core", ":feature") have no code.
        path == ":core" || path == ":feature" -> emptySet()
        else -> null
    }

    private companion object {
        const val ANY = "*"
        val LEAF_MODULES = setOf(":core:domain", ":core:database", ":core:designsystem", ":core:network")
        val TEST_ONLY = setOf(":core:testing")
        val CHECKED_CONFIGURATIONS = setOf("api", "implementation", "compileOnly", "runtimeOnly")
        val TEST_CONFIGURATIONS = setOf("testImplementation", "androidTestImplementation")
    }
}
