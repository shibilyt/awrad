import type { ReactElement } from "react";
import {
  FieldError,
  Input,
  Label,
  Text,
  TextField as AriaTextField,
  type TextFieldProps as AriaTextFieldProps,
} from "react-aria-components";
import { useFill } from "./Surface";

export interface TextFieldProps extends Omit<AriaTextFieldProps, "children" | "className"> {
  label: string;
  /** Help shown under the field and linked to it with `aria-describedby`. */
  description?: string | undefined;
  inputMode?: "text" | "email" | "numeric";
  autoCapitalize?: "none" | "sentences";
}

/**
 * A labelled text input. React Aria links the label, the description and the
 * error message to the input; errors come from the enclosing `Form`'s
 * `validationErrors` (or `isInvalid`) and are announced with the field.
 *
 * Filled, never outlined (`useFill`). Keyboard focus shows the `accent` ring; a
 * click shows the caret only. A field in error gets an `error` border, always
 * with its message; the border is transparent otherwise, so the text doesn't
 * move when an error appears.
 */
export function TextField({ label, description, inputMode, autoCapitalize, ...props }: TextFieldProps): ReactElement {
  const fill = useFill();
  return (
    <AriaTextField {...props} className="flex flex-col gap-1.5 text-start">
      <Label className="text-sm font-medium text-on-surface">{label}</Label>
      <Input
        {...(inputMode === undefined ? {} : { inputMode })}
        {...(autoCapitalize === undefined ? {} : { autoCapitalize })}
        className={[
          "min-h-12 rounded-xl border border-transparent px-4 text-base text-on-surface",
          fill,
          "caret-accent placeholder:text-on-surface-variant",
          // Tailwind's outline-none also zeroes outline-2's style, so the ring names its style.
          "outline-none data-focus-visible:outline-solid data-focus-visible:outline-2",
          "data-focus-visible:outline-offset-2 data-focus-visible:outline-accent",
          "data-invalid:border-error",
        ].join(" ")}
      />
      {description !== undefined && (
        <Text slot="description" className="text-sm text-on-surface-variant">
          {description}
        </Text>
      )}
      <FieldError className="text-sm text-error" />
    </AriaTextField>
  );
}
