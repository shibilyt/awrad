import type { FieldCode, FieldProblem } from "@/shared/sync";
import { day } from "./days";
import { structureProblems } from "./documentStructure";
import type { GoalDocument, Version } from "./types";
import { goalErrors, sessionId, structureOf } from "./validity";
import { sameJson, settingsOf } from "./versions";

/**
 * Which goal documents are valid (contracts/sync/v1/fixtures/goal_document_validity.json): the
 * structure first, then, for a structurally valid document, the goal rules as field errors on the
 * version and session they're in (sync/v1 README "Goal rules as field errors"). Pointers are into
 * the document, sorted by field, then code, like a `rejected` receipt's without `/document`.
 */

function compare(a: FieldProblem, b: FieldProblem): number {
  if (a.field !== b.field) return a.field < b.field ? -1 : 1;
  if (a.code === b.code) return 0;
  return a.code < b.code ? -1 : 1;
}

function versionProblems(
  document: GoalDocument,
  version: Version,
  at: string,
  add: (field: string, code: FieldCode) => void,
): void {
  const errors = new Set(goalErrors({ ...settingsOf(version), paused: document.paused, excused: document.excused }));
  const policy = version.count_policy;
  if (errors.has("target_required")) add(`${at}/count_policy/target`, "required");
  if (errors.has("streak_threshold_value_required") || errors.has("streak_pace_not_allowed")) {
    add(`${at}/count_policy/streak_threshold`, "invalid");
  }
  if (errors.has("end_date_and_duration")) add(`${at}/active_period/duration_days`, "not_allowed");
  if (errors.has("make_up_not_allowed")) add(`${at}/make_up/window`, "not_allowed");
  if (errors.has("sessions_with_minimum_or_cap")) {
    if (policy.minimum !== null) add(`${at}/count_policy/minimum`, "not_allowed");
    if (policy.maximum !== null) add(`${at}/count_policy/maximum`, "not_allowed");
  }
  const tracker = version.requirement.type === "tracker";
  const seen = new Set<string>();
  version.sessions.forEach((session, m) => {
    const sessionAt = `${at}/sessions/${String(m)}`;
    if (!tracker && session.target === null) add(`${sessionAt}/target`, "required");
    if (session.id !== sessionId(session)) add(`${sessionAt}/id`, "mismatch");
    if (seen.has(session.id)) add(`${sessionAt}/id`, "duplicate");
    seen.add(session.id);
    if (session.kind === "between" && session.from === session.to) add(`${sessionAt}/to`, "range");
  });
}

/** A structurally valid document's goal-rule errors, sorted. */
export function goalRuleProblems(document: GoalDocument): FieldProblem[] {
  const problems: FieldProblem[] = [];
  const add = (field: string, code: FieldCode) => {
    if (!problems.some((p) => p.field === field && p.code === code)) problems.push({ field, code });
  };
  const { versions } = document;
  versions.forEach((version, n) => {
    versionProblems(document, version, `/versions/${String(n)}`, add);
  });
  const [first] = versions;
  versions.forEach((version, n) => {
    const previous = versions[n - 1];
    if (first === undefined || previous === undefined) return;
    if (!sameJson(structureOf(version), structureOf(first))) add(`/versions/${String(n)}`, "mismatch");
    if (day(version.from) <= day(previous.from)) add(`/versions/${String(n)}/from`, "range");
  });
  if (first?.from !== document.created_on) add("/versions/0/from", "mismatch");
  return problems.sort(compare);
}

/** Every problem with a goal document, sorted; empty when it's valid. Structure first, then the goal rules. */
export function goalDocumentProblems(document: unknown): FieldProblem[] {
  const structure = structureProblems(document);
  if (structure.length > 0) return structure.sort(compare);
  return goalRuleProblems(document as GoalDocument);
}
