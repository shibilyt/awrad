import type { ReactElement, ReactNode } from "react";
import { Form } from "react-aria-components";
import { PrimaryButton } from "@/shared/ui/Button";
import { useFill } from "@/shared/ui/Surface";

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
    <main className="mx-auto flex w-full max-w-md flex-col gap-6 px-6 py-10">
      <h1 className="text-2xl font-semibold text-accent">{title}</h1>
      {intro !== undefined && <div className="flex flex-col gap-1 text-on-surface-variant">{intro}</div>}
      {children}
      {footer !== undefined && <div className="flex flex-col items-start gap-3 text-sm">{footer}</div>}
    </main>
  );
}

/** A request-level message, filled (no outline) in `error` text. `role="alert"` announces it when it appears. */
export function FormAlert({ message }: { message: string | null }): ReactElement | null {
  const fill = useFill();
  if (message === null) return null;
  return (
    <p role="alert" className={`rounded-xl px-4 py-3 text-sm text-error ${fill}`}>
      {message}
    </p>
  );
}

/** A confirmation (code sent, email verified). `role="status"` announces it politely. */
export function FormNotice({ message }: { message: string | null }): ReactElement | null {
  if (message === null) return null;
  return (
    <p role="status" className="rounded-xl bg-primary-container px-4 py-3 text-sm text-on-primary-container">
      {message}
    </p>
  );
}

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
      className="flex flex-col gap-5"
    >
      {children}
      <FormAlert message={alert} />
      <PrimaryButton type="submit" isPending={isPending}>
        {submitLabel}
      </PrimaryButton>
    </Form>
  );
}
