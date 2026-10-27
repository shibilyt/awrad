import type { ReactElement } from "react";
import {
  CheckboxButton,
  CheckboxField,
  SwitchButton,
  SwitchField,
  type CheckboxFieldProps,
  type SwitchFieldProps,
} from "react-aria-components";
import { cx } from "./cx";
import { CheckIcon } from "./icons.gen";

const FOCUS =
  "group-data-focus-visible:outline-focus-ring group-data-focus-visible:outline-offset-focus-ring group-data-focus-visible:outline-accent";

/**
 * A labelled checkbox (components.md). React Aria keeps the native input, so forms and screen
 * readers see a real checkbox. The box is `checkbox` (20) in a 48 touch target: the `checkbox`
 * stroke in `outlineStrong`, then a `primary` fill with an `onPrimary` `check` icon (`iconSmall`) when ticked; the label
 * in `body`, `md` after it. Colours and the tick cross-fade (`select`).
 */
export function Checkbox({
  children,
  ...props
}: Omit<CheckboxFieldProps, "children" | "className"> & { children: string }): ReactElement {
  return (
    <CheckboxField {...props}>
      <CheckboxButton className="group flex min-h-touch-target items-center gap-md text-body text-on-surface data-disabled:opacity-disabled">
        <span
          aria-hidden="true"
          className={cx(
            "flex size-checkbox shrink-0 items-center justify-center rounded-checkbox select-fade",
            "border-checkbox border-outline-strong group-data-selected:border-primary group-data-selected:bg-primary",
            FOCUS,
          )}
        >
          <span className="flex text-on-primary opacity-0 select-fade group-data-selected:opacity-100">
            <CheckIcon size="small" />
          </span>
        </span>
        {children}
      </CheckboxButton>
    </CheckboxField>
  );
}

/**
 * An on/off switch (components.md), its label at the start. The track is `switchWidth` ×
 * `switchHeight`, fully rounded: `outline` with a `background` thumb when off, `primary` with an
 * `onPrimary` thumb when on. Web motion is fades only, so the thumb doesn't slide: the off and
 * on thumbs cross-fade with the track colour (`select`).
 */
export function Switch({
  children,
  ...props
}: Omit<SwitchFieldProps, "children" | "className" | "style"> & { children: string }): ReactElement {
  return (
    <SwitchField {...props}>
      <SwitchButton className="group flex min-h-touch-target items-center justify-between gap-md text-body text-on-surface data-disabled:opacity-disabled">
        <span className="min-w-0">{children}</span>
        <span
          aria-hidden="true"
          className={cx(
            "relative h-switch-height w-switch-width shrink-0 rounded-full bg-outline select-fade",
            "group-data-selected:bg-primary",
            FOCUS,
          )}
        >
          <span className="absolute start-xs top-xs size-switch-thumb rounded-full bg-background select-fade group-data-selected:opacity-0" />
          <span className="absolute end-xs top-xs size-switch-thumb rounded-full bg-on-primary opacity-0 select-fade group-data-selected:opacity-100" />
        </span>
      </SwitchButton>
    </SwitchField>
  );
}
