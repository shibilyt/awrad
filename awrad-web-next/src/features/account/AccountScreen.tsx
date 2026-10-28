import type { ReactElement, ReactNode } from "react";
import { Form } from "react-aria-components";
import { Button } from "@/shared/ui/Button";
import { FormAlert } from "@/shared/ui/FormAlert";

/** The frame every account screen shares: a heading, an optional intro, the content, then links. */
export function AccountScreen({
  title,
  intro,
  children,
  footer,
}: {
  title: string;
  intro?: ReactNode;
  children: ReactNode;
  footer?: ReactNode;
}): ReactElement {
  return (
    <main className="mx-auto flex w-full max-w-content flex-col gap-section-gap px-page-margin py-4xl">
      <h1 className="text-title text-on-surface">{title}</h1>
      {intro !== undefined && <div className="flex flex-col gap-xs text-on-surface-variant">{intro}</div>}
      {children}
      {footer !== undefined && <div className="flex flex-col items-start gap-row-gap text-label">{footer}</div>}
    </main>
  );
}

// The form messages are shared with the Library (slice 3b).
export { FormAlert, FormNotice } from "@/shared/ui/FormAlert";

/**
 * An account form. Validation is React Aria's ARIA mode: no browser bubbles,
 * errors (the client's own checks, or the server's field codes) come in
 * `errors` keyed by input name and are tied to their inputs.
 */
export function AccountForm({
  errors,
  alert,
  submitLabel,
  isPending,
  onSubmit,
  children,
}: {
  errors: Record<string, string>;
  alert: string | null;
  submitLabel: string;
  isPending: boolean;
  onSubmit: (data: FormData) => void;
  children: ReactNode;
}): ReactElement {
  return (
    <Form
      validationBehavior="aria"
      validationErrors={errors}
      onSubmit={(event) => {
        event.preventDefault();
        onSubmit(new FormData(event.currentTarget));
      }}
      className="flex flex-col gap-xl"
    >
      {children}
      <FormAlert message={alert} />
      <Button type="submit" isPending={isPending}>
        {submitLabel}
      </Button>
    </Form>
  );
}
