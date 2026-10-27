import { createLink } from "@tanstack/react-router";
import type { AnchorHTMLAttributes, ReactElement, Ref } from "react";
import { SmallRoundIcon } from "./Button";
import { cx } from "./cx";
import { ForwardIcon } from "./icons.gen";
import { useFill } from "./Surface";

interface TileProps extends AnchorHTMLAttributes<HTMLAnchorElement> {
  ref?: Ref<HTMLAnchorElement>;
  /** The collection's title, in `rowTitle`: up to two lines, wrapping between words, then an ellipsis. */
  heading: string;
  /** How many it holds ("4 dhikrs"), in `caption`. */
  count: string;
}

function TileAnchor({ ref, heading, count, className, ...props }: TileProps): ReactElement {
  const fill = useFill();
  return (
    <a
      ref={ref}
      {...props}
      className={cx(
        "flex size-collection-tile shrink-0 flex-col justify-between rounded-tile p-md text-start",
        fill,
        "focus-ring active:opacity-90",
        className,
      )}
    >
      <span className="flex min-w-0 flex-col gap-xxs">
        <span className="line-clamp-2 text-ellipsis text-row-title text-on-surface">{heading}</span>{" "}
        <span className="truncate text-caption text-on-surface-variant">{count}</span>
      </span>
      <span className="self-end">
        <SmallRoundIcon icon={ForwardIcon} />
      </span>
    </a>
  );
}

/**
 * A collection on Home and the Library: a `collectionTile` (128) square, `surface` on the page
 * (`useFill`), `tile` corners, the title over its count in `caption`, and a small round
 * `forward` arrow at the end (it flips in right-to-left layouts). The whole tile is one link to
 * the collection, so the arrow is drawn, not a separate button; the link's name is the title and
 * the count (a space between them, so they don't run together). Pressed, it dims like a card.
 */
export const CollectionTile = createLink(TileAnchor);
