import { useMutation } from "@tanstack/react-query";
import { useState, type ReactElement, type ReactNode } from "react";
import { useTranslation } from "react-i18next";
import { emailInput } from "@/shared/account-input";
import { ApiProblem } from "@/shared/api/problem";
import { SecondaryButton } from "@/shared/ui/Button";
import { FormAlert, FormNotice } from "./AccountScreen";
import type { PendingAccount } from "./pending";
import { problemKey } from "./problems";
import { RESEND_COOLDOWN_SECONDS, useCooldown } from "./useCooldown";

/**
 * "Send a new code", with a cooldown: a minute after each code, or the
 * server's `Retry-After` when it says `rate_limited`. A new code cancels the
 * old one, so the person is told to use the latest email.
 */
export function ResendCode({
  email,
  send,
  initialCooldown,
}: {
  /** What's typed (or remembered) for the email; checked with the shared rule before sending. */
  email: string;
  send: (email: string) => Promise<void>;
  initialCooldown: number;
}): ReactElement {
  const { t } = useTranslation();
  const cooldown = useCooldown(initialCooldown);
  const [notice, setNotice] = useState<string | null>(null);
  const [alert, setAlert] = useState<string | null>(null);
  const mutation = useMutation({
    mutationFn: send,
    onSuccess: () => {
      setAlert(null);
      setNotice(t("account.code.resent"));
      cooldown.start(RESEND_COOLDOWN_SECONDS);
    },
    onError: (error) => {
      setNotice(null);
      setAlert(t(problemKey(error)));
      if (error instanceof ApiProblem && error.retryAfter !== null) cooldown.start(error.retryAfter);
    },
  });

  const resend = () => {
    const valid = emailInput(email);
    if (valid === null) {
      setNotice(null);
      setAlert(t("account.fieldErrors.email_invalid"));
      return;
    }
    mutation.mutate(valid);
  };

  return (
    <div className="flex flex-col gap-2">
      <SecondaryButton onPress={resend} isDisabled={cooldown.remaining > 0} isPending={mutation.isPending}>
        {t("account.code.resend")}
      </SecondaryButton>
      {cooldown.remaining > 0 && (
        <p className="text-sm text-on-surface-variant">{t("account.code.resendIn", { seconds: cooldown.remaining })}</p>
      )}
      <FormNotice message={notice} />
      <FormAlert message={alert} />
    </div>
  );
}

/** "We sent a code to …", or, after a reload has forgotten the email, a field for it. */
export function CodeSentIntro({ pending, fallback }: { pending: PendingAccount | null; fallback: string }): ReactNode {
  const { t } = useTranslation();
  if (pending === null) return <p>{fallback}</p>;
  return (
    <>
      <p>{t("account.code.sentTo")}</p>
      <p className="font-semibold text-on-surface">
        <bdi>{pending.email}</bdi>
      </p>
    </>
  );
}
