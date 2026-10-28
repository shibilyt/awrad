/**
 * After a save that failed on its fields, brings the first problem (in page order) into view and
 * focuses it, so the person lands on what to fix instead of the message by the Save button.
 * A problem is anything marked `data-invalid`: a field React Aria marks invalid, or a group or
 * reference card whose message is for it as a whole (no title in any language), which focuses its
 * first field. The jump is instant: motion is fades only.
 */
export function focusFirstError(form: HTMLFormElement | null): void {
  const first = form?.querySelector<HTMLElement>("[data-invalid]");
  if (first === null || first === undefined) return;
  const field = first.querySelector<HTMLElement>("input:not([type=hidden]), textarea") ?? first;
  first.scrollIntoView({ block: "center" });
  field.focus({ preventScroll: true });
}
