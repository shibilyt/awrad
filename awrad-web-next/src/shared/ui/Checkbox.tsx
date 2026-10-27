import type { ReactElement } from "react";
import { CheckboxButton, CheckboxField, type CheckboxFieldProps } from "react-aria-components";

/** A labelled checkbox. React Aria keeps the native input, so forms and screen readers see a real checkbox. */
export function Checkbox({
  children,
  ...props
}: Omit<CheckboxFieldProps, "children" | "className"> & { children: string }): ReactElement {
  return (
    <CheckboxField {...props}>
      <CheckboxButton className="group flex min-h-11 items-center gap-3 text-on-surface">
        <span
          aria-hidden="true"
          className={[
            "flex size-5 shrink-0 items-center justify-center rounded border-2 border-outline-strong",
            "group-data-selected:border-accent group-data-selected:bg-primary",
            "group-data-focus-visible:outline-2 group-data-focus-visible:outline-offset-2 group-data-focus-visible:outline-accent",
          ].join(" ")}
        >
          <svg
            viewBox="0 0 16 16"
            className="hidden size-3.5 fill-none stroke-on-primary stroke-2 group-data-selected:block"
          >
            <polyline points="3,8.5 6.5,12 13,4.5" />
          </svg>
        </span>
        {children}
      </CheckboxButton>
    </CheckboxField>
  );
}
