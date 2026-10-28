/**
 * Names a control by its visible text (`aria-label`) unless the caller already names it. Spread it
 * before the caller's props. The text usually sits in a wrapper span (or after the indicator in a
 * label), and some accessibility trees don't look inside: a checkbox then showed up as its value
 * ("true") and the bottom bar's tabs nameless.
 */
export function nameFromText(
  text: string,
  props: { "aria-label"?: string | undefined; "aria-labelledby"?: string | undefined },
): { "aria-label"?: string } {
  return props["aria-label"] !== undefined || props["aria-labelledby"] !== undefined ? {} : { "aria-label": text };
}
