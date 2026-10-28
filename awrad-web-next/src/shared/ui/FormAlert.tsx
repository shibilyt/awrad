import type { ReactElement } from "react";
import { ErrorIcon } from "./icons.gen";
import { useFill } from "./Surface";

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
