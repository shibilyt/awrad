import type { ReactElement, ReactNode } from "react";
import { Form } from "react-aria-components";
import { Button } from "@/shared/ui/Button";
import { ErrorIcon } from "@/shared/ui/icons.gen";
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
    <main className="mx-auto flex w-full max-w-content flex-col gap-section-gap px-page-margin py-4xl">
      <h1 className="text-title text-on-surface">{title}</h1>
      {intro !== undefined && <div className="flex flex-col gap-xs text-on-surface-variant">{intro}</div>}
      {children}
      {footer !== undefined && <div className="flex flex-col items-start gap-row-gap text-label">{footer}</div>}
    </main>
  );
}

/**
 * A request-level message, filled (no outline) in `error` text beside the decorative `error` icon.
 * `role="alert"` announces it when it appears.
 */
export function FormAlert({ message }: { message: string | null }): ReactElement | null {
  const fill = useFill();
  if (message === null) return null;
  return (
    <p
      key={message}
      role="alert"
      className={`content-swap flex items-start gap-inline-gap rounded-field px-lg py-md text-body-small text-error ${fill}`}
    >
      <ErrorIcon size="small" />
      <span className="min-w-0 flex-1">{message}</span>
    </p>
  );
}

/** A confirmation (code sent, email verified). `role="status"` announces it politely. */
export function FormNotice({ message }: { message: string | null }): ReactElement | null {
  if (message === null) return null;
  return (
    <p
      key={message}
      role="status"
      className="content-swap rounded-field bg-primary-container px-lg py-md text-body-small text-on-primary-container"
    >
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
