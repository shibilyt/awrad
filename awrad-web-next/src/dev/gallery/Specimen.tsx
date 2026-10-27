import type { ReactElement, ReactNode } from "react";

/** A part of the gallery (containers, buttons, inputs, navigation). */
export function GallerySection({ title, children }: { title: string; children: ReactNode }): ReactElement {
  return (
    <section className="flex flex-col gap-section-gap">
      <h2 className="text-title text-on-surface">{title}</h2>
      {children}
    </section>
  );
}

/** One component in its states, under a caption naming them. */
export function Specimen({ title, children }: { title: string; children: ReactNode }): ReactElement {
  return (
    <div className="flex flex-col gap-sm">
      <h3 className="text-caption text-on-surface-variant">{title}</h3>
      {children}
    </div>
  );
}

/** Specimens side by side, wrapping on narrow screens. */
export function Row({ children }: { children: ReactNode }): ReactElement {
  return <div className="flex flex-wrap items-center gap-lg">{children}</div>;
}

/** Does nothing: a press handler for buttons that only show their states. */
export function noop(): void {
  // The gallery only shows states.
}
