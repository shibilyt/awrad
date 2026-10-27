import TokenText.appendDoc
import TokenText.float
import TokenText.identifier
import TokenText.int
import TokenText.sentence
import TokenText.string
import TokenText.typeName

/**
 * Renders motion.json (AwradTokensTask): easings as `CubicBezierEasing`, durations as `Int` milliseconds, springs
 * as `AwradSpring(dampingRatio, stiffness)`, haptics as the `AwradHaptic` enum, and the named motions Android uses
 * as nested objects whose references (a duration, an easing, a spring, a haptic, a shape role) resolve to the
 * generated values. A named motion's keys are typed by [KEYS]; an unknown key fails generation, so a new kind of
 * value in the contract gets a deliberate Kotlin type instead of being dropped.
 */
internal class MotionTokens(private val file: TokenFile, private val shapes: ShapeTokens.Parsed) {

    private enum class Kind { FLOAT, INT, MILLIS, DP, DURATION, EASING, SPRING, HAPTIC, RADIUS, STRING }

    private val easings = file.obj("easing").keys.associateWith { identifier(file, it) }
    private val durations = file.obj("duration").keys.associateWith { identifier(file, it) }
    private val springs = file.obj("spring").keys.associateWith { identifier(file, it) }
    private val haptics = file.obj("haptic").keys.associateWith { typeName(identifier(file, it)) }

    fun render(header: TokenHeader): String = buildString {
        with(header) {
            appendHeader(
                "motion.json",
                listOf(
                    "androidx.compose.animation.core.CubicBezierEasing",
                    "androidx.compose.animation.core.Easing",
                    "androidx.compose.ui.unit.Dp",
                    "androidx.compose.ui.unit.dp",
                ),
            )
        }
        appendEasings()
        appendLine()
        appendDurations()
        appendLine()
        appendSprings()
        appendLine()
        appendHaptics()
        appendLine()
        appendMotions()
    }

    private fun StringBuilder.appendEasings() {
        appendLine("/** Easings, as cubic-bezier control points. */")
        appendLine("public object AwradEasing {")
        @Suppress("UNCHECKED_CAST")
        file.obj("easing").entries.forEachIndexed { index, (name, value) ->
            val points = value as? List<Any?> ?: file.fail("easing.$name must be four numbers")
            if (points.size != BEZIER_POINTS) file.fail("easing.$name must be four numbers")
            val args = points.joinToString(", ") { float(file, "easing.$name", it) }
            if (index > 0) appendLine()
            appendDoc("    ", "`$name`: (${points.joinToString(", ")}).")
            appendLine("    public val ${easings.getValue(name)}: Easing = CubicBezierEasing($args)")
        }
        appendLine("}")
    }

    private fun StringBuilder.appendDurations() {
        appendLine("/** Durations in milliseconds. */")
        appendLine("public object AwradDurations {")
        file.obj("duration").forEach { (name, value) ->
            appendLine("    public const val ${durations.getValue(name)}: Int = ${int(file, "duration.$name", value)}")
        }
        appendLine("}")
    }

    private fun StringBuilder.appendSprings() {
        appendLine("/** Springs (dampingRatio, stiffness, mass 1). `AwradSpring.spec()` makes the Compose `spring()`. */")
        appendLine("public object AwradSprings {")
        @Suppress("UNCHECKED_CAST")
        file.obj("spring").entries.forEachIndexed { index, (name, value) ->
            val spring = value as? Map<String, Any?> ?: file.fail("spring.$name must be an object")
            val damping = float(file, "spring.$name.dampingRatio", spring["dampingRatio"])
            val stiffness = float(file, "spring.$name.stiffness", spring["stiffness"])
            if (index > 0) appendLine()
            appendDoc("    ", sentence(string(file, "spring.$name.use", spring["use"])))
            appendLine(
                "    public val ${springs.getValue(name)}: AwradSpring = " +
                    "AwradSpring(dampingRatio = $damping, stiffness = $stiffness)",
            )
        }
        appendLine("}")
    }

    private fun StringBuilder.appendHaptics() {
        appendLine("/** Haptic feedback by meaning. `AwradHaptics` performs them. */")
        appendLine("public enum class AwradHaptic {")
        @Suppress("UNCHECKED_CAST")
        file.obj("haptic").entries.forEachIndexed { index, (name, value) ->
            val haptic = value as? Map<String, Any?> ?: file.fail("haptic.$name must be an object")
            if (index > 0) appendLine()
            appendDoc("    ", sentence(string(file, "haptic.$name.use", haptic["use"])))
            appendLine("    ${haptics.getValue(name)},")
        }
        appendLine("}")
    }

    private fun StringBuilder.appendMotions() {
        appendLine("/** The named motions Android uses, and reduced motion. `AwradMotion` turns them into specs. */")
        appendLine("public object AwradMotions {")
        @Suppress("UNCHECKED_CAST")
        val android = file.obj("motions").filter { (name, value) ->
            val motion = value as? Map<String, Any?> ?: file.fail("motions.$name must be an object")
            val platforms = motion["platforms"] as? List<Any?> ?: file.fail("motions.$name.platforms must be a list")
            "android" in platforms
        }
        android.entries.forEachIndexed { index, (name, value) ->
            if (index > 0) appendLine()
            @Suppress("UNCHECKED_CAST")
            appendMotion("    ", "motions.$name", typeName(identifier(file, name)), value as Map<String, Any?>)
        }
        appendLine()
        appendReducedMotion()
        appendLine("}")
    }

    private fun StringBuilder.appendReducedMotion() {
        val reduced = file.obj("reducedMotion")
        val replaceWith = reduced["replaceWith"]
        if (replaceWith != "crossfade") file.fail("reducedMotion.replaceWith must be crossfade, was $replaceWith")
        appendDoc("    ", sentence(string(file, "reducedMotion.use", reduced["use"])))
        appendLine("    public object ReducedMotion {")
        appendLine("        /** A cross-fade of this duration replaces every movement, scale and spring. */")
        appendLine("        public const val durationMillis: Int = ${duration("reducedMotion.duration", reduced["duration"])}")
        appendLine("    }")
    }

    private fun StringBuilder.appendMotion(indent: String, path: String, name: String, motion: Map<String, Any?>) {
        motion["use"]?.let { appendDoc(indent, sentence(string(file, "$path.use", it))) }
        appendLine("${indent}public object $name {")
        val properties = motion.filterKeys { it != "use" && it != "platforms" }
        var previousWasObject = false
        properties.entries.forEachIndexed { index, (key, value) ->
            if (index > 0 && (value is Map<*, *> || previousWasObject)) appendLine()
            previousWasObject = value is Map<*, *>
            if (value is Map<*, *>) {
                @Suppress("UNCHECKED_CAST")
                appendMotion("$indent    ", "$path.$key", typeName(identifier(file, key)), value as Map<String, Any?>)
            } else {
                appendLine("$indent    ${property("$path.$key", key, value)}")
            }
        }
        appendLine("$indent}")
    }

    private fun property(path: String, key: String, value: Any?): String {
        val kind = KEYS[key] ?: file.fail("$path: no Android type for '$key' yet; add it to MotionTokens.KEYS")
        val id = identifier(file, key)
        return when (kind) {
            Kind.FLOAT -> "public const val $id: Float = ${float(file, path, value)}"
            Kind.INT -> "public const val $id: Int = ${int(file, path, value)}"
            Kind.MILLIS -> "public const val ${id}Millis: Int = ${int(file, path, value)}"
            Kind.DP -> "public val $id: Dp = ${int(file, path, value)}.dp"
            Kind.DURATION -> "public const val ${id}Millis: Int = ${duration(path, value)}"
            Kind.EASING -> "public val $id: Easing = AwradEasing.${ref(path, value, easings)}"
            Kind.SPRING -> "public val $id: AwradSpring = AwradSprings.${ref(path, value, springs)}"
            Kind.HAPTIC -> "public val $id: AwradHaptic = AwradHaptic.${ref(path, value, haptics)}"
            Kind.RADIUS -> {
                val role = shapes.role(string(file, path, value))
                if (role.step.radius == null) file.fail("$path: '${role.name}' is fully rounded, not a radius")
                "public val $id: Dp = AwradRadius.${role.step.name}"
            }
            Kind.STRING -> "public const val $id: String = \"${string(file, path, value)}\""
        }
    }

    private fun duration(path: String, value: Any?): String = "AwradDurations.${ref(path, value, durations)}"

    private fun ref(path: String, value: Any?, names: Map<String, String>): String {
        val name = string(file, path, value)
        return names[name] ?: file.fail("$path: '$name' isn't one of ${names.keys}")
    }

    private companion object {
        const val BEZIER_POINTS = 4

        /** How each key of a named motion is typed in Kotlin. */
        val KEYS = mapOf(
            "scaleFrom" to Kind.FLOAT,
            "scaleTo" to Kind.FLOAT,
            "fadeFrom" to Kind.FLOAT,
            "pillScaleFrom" to Kind.FLOAT,
            "iconScale" to Kind.FLOAT,
            "cardScale" to Kind.FLOAT,
            "buttonScale" to Kind.FLOAT,
            "popScale" to Kind.FLOAT,
            "overshootScale" to Kind.FLOAT,
            "dim" to Kind.FLOAT,
            // Degrees.
            "chevronRotation" to Kind.FLOAT,
            // Velocity in dp (pt) per second.
            "releaseVelocity" to Kind.FLOAT,
            "maxStaggered" to Kind.INT,
            // A delay in milliseconds, not a named duration.
            "stagger" to Kind.MILLIS,
            "offset" to Kind.DP,
            "duration" to Kind.DURATION,
            "fadeDuration" to Kind.DURATION,
            "colorDuration" to Kind.DURATION,
            "pressDuration" to Kind.DURATION,
            "fadeIn" to Kind.DURATION,
            "fadeOut" to Kind.DURATION,
            "easing" to Kind.EASING,
            "spring" to Kind.SPRING,
            "pillSpring" to Kind.SPRING,
            "iconSpring" to Kind.SPRING,
            "releaseSpring" to Kind.SPRING,
            "ringSpring" to Kind.SPRING,
            "settleSpring" to Kind.SPRING,
            "sizeSpring" to Kind.SPRING,
            "fadeSpring" to Kind.SPRING,
            "haptic" to Kind.HAPTIC,
            "radius" to Kind.RADIUS,
            "numberTransition" to Kind.STRING,
        )
    }
}
