package app.awrad.feature.library

import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.key
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.error
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.KeyboardType
import app.awrad.core.designsystem.component.AwradTextButton
import app.awrad.core.designsystem.component.AwradTextField
import app.awrad.core.designsystem.icon.AwradIcons
import app.awrad.core.designsystem.theme.AwradTheme

/**
 * An optional Qur'an reference (surah and ayat), the references of other types the dhikr already had, then any
 * other references as free text. A problem with one reference shows on its own row (and field).
 */
@Composable
internal fun ReferencesSection(
    state: EditorUiState,
    onAction: (EditorAction) -> Unit,
    targets: ProblemTargets,
    modifier: Modifier = Modifier,
) {
    EditorSection(title = stringResource(R.string.library_references), modifier = modifier) {
        QuranReferenceFields(
            quran = state.quran,
            problems = state.problems,
            targets = targets,
            onChange = { onAction(EditorAction.QuranChanged(it)) },
        )
        state.kept.forEachIndexed { index, reference ->
            KeptReferenceRow(
                text = referenceLabel(reference).text,
                problem = state.problems[ProblemSpot.kept(index)],
                onRemove = { onAction(EditorAction.RemoveKeptReference(index)) },
                modifier = Modifier.problemSpot(targets, ProblemSpot.kept(index)),
            )
        }
        state.otherReferences.forEachIndexed { index, text ->
            key(index) {
                AwradTextField(
                    value = text,
                    onValueChange = { onAction(EditorAction.ReferenceChanged(index, it)) },
                    label = stringResource(R.string.editor_reference, index + 1),
                    modifier = Modifier.problemSpot(targets, ProblemSpot.other(index)),
                    error = state.problems[ProblemSpot.other(index)]?.let { problemText(it) },
                    trailingIcon = { RemoveButton(onClick = { onAction(EditorAction.RemoveReference(index)) }) },
                )
            }
        }
        AwradTextButton(
            text = stringResource(R.string.editor_add_reference),
            onClick = { onAction(EditorAction.AddReference) },
            leadingIcon = AwradIcons.Add,
        )
    }
}

/**
 * Surah, from ayah and to ayah (the same ayah when left empty), in a row of number fields; under them the
 * reference's problem, such as a range that ends before it starts. The field the problem is about carries it too,
 * so it's read out there, and a failed save focuses that field.
 */
@Composable
private fun QuranReferenceFields(
    quran: QuranFields,
    problems: Map<ProblemSpot, EditorProblem>,
    targets: ProblemTargets,
    onChange: (QuranFields) -> Unit,
    modifier: Modifier = Modifier,
) {
    val number = KeyboardOptions(keyboardType = KeyboardType.Number)
    val fields = listOf(EditorField.SURAH, EditorField.AYAH_START, EditorField.AYAH_END)
    val problem = fields.firstNotNullOfOrNull { problems[ProblemSpot(it)] }?.let { problemText(it) }
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(AwradTheme.spacing.xs)) {
        Row(horizontalArrangement = Arrangement.spacedBy(AwradTheme.spacing.sm)) {
            fields.forEach { field ->
                val spot = ProblemSpot(field)
                AwradTextField(
                    value = quran[field],
                    onValueChange = { onChange(quran.with(field, it)) },
                    label = stringResource(QURAN_LABELS.getValue(field)),
                    modifier = Modifier
                        .weight(1f)
                        .problemSpot(targets, spot)
                        .semantics { if (problem != null && spot in problems) error(problem) },
                    keyboardOptions = number,
                )
            }
        }
        if (problem != null) {
            Text(
                text = problem,
                style = AwradTheme.type.caption,
                color = AwradTheme.colors.error,
            )
        }
    }
}

private val QURAN_LABELS = mapOf(
    EditorField.SURAH to R.string.editor_surah,
    EditorField.AYAH_START to R.string.editor_ayah_start,
    EditorField.AYAH_END to R.string.editor_ayah_end,
)

private operator fun QuranFields.get(field: EditorField): String = when (field) {
    EditorField.AYAH_START -> ayahStart
    EditorField.AYAH_END -> ayahEnd
    else -> surah
}

private fun QuranFields.with(field: EditorField, text: String): QuranFields = when (field) {
    EditorField.AYAH_START -> copy(ayahStart = text)
    EditorField.AYAH_END -> copy(ayahEnd = text)
    else -> copy(surah = text)
}

/**
 * A reference of another type the dhikr already had, as it reads, with Remove. With a [problem] it's marked and
 * focusable, so a failed save can move focus (and a screen reader) to it.
 */
@Composable
private fun KeptReferenceRow(
    text: String,
    problem: EditorProblem?,
    onRemove: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val error = problem?.let { problemText(it) }
    val marked = if (error == null) {
        modifier
    } else {
        modifier.semantics(mergeDescendants = true) { error(error) }.focusable()
    }
    Column(
        modifier = marked,
        verticalArrangement = Arrangement.spacedBy(AwradTheme.spacing.xs),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = text,
                modifier = Modifier.weight(1f),
                style = AwradTheme.type.bodySmall,
                color = AwradTheme.colors.onSurfaceVariant,
            )
            RemoveButton(onClick = onRemove)
        }
        if (error != null) {
            Text(text = error, style = AwradTheme.type.caption, color = AwradTheme.colors.error)
        }
    }
}
