import { useEffect, useRef, useState, type ReactElement, type ReactNode } from "react";
import { TopBar } from "./TopBar";

/** The nearest ancestor that scrolls, or `null` for the page itself. */
function scrollParent(element: HTMLElement): HTMLElement | null {
  for (let parent = element.parentElement; parent !== null; parent = parent.parentElement) {
    if (/auto|scroll/.test(getComputedStyle(parent).overflowY)) return parent;
  }
  return null;
}

/**
 * The top of a main tab (components.md "Large-title header", My Goals): the page's `h1` in
 * `largeTitle` at the start and an optional round button at the end; the content sheet or
 * segmented pills follow `lg` below. It scrolls away with the content, and once the title has
 * scrolled out of view a compact top bar with the title in `title` style fades in at the top.
 * That copy is hidden from screen readers, which still have the `h1`.
 */
export function LargeTitleHeader({ title, action }: { title: string; action?: ReactNode }): ReactElement {
  const heading = useRef<HTMLHeadingElement>(null);
  const [compact, setCompact] = useState(false);

  useEffect(() => {
    const element = heading.current;
    if (element === null || typeof IntersectionObserver === "undefined") return;
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry === undefined) return;
        // Gone above the top, not merely below the fold.
        const top = entry.rootBounds?.top ?? 0;
        setCompact(!entry.isIntersecting && entry.boundingClientRect.bottom <= top);
      },
      { root: scrollParent(element) },
    );
    observer.observe(element);
    return () => {
      observer.disconnect();
    };
  }, []);

  return (
    <>
      <div className="flex items-center justify-between gap-lg px-page-margin pb-lg">
        <h1 ref={heading} className="min-w-0 text-large-title text-on-surface">
          {title}
        </h1>
        {action}
      </div>
      {compact && (
        <div aria-hidden="true" className="content-swap fixed inset-x-0 top-0 z-10 bg-background">
          <TopBar title={<span className="truncate">{title}</span>} />
        </div>
      )}
    </>
  );
}
