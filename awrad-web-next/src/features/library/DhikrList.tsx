import { createLink } from "@tanstack/react-router";
import type { AnchorHTMLAttributes, ReactElement, Ref } from "react";
import type { Dhikr } from "@/shared/dhikr-catalog";
import { useLanguage } from "@/shared/i18n";
import { cx } from "@/shared/ui/cx";
import { ChevronIcon } from "@/shared/ui/icons.gen";
import { useFill } from "@/shared/ui/Surface";

interface RowProps extends AnchorHTMLAttributes<HTMLAnchorElement> {
  ref?: Ref<HTMLAnchorElement>;
  heading: string;
  arabic: string;
}

function RowAnchor({ ref, heading, arabic, className, ...props }: RowProps): ReactElement {
  const fill = useFill();
  return (
    <a
      ref={ref}
      {...props}
      className={cx(
        "flex min-h-list-row items-center gap-md rounded-tile ps-lg pe-md py-sm",
        fill,
        "focus-ring active:opacity-90",
        className,
      )}
    >
      {/* The title sits at the row's start; the Arabic spans the row, aligned right in every language. */}
      <span className="flex min-w-0 flex-1 flex-col items-start">
        <span className="max-w-full truncate text-row-title text-on-surface">{heading}</span>
        <span lang="ar" dir="rtl" className="self-stretch truncate text-right text-quran-line text-on-surface-variant">
          {arabic}
        </span>
      </span>
      <span className="text-on-surface-variant">
        <ChevronIcon />
      </span>
    </a>
  );
}

const RowLink = createLink(RowAnchor);

/**
 * A dhikr in a list: its title in `rowTitle`, the start of its Arabic on one line in `quranLine`
 * (right to left and aligned right in every language, cut off with an ellipsis), and a trailing chevron (mirrored in right-to-left
 * layouts). The row is one link to the dhikr; `tile` corners, filled like a card.
 */
export function DhikrRow({ dhikr }: { dhikr: Dhikr }): ReactElement {
  const language = useLanguage();
  return (
    <RowLink
      to="/library/dhikrs/$key"
      params={{ key: dhikr.key }}
      heading={dhikr.title[language]}
      arabic={dhikr.arabic}
    />
  );
}

/** Dhikr rows, `sm` apart, inside the page margin. */
export function DhikrList({ dhikrs, label }: { dhikrs: readonly Dhikr[]; label: string }): ReactElement {
  return (
    <ul aria-label={label} className="flex flex-col gap-sm px-page-margin">
      {dhikrs.map((dhikr) => (
        <li key={dhikr.key}>
          <DhikrRow dhikr={dhikr} />
        </li>
      ))}
    </ul>
  );
}
