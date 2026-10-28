import type { ReactElement } from "react";
import {
  FieldError,
  Input,
  Label,
  Text,
  TextArea,
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
  /** An example of what to type, in `onSurfaceVariant`; never a substitute for the label. */
  placeholder?: string;
  /** Several lines (Arabic text, a translation): a text area that starts `control` tall and grows with Enter. */
  multiline?: boolean;
  /** The language typed, when it isn't the page's (Arabic in an English page): sets `lang` and `dir`. */
  textLanguage?: "ar";
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
 * error appears. The message and the help text below are `caption`. Disabled, the
 * whole field is drawn at the `disabled` opacity. `multiline` makes it a text area that grows
 * with its text; `textLanguage="ar"` types right to left in the Arabic font.
 */
export function TextField({
  label,
  description,
  inputMode,
  autoCapitalize,
  placeholder,
  multiline = false,
  textLanguage,
  ...props
}: TextFieldProps): ReactElement {
  const fill = useFill();
  const inputProps = {
    ...(placeholder === undefined ? {} : { placeholder }),
    ...(textLanguage === undefined ? {} : { lang: textLanguage, dir: "rtl" }),
    className: [
      "min-h-control rounded-field border-field-error border-transparent px-lg text-input text-on-surface",
      fill,
      "caret-accent placeholder:text-on-surface-variant",
      "outline-none data-focus-visible:outline-focus-ring data-focus-visible:outline-offset-focus-ring",
      "data-focus-visible:outline-accent",
      "data-invalid:border-error",
      multiline ? "field-sizing-content resize-none py-md" : "",
      textLanguage === "ar" ? "font-arabic" : "",
    ].join(" "),
  };
  return (
    <AriaTextField {...props} className="flex flex-col gap-xs text-start data-disabled:opacity-disabled">
      <Label className="text-label text-on-surface">{label}</Label>
      {multiline ? (
        <TextArea {...inputProps} />
      ) : (
        <Input
          {...inputProps}
          {...(inputMode === undefined ? {} : { inputMode })}
          {...(autoCapitalize === undefined ? {} : { autoCapitalize })}
        />
      )}
      {description !== undefined && (
        <Text slot="description" className="text-caption text-on-surface-variant">
          {description}
        </Text>
      )}
      <FieldError className="text-caption text-error" />
    </AriaTextField>
  );
}
