import type { ReactElement } from "react";
import { Button as AriaButton, type ButtonProps } from "react-aria-components";

/**
 * The primary call to action. React Aria handles focus, keyboard, press and
 * RTL; this component only styles it.
 */
export function PrimaryButton({ className, ...props }: ButtonProps & { className?: string }): ReactElement {
  return (
    <AriaButton
      {...props}
      className={[
        "min-h-14 w-full rounded-2xl bg-primary px-6 font-semibold text-on-primary",
        "outline-none focus-visible:ring-4 focus-visible:ring-primary-container",
        "pressed:opacity-90 disabled:opacity-50",
        className ?? "",
      ].join(" ")}
    />
  );
}
