import type { ReactElement } from "react";
import { Button as AriaButton, type ButtonProps } from "react-aria-components";
import { useFill } from "./Surface";

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
        "min-h-touch-target w-full rounded-button bg-primary px-2xl text-button text-on-primary",
        "focus-ring data-pressed:opacity-90 disabled:opacity-50 data-pending:opacity-70",
        className ?? "",
      ].join(" ")}
    />
  );
}

/** A secondary action: filled like a field (`useFill`), never outlined; same behaviour as `PrimaryButton`. */
export function SecondaryButton({ className, ...props }: Props): ReactElement {
  const fill = useFill();
  return (
    <AriaButton
      {...props}
      className={[
        "min-h-touch-target w-full rounded-button px-2xl text-button text-accent",
        fill,
        "focus-ring data-pressed:bg-primary-container data-pressed:text-on-primary-container",
        "disabled:opacity-50 data-pending:opacity-70",
        className ?? "",
      ].join(" ")}
    />
  );
}

/** A small filled action inside a list row (sign out one device). */
export function InlineButton({ className, ...props }: Props): ReactElement {
  const fill = useFill();
  return (
    <AriaButton
      {...props}
      className={[
        "min-h-touch-target shrink-0 rounded-button px-lg text-label text-accent",
        fill,
        "focus-ring data-pressed:bg-primary-container data-pressed:text-on-primary-container",
        "disabled:opacity-50 data-pending:opacity-70",
        className ?? "",
      ].join(" ")}
    />
  );
}

/**
 * An action that ends or deletes something: filled like a secondary button but
 * in `error` text (an `error` fill while pressed), so it never looks like the default.
 */
export function DangerButton({ className, ...props }: Props): ReactElement {
  const fill = useFill();
  return (
    <AriaButton
      {...props}
      className={[
        "min-h-touch-target w-full rounded-button px-2xl text-button text-error",
        fill,
        "focus-ring data-pressed:bg-error data-pressed:text-on-error disabled:opacity-50 data-pending:opacity-70",
        className ?? "",
      ].join(" ")}
    />
  );
}
