import type { ReactElement, ReactNode } from "react";
import { Button as AriaButton, ProgressBar, type ButtonProps as AriaButtonProps } from "react-aria-components";
import { useTranslation } from "react-i18next";
import { cx } from "./cx";
import type { Icon } from "./icons.gen";
import { nameFromText } from "./nameFromText";
import { useSecondaryFill } from "./Surface";

type AriaProps = Omit<AriaButtonProps, "children" | "className" | "style">;

/** Main (`primary`), secondary (`secondaryContainer`) or error (`error`, destructive confirmations). */
export type ButtonVariant = "main" | "secondary" | "error";

const VARIANTS: Record<Exclude<ButtonVariant, "secondary">, string> = {
  main: "bg-primary text-on-primary",
  error: "bg-error text-on-error",
};

/** Press, keyboard focus and disabled, the same on every button: a filled shape at 38% when disabled. */
const STATES = "focus-ring data-pressed:opacity-90 disabled:opacity-disabled";

export interface ButtonProps extends AriaProps {
  variant?: ButtonVariant;
  /** `control` (56, the default), or `row`: a button inside a list row, `touchTarget` (48) tall. */
  size?: "control" | "row";
  /** `fill` (the default for `control`) takes the width it's given; `label` is as wide as its label. */
  width?: "fill" | "label";
  /** A leading icon, `iconSmall`, `inlineGap` from the label. */
  icon?: Icon;
  children: ReactNode;
}

/**
 * The web's own progress indicator (components.md lets each platform use its own): three dots that
 * fade in turn, in the content colour. Fades only, still with reduced motion.
 */
function PendingIndicator(): ReactElement {
  const { t } = useTranslation();
  return (
    <ProgressBar
      isIndeterminate
      aria-label={t("ui.loading")}
      className="absolute inset-0 flex items-center justify-center gap-xs"
    >
      <span className="progress-pulse size-sm rounded-full bg-current" />
      <span className="progress-pulse size-sm rounded-full bg-current" />
      <span className="progress-pulse size-sm rounded-full bg-current" />
    </ProgressBar>
  );
}

/**
 * A button (components.md): main, secondary or error, `control` tall and filling its width, or
 * `row` sized. React Aria handles focus, keyboard, press, pending and RTL. While `isPending` the
 * label gives way to a progress indicator; the button keeps its size, ignores presses and isn't
 * drawn as disabled. Disabled, it keeps its colours at the `disabled` opacity.
 *
 * A text label also names the button (`aria-label`): the label sits in a wrapper span, which some
 * accessibility trees don't look into (a submit button showed up nameless), and while pending
 * React Aria then names it "label Loading".
 */
export function Button({
  variant = "main",
  size = "control",
  width = size === "row" ? "label" : "fill",
  icon: LeadingIcon,
  children,
  ...props
}: ButtonProps): ReactElement {
  const secondary = useSecondaryFill();
  return (
    <AriaButton
      {...(typeof children === "string" ? nameFromText(children, props) : {})}
      {...props}
      className={cx(
        "relative inline-flex items-center justify-center rounded-button text-button select-fade",
        size === "control" ? "min-h-control px-2xl" : "min-h-touch-target px-lg",
        width === "fill" ? "w-full" : "shrink-0",
        variant === "secondary" ? secondary : VARIANTS[variant],
        STATES,
      )}
    >
      {({ isPending }) => (
        <>
          <span className={cx("inline-flex items-center gap-inline-gap", isPending && "opacity-0")}>
            {LeadingIcon !== undefined && <LeadingIcon size="small" />}
            {children}
          </span>
          {isPending && <PendingIndicator />}
        </>
      )}
    </AriaButton>
  );
}

/**
 * What a text button sits on: no fill (`accent`), or a `secondaryContainer` or `primary` fill,
 * where it takes the fill's paired content colour (components.md "Buttons"; in dark mode `accent`
 * is the `secondaryContainer` colour, so it would vanish there).
 */
export type TextButtonOn = "none" | "secondaryContainer" | "primary";

const TEXT_BUTTON_COLORS: Record<TextButtonOn, string> = {
  none: "text-accent",
  secondaryContainer: "text-on-secondary-container",
  primary: "text-on-primary",
};

/** A text button's look, shared with `TextButtonLink` (a text button that navigates). */
export function textButtonClasses(on: TextButtonOn = "none"): string {
  return cx("inline-flex min-h-touch-target items-center rounded-xs text-label", TEXT_BUTTON_COLORS[on], STATES);
}

/**
 * A link-like action (View All): no fill, `accent`, `label` style, `touchTarget` tall. `on` names
 * the fill it sits on when that's `secondaryContainer` or `primary` (the conflict banner).
 */
export function TextButton({
  on = "none",
  children,
  ...props
}: AriaProps & { on?: TextButtonOn; children: ReactNode }): ReactElement {
  return (
    <AriaButton {...props} className={textButtonClasses(on)}>
      {children}
    </AriaButton>
  );
}

interface IconOnlyProps extends AriaProps {
  icon: Icon;
  /** Required: the button shows only an icon. */
  "aria-label": string;
}

/**
 * A round `primary` button with an `onPrimary` icon: `regular` (48, the + on My Goals) or
 * `small` (32, a collection tile's arrow) inside a 48 touch target. A regular one `isPending`
 * (audio loading) shows the progress indicator in place of its icon.
 */
export function RoundButton({
  icon: ButtonIcon,
  size = "regular",
  ...props
}: IconOnlyProps & { size?: "regular" | "small" }): ReactElement {
  if (size === "regular") {
    return (
      <AriaButton
        {...props}
        className={cx(
          "relative flex size-round-button shrink-0 items-center justify-center rounded-round-button",
          "bg-primary text-on-primary",
          STATES,
        )}
      >
        {({ isPending }) => (isPending ? <PendingIndicator /> : <ButtonIcon size="icon" />)}
      </AriaButton>
    );
  }
  return (
    <AriaButton
      {...props}
      className={cx("flex size-touch-target shrink-0 items-center justify-center rounded-round-button", STATES)}
    >
      <SmallRoundIcon icon={ButtonIcon} />
    </AriaButton>
  );
}

/**
 * The visible part of a small round button: a `roundButtonSmall` (32) `primary` circle with an
 * `onPrimary` `iconSmall`. For a press target bigger than the button, such as the arrow on a
 * collection tile, where the whole tile is the link.
 */
export function SmallRoundIcon({ icon: ButtonIcon }: { icon: Icon }): ReactElement {
  return (
    <span className="flex size-round-button-small shrink-0 items-center justify-center rounded-round-button bg-primary text-on-primary">
      <ButtonIcon size="small" />
    </span>
  );
}

/** An icon with no fill (back, the three-dot menu): `onSurface`, `icon` size, a 48 touch target. */
export function IconButton({ icon: ButtonIcon, ...props }: IconOnlyProps): ReactElement {
  return (
    <AriaButton
      {...props}
      className={cx("flex size-touch-target shrink-0 items-center justify-center rounded-full text-on-surface", STATES)}
    >
      <ButtonIcon size="icon" />
    </AriaButton>
  );
}
