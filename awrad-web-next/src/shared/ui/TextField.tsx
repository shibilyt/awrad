import type { ReactElement } from "react";
import {
  FieldError,
  Input,
  Label,
  Text,
  TextField as AriaTextField,
  type TextFieldProps as AriaTextFieldProps,
} from "react-aria-components";

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
 */
export function TextField({ label, description, inputMode, autoCapitalize, ...props }: TextFieldProps): ReactElement {
  return (
    <AriaTextField {...props} className="flex flex-col gap-1.5 text-start">
      <Label className="text-sm font-medium text-on-surface">{label}</Label>
      <Input
        {...(inputMode === undefined ? {} : { inputMode })}
        {...(autoCapitalize === undefined ? {} : { autoCapitalize })}
        className={[
          "min-h-12 rounded-xl border border-outline-variant bg-surface px-4 text-base text-on-surface",
          "outline-none focus-visible:border-primary focus-visible:ring-2 focus-visible:ring-primary-container",
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
