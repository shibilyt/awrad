import type { ReactElement, ReactNode } from "react";
import { Button as AriaButton, ProgressBar, type ButtonProps as AriaButtonProps } from "react-aria-components";
import { useTranslation } from "react-i18next";
import { cx } from "./cx";
import type { Icon } from "./icons";
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

/** Three dots that fade in turn, in the content colour. Fades only, still with reduced motion. */
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

/** A link-like action (View All): no fill, `accent`, `label` style, `touchTarget` tall. */
export function TextButton({ children, ...props }: AriaProps & { children: ReactNode }): ReactElement {
  return (
    <AriaButton
      {...props}
      className={cx("inline-flex min-h-touch-target items-center rounded-xs text-label text-accent", STATES)}
    >
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
 * `small` (32, a collection tile's arrow) inside a 48 touch target.
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
          "flex size-round-button shrink-0 items-center justify-center rounded-round-button",
          "bg-primary text-on-primary",
          STATES,
        )}
      >
        <ButtonIcon size="icon" />
      </AriaButton>
    );
  }
  return (
    <AriaButton
      {...props}
      className={cx("flex size-touch-target shrink-0 items-center justify-center rounded-round-button", STATES)}
    >
      <span className="flex size-round-button-small items-center justify-center rounded-round-button bg-primary text-on-primary">
        <ButtonIcon size="small" />
      </span>
    </AriaButton>
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
