import { useEffect, useRef, type RefObject } from "react";

/**
 * After a save that failed on its fields, brings the first problem (in page order) into view and
 * focuses it, so the person lands on what to fix instead of the message by the Save button.
 * A problem is anything marked `data-invalid`: a field React Aria marks invalid, or a group or
 * reference card whose message is for it as a whole (no title in any language), which focuses its
 * first field, or its first button when it has no field (the recording: Replace). The jump is
 * instant: motion is fades only.
 */
export function focusFirstError(form: HTMLFormElement | null): void {
  const first = form?.querySelector<HTMLElement>("[data-invalid]");
  if (first === null || first === undefined) return;
  const field =
    first.querySelector<HTMLElement>("input:not([type=hidden]):not([type=file]), textarea") ??
    first.querySelector<HTMLElement>("button") ??
    first;
  first.scrollIntoView({ block: "center" });
  field.focus({ preventScroll: true });
}

/**
 * The form's ref, and the jump: each save that stopped on field problems (`fieldFailures` counts
 * them) lands on the first of them once they're drawn; when the server refused it, once "Change
 * refused" has closed (`isRefused` false again: focus can't leave a modal).
 */
export function useFocusFirstError(fieldFailures: number, isRefused: boolean): RefObject<HTMLFormElement | null> {
  const form = useRef<HTMLFormElement>(null);
  useEffect(() => {
    if (fieldFailures > 0 && !isRefused) focusFirstError(form.current);
  }, [fieldFailures, isRefused]);
  return form;
}
