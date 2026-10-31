package app.awrad.core.domain.goal

import app.awrad.core.domain.sync.FieldError
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.time.LocalDate

/**
 * Which goal documents are valid (fixture `goal_document_validity`; contracts/sync/v1/README.md, "Goal documents").
 * Structure first: the document must match `$defs/goal_document` ([goalDocumentStructureErrors]). Only a structurally
 * valid document is checked against the goal rules, each error at the version and session it's in. Errors are
 * `{field, code}`, the field a JSON Pointer into the document, sorted by field and then code. The phone checks before
 * saving; the server checks every put (with `/document` in front).
 */
public object GoalDocumentValidity {

    /** Every problem with [document]; empty when it's valid. */
    public fun errors(document: JsonObject): List<FieldError> {
        val errors = goalDocumentStructureErrors(document).ifEmpty {
            val versions = checkNotNull(GoalJson.decodeVersions(document.getValue("versions") as JsonArray))
            timelineFieldErrors(LocalDate.parse(document.getValue("created_on").jsonPrimitive.content), versions)
        }
        return errors.distinct().sortedWith(compareBy({ it.field }, { it.code.wire }))
    }

    /** Whether [document] is a valid goal document. */
    public fun isValid(document: JsonObject): Boolean = errors(document).isEmpty()
}
