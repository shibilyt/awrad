import type { ReactElement, ReactNode } from "react";
import { cx } from "./cx";

/**
 * The icons the key components use, as small inline SVGs drawn for Awrad (no icon library).
 * Filled shapes in `currentColor`, on a 24 grid, decorative (`aria-hidden`): the control
 * that holds an icon carries the label. `icon` is the `icon` size (24), `small` `iconSmall` (20).
 */
export interface IconProps {
  size?: "icon" | "small";
}

export type Icon = (props: IconProps) => ReactElement;

function Svg({
  size = "icon",
  mirrored = false,
  children,
}: IconProps & { mirrored?: boolean; children: ReactNode }): ReactElement {
  return (
    <svg
      viewBox="0 0 24 24"
      aria-hidden="true"
      focusable="false"
      fill="currentColor"
      className={cx("shrink-0", size === "icon" ? "size-icon" : "size-icon-small", mirrored && "rtl:-scale-x-100")}
    >
      {children}
    </svg>
  );
}

/** Back: points to the start, so it flips in right-to-left layouts. */
export function BackIcon(props: IconProps): ReactElement {
  return (
    <Svg {...props} mirrored>
      <polygon points="15.6,4.6 17,6 11,12 17,18 15.6,19.4 8.2,12" />
    </Svg>
  );
}

/** Forward arrow (a collection tile's round button): points to the end, flipped in RTL. */
export function ArrowIcon(props: IconProps): ReactElement {
  return (
    <Svg {...props} mirrored>
      <polygon points="4,11 15.2,11 10.6,6.4 12,5 19,12 12,19 10.6,17.6 15.2,13 4,13" />
    </Svg>
  );
}

export function PlusIcon(props: IconProps): ReactElement {
  return (
    <Svg {...props}>
      <polygon points="11,5 13,5 13,11 19,11 19,13 13,13 13,19 11,19 11,13 5,13 5,11 11,11" />
    </Svg>
  );
}

/** The three-dot menu. */
export function MoreIcon(props: IconProps): ReactElement {
  return (
    <Svg {...props}>
      <circle cx="12" cy="5" r="2" />
      <circle cx="12" cy="12" r="2" />
      <circle cx="12" cy="19" r="2" />
    </Svg>
  );
}

export function CheckIcon(props: IconProps): ReactElement {
  return (
    <Svg {...props}>
      <polygon points="9.5,15.6 5.4,11.5 4,12.9 9.5,18.4 20,7.9 18.6,6.5" />
    </Svg>
  );
}

export function BellIcon(props: IconProps): ReactElement {
  return (
    <Svg {...props}>
      <path d="M12 2.5a1.5 1.5 0 0 1 1.5 1.5v.7c2.9.7 4.5 3.2 4.5 6.3v5l2 2v1H4v-1l2-2v-5c0-3.1 1.6-5.6 4.5-6.3V4A1.5 1.5 0 0 1 12 2.5Zm2 18a2 2 0 0 1-4 0Z" />
    </Svg>
  );
}

export function HomeIcon(props: IconProps): ReactElement {
  return (
    <Svg {...props}>
      <path d="M12 3l9 7.5V21h-6v-6H9v6H3V10.5Z" />
    </Svg>
  );
}

/** Goals: a target. */
export function GoalsIcon(props: IconProps): ReactElement {
  return (
    <Svg {...props}>
      <path
        fillRule="evenodd"
        d="M12 3a9 9 0 1 1 0 18a9 9 0 1 1 0-18Zm0 3a6 6 0 1 0 0 12a6 6 0 1 0 0-12Zm0 3a3 3 0 1 1 0 6a3 3 0 1 1 0-6Z"
      />
    </Svg>
  );
}

/** Library: a book. */
export function LibraryIcon(props: IconProps): ReactElement {
  return (
    <Svg {...props}>
      <path
        fillRule="evenodd"
        d="M6 2.5h12a2 2 0 0 1 2 2v15a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2v-15a2 2 0 0 1 2-2Zm3 4v2h7v-2Z"
      />
    </Svg>
  );
}

/** Community: two people. */
export function CommunityIcon(props: IconProps): ReactElement {
  return (
    <Svg {...props}>
      <circle cx="9" cy="7.5" r="3.5" />
      <path d="M2.5 19.5c0-3.2 2.9-5.5 6.5-5.5s6.5 2.3 6.5 5.5v1h-13Z" />
      <circle cx="16.5" cy="8" r="3" />
      <path d="M16.6 14.1c2.9.3 4.9 2.3 4.9 5.4v1h-4v-1c0-2-.7-3.7-2-4.9a7 7 0 0 1 1.1-.5Z" />
    </Svg>
  );
}
