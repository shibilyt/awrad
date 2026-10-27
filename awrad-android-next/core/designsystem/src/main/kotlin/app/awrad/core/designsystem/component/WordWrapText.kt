package app.awrad.core.designsystem.component

import androidx.compose.foundation.layout.Column
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.text
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp

/**
 * [text] in at most [maxLines] lines that break only between words. Android breaks a word that's wider than the
 * line between its letters (a Malayalam title split before its last letter); here such a word keeps its own line
 * and ends in an ellipsis instead, and so does whatever doesn't fit in the last line. The lines are [width] wide,
 * known up front (a tile's text width) so the text keeps its intrinsic size. Screen readers get [text] whole.
 */
@Composable
internal fun WordWrapText(
    text: String,
    style: TextStyle,
    color: Color,
    maxLines: Int,
    width: Dp,
    modifier: Modifier = Modifier,
) {
    val measurer = rememberTextMeasurer()
    val widthPx = with(LocalDensity.current) { width.roundToPx() }
    val lines = remember(text, style, widthPx, measurer) { wordLines(text, style, widthPx, maxLines, measurer) }
    Column(modifier = modifier.clearAndSetSemantics { this.text = AnnotatedString(text) }) {
        lines.forEach { line ->
            Text(
                text = line,
                style = style,
                color = color,
                maxLines = 1,
                softWrap = false,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

/** Greedy word wrap into at most [maxLines]; the last line takes the rest (its overflow is ellipsized). */
private fun wordLines(text: String, style: TextStyle, width: Int, maxLines: Int, measurer: TextMeasurer): List<String> {
    val words = text.trim().split(WHITESPACE).filter { it.isNotEmpty() }
    val lines = mutableListOf<String>()
    var current = ""
    for (word in words) {
        val candidate = if (current.isEmpty()) word else "$current $word"
        val fits = measurer.measure(candidate, style, maxLines = 1, softWrap = false).size.width <= width
        when {
            current.isEmpty() || fits -> current = candidate
            else -> {
                lines += current
                current = word
            }
        }
    }
    if (current.isNotEmpty()) lines += current
    return if (lines.size <= maxLines) lines else lines.take(maxLines - 1) + lines.drop(maxLines - 1).joinToString(" ")
}

private val WHITESPACE = Regex("\\s+")
