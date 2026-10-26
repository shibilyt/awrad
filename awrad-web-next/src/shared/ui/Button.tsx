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
        "outline-none focus-visible:ring-4 focus-visible:ring-primary-container",
        "data-pressed:opacity-90 disabled:opacity-50 data-pending:opacity-70",
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
        "min-h-12 w-full rounded-2xl border border-outline-variant px-6 font-semibold text-primary",
        "outline-none focus-visible:ring-4 focus-visible:ring-primary-container",
        "data-pressed:bg-primary-container disabled:opacity-50 data-pending:opacity-70",
        className ?? "",
      ].join(" ")}
    />
  );
}
