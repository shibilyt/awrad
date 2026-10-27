import type { ReactElement, ReactNode } from "react";
import { Button as AriaButton, type ButtonProps as AriaButtonProps } from "react-aria-components";
import { cx } from "./cx";
import { Inside, OnSurface, useFill } from "./Surface";

/** `card` (24) for grouped content, `tile` (16) for a list item's card. */
export type CardShape = "card" | "tile";

const SHAPES: Record<CardShape, string> = { card: "rounded-card", tile: "rounded-tile" };

interface CardLayout {
  shape?: CardShape;
  /**
   * `cardPadding` inside and rows `rowGap` apart (the default). `false` for a list
   * whose rows carry their own padding (account settings links, devices).
   */
  padded?: boolean;
}

function cardClasses(fill: string, shape: CardShape = "card", padded = true): string {
  return cx("flex flex-col", SHAPES[shape], fill, padded && "gap-row-gap p-card-padding");
}

/**
 * Grouped content or a list item: `surface` on the page, `background` inside a
 * `surface` area (the content sheet). Rows inside are spaced, never divided by lines.
 */
export function Card({ shape, padded, children }: CardLayout & { children: ReactNode }): ReactElement {
  const fill = useFill();
  return (
    <div className={cardClasses(fill, shape, padded)}>
      <Inside fill={fill}>{children}</Inside>
    </div>
  );
}

/**
 * A card that is one press target (a goal on My Goals). A React Aria button: keyboard,
 * focus ring and disabled state included. Its content can't hold other controls.
 */
export function ClickableCard({
  children,
  shape,
  padded,
  ...props
}: CardLayout & Omit<AriaButtonProps, "children" | "className" | "style"> & { children: ReactNode }): ReactElement {
  const fill = useFill();
  return (
    <AriaButton
      {...props}
      className={cx(
        cardClasses(fill, shape, padded),
        "w-full text-start text-on-surface",
        "focus-ring data-pressed:opacity-90 disabled:opacity-disabled",
      )}
    >
      <Inside fill={fill}>{children}</Inside>
    </AriaButton>
  );
}

/**
 * The area under a large-title header (My Goals): `surface`, top corners `contentSheet`,
 * filling the rest of the page. Cards inside fill with `background`.
 */
export function ContentSheet({ children }: { children: ReactNode }): ReactElement {
  return (
    <div className="flex grow flex-col gap-sm rounded-t-content-sheet bg-surface pb-page-margin">
      <OnSurface>{children}</OnSurface>
    </div>
  );
}

/** A titled section in the content sheet: the title in `sectionTitle`, padded by `pageMargin`. */
export function ContentSheetSection({ title, children }: { title: string; children: ReactNode }): ReactElement {
  return (
    <section className="flex flex-col gap-row-gap px-page-margin pt-page-margin">
      <h2 className="text-section-title text-on-surface">{title}</h2>
      {children}
    </section>
  );
}
