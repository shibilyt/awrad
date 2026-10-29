/**
 * The router fades pages with view transitions (`defaultViewTransition` in router.ts) and
 * awaits only `updateCallbackDone`. The browser aborts a transition when the document isn't
 * visible yet (the first navigation of a page load, a background tab) or when another
 * transition starts, and then rejects `ready` (and sometimes `finished`) with an
 * `InvalidStateError` that nothing handles. An aborted transition just means the page swaps
 * without the fade, so the rejections are swallowed here.
 */

const guarded = new WeakSet<object>();

function ignore(): void {
  /* An aborted transition only loses its fade. */
}

/** Wraps `doc.startViewTransition` so an aborted transition never causes an unhandled rejection. Safe to call twice. */
export function guardViewTransitions(doc: Document = document): void {
  if (typeof doc.startViewTransition !== "function") return;
  const current: unknown = Reflect.get(doc, "startViewTransition");
  if (typeof current === "function" && guarded.has(current)) return;
  const original = doc.startViewTransition.bind(doc);
  const wrapped = (...args: Parameters<Document["startViewTransition"]>): ViewTransition => {
    const started = original(...args);
    started.ready.catch(ignore);
    started.finished.catch(ignore);
    return started;
  };
  guarded.add(wrapped);
  doc.startViewTransition = wrapped;
}
