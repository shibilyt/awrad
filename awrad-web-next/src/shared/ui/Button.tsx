import type { ReactElement } from "react";
import { Button as AriaButton, type ButtonProps } from "react-aria-components";

type Props = ButtonProps & { className?: string };

/**
 * The primary call to action. React Aria handles focus, keyboard, press,
 * pending state and RTL; this component only styles it.
 */
export function PrimaryButton({ className, ...props }: Props): ReactElement {
  return (
    <AriaButton
      {...props}
      className={[
        "min-h-14 w-full rounded-2xl bg-primary px-6 font-semibold text-on-primary",
        "focus-ring data-pressed:opacity-90 disabled:opacity-50 data-pending:opacity-70",
        className ?? "",
      ].join(" ")}
    />
  );
}

/** A secondary action: outlined, same size and behaviour as `PrimaryButton`. */
export function SecondaryButton({ className, ...props }: Props): ReactElement {
  return (
    <AriaButton
      {...props}
      className={[
        "min-h-12 w-full rounded-2xl border border-outline-strong px-6 font-semibold text-accent",
        "focus-ring data-pressed:bg-primary-container data-pressed:text-on-primary-container",
        "disabled:opacity-50 data-pending:opacity-70",
        className ?? "",
      ].join(" ")}
    />
  );
}

/** A small outlined action inside a list row (sign out one device). */
export function InlineButton({ className, ...props }: Props): ReactElement {
  return (
    <AriaButton
      {...props}
      className={[
        "min-h-11 shrink-0 rounded-xl border border-outline-strong px-4 text-sm font-semibold text-accent",
        "focus-ring data-pressed:bg-primary-container data-pressed:text-on-primary-container",
        "disabled:opacity-50 data-pending:opacity-70",
        className ?? "",
      ].join(" ")}
    />
  );
}

/** An action that ends or deletes something: outlined in the error colour (filled while pressed), so it never looks like the default. */
export function DangerButton({ className, ...props }: Props): ReactElement {
  return (
    <AriaButton
      {...props}
      className={[
        "min-h-12 w-full rounded-2xl border-2 border-error px-6 font-semibold text-error",
        "focus-ring data-pressed:bg-error data-pressed:text-on-error disabled:opacity-50 data-pending:opacity-70",
        className ?? "",
      ].join(" ")}
    />
  );
}
