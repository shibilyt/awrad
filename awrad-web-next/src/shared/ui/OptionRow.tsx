import { createContext, useContext, type ReactElement, type ReactNode } from "react";
import {
  CheckboxButton,
  CheckboxField,
  CheckboxGroup,
  RadioButton,
  RadioField,
  RadioGroup,
  type CheckboxGroupProps,
  type RadioGroupProps,
} from "react-aria-components";
import { cx } from "./cx";
import { CheckIcon } from "./icons.gen";
import { useSecondaryFill } from "./Surface";

type Mode = "single" | "multiple";
const ModeContext = createContext<Mode>("single");

type GroupProps<P> = Omit<P, "children" | "className" | "style" | "orientation"> & {
  /** Names the group for screen readers; the screen's own heading usually shows it. */
  "aria-label": string;
  children: ReactNode;
};

const GROUP = "flex flex-col gap-row-gap";

/** One choice from a list of option rows (language): a React Aria radio group. */
export function OptionRadioGroup({ children, ...props }: GroupProps<RadioGroupProps>): ReactElement {
  return (
    <RadioGroup {...props} className={GROUP}>
      <ModeContext value="single">{children}</ModeContext>
    </RadioGroup>
  );
}

/** Any number of choices from a list of option rows: a React Aria checkbox group. */
export function OptionCheckboxGroup({ children, ...props }: GroupProps<CheckboxGroupProps>): ReactElement {
  return (
    <CheckboxGroup {...props} className={GROUP}>
      <ModeContext value="multiple">{children}</ModeContext>
    </CheckboxGroup>
  );
}

const ROW = cx(
  "flex min-h-list-row cursor-default items-center gap-md rounded-tile px-md select-fade",
  "data-selected:bg-primary data-selected:text-on-primary-variant",
  "data-focus-visible:outline-focus-ring data-focus-visible:outline-offset-focus-ring data-focus-visible:outline-accent",
  "data-pressed:opacity-90 data-disabled:opacity-disabled",
);

/**
 * A selectable row (components.md "Option row"), announced as a radio or a checkbox by the
 * group around it. Unselected `secondaryContainer` (`useSecondaryFill`); selected `primary` with an
 * `onPrimaryVariant` label and a check in a circle. Colours cross-fade (`select`).
 */
export function OptionRow({
  value,
  label,
  avatar,
  isDisabled = false,
}: {
  value: string;
  label: string;
  /** Short text in the leading circle ("Aa"); decorative, the label names the row. */
  avatar?: string;
  isDisabled?: boolean;
}): ReactElement {
  const mode = useContext(ModeContext);
  const fill = useSecondaryFill();
  const content = ({ isSelected }: { isSelected: boolean }): ReactElement => (
    <>
      {avatar !== undefined && (
        <span
          aria-hidden="true"
          className={cx(
            "flex size-avatar shrink-0 items-center justify-center rounded-full text-label select-fade",
            isSelected ? "bg-on-primary-variant text-primary" : "bg-background text-on-surface",
          )}
        >
          {avatar}
        </span>
      )}
      <span className="min-w-0 flex-1 text-row-title">{label}</span>
      <span
        aria-hidden="true"
        className={cx(
          "flex size-icon shrink-0 items-center justify-center rounded-full bg-on-primary text-primary select-fade",
          !isSelected && "opacity-0",
        )}
      >
        <CheckIcon size="small" />
      </span>
    </>
  );
  return mode === "single" ? (
    <RadioField value={value} isDisabled={isDisabled}>
      <RadioButton className={cx(ROW, fill)}>{content}</RadioButton>
    </RadioField>
  ) : (
    <CheckboxField value={value} isDisabled={isDisabled}>
      <CheckboxButton className={cx(ROW, fill)}>{content}</CheckboxButton>
    </CheckboxField>
  );
}
