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
 * Filled, never outlined (`useFill`), `control` high, typed text in the `input`
 * style. Keyboard focus shows the `accent` ring; a click shows the caret only. A
 * field in error gets an `error` border (the `fieldError` stroke), always with its
 * message; the border is transparent otherwise, so the text doesn't move when an
 * error appears.
 */
export function TextField({ label, description, inputMode, autoCapitalize, ...props }: TextFieldProps): ReactElement {
  const fill = useFill();
  return (
    <AriaTextField {...props} className="flex flex-col gap-xs text-start">
      <Label className="text-label text-on-surface">{label}</Label>
      <Input
        {...(inputMode === undefined ? {} : { inputMode })}
        {...(autoCapitalize === undefined ? {} : { autoCapitalize })}
        className={[
          "min-h-control rounded-field border-field-error border-transparent px-lg text-input text-on-surface",
          fill,
          "caret-accent placeholder:text-on-surface-variant",
          "outline-none data-focus-visible:outline-focus-ring data-focus-visible:outline-offset-focus-ring",
          "data-focus-visible:outline-accent",
          "data-invalid:border-error",
        ].join(" ")}
      />
      {description !== undefined && (
        <Text slot="description" className="text-body-small text-on-surface-variant">
          {description}
        </Text>
      )}
      <FieldError className="text-body-small text-error" />
    </AriaTextField>
  );
}
