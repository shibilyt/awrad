import { useMutation } from "@tanstack/react-query";
import { useState } from "react";
import { useTranslation } from "react-i18next";
import { fieldErrorKeys, problemKey } from "./problems";

interface Options<Input, Result> {
  action: (input: Input) => Promise<Result>;
  onSuccess: (result: Result, input: Input) => void;
  /** Handles a problem itself (for example by navigating); return `true` to skip the alert. */
  onProblem?: (error: unknown, input: Input) => boolean;
}

export interface AccountAction<Input> {
  /** Runs the action, unless the client's own checks found errors (translation keys by input name). */
  submit: (input: Input | null, errorKeys: Record<string, string>) => void;
  errors: Record<string, string>;
  alert: string | null;
  isPending: boolean;
}

function translateAll(t: (key: string) => string, keys: Record<string, string>): Record<string, string> {
  return Object.fromEntries(Object.entries(keys).map(([field, key]) => [field, t(key)]));
}

/**
 * One account request behind a form: client checks first, then the request,
 * then its problem shown as translated text chosen by `code` (and field codes
 * on their inputs). Never the server's `detail`.
 */
export function useAccountAction<Input, Result>({
  action,
  onSuccess,
  onProblem,
}: Options<Input, Result>): AccountAction<Input> {
  const { t } = useTranslation();
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [alert, setAlert] = useState<string | null>(null);
  const mutation = useMutation({
    mutationFn: action,
    onSuccess: (result, input) => {
      onSuccess(result, input);
    },
    onError: (error, input) => {
      if (onProblem?.(error, input) === true) return;
      setErrors(translateAll(t, fieldErrorKeys(error)));
      setAlert(t(problemKey(error)));
    },
  });

  return {
    submit: (input, errorKeys) => {
      if (input === null || Object.keys(errorKeys).length > 0) {
        setErrors(translateAll(t, errorKeys));
        setAlert(t("account.problems.validation_failed"));
        return;
      }
      setErrors({});
      setAlert(null);
      mutation.mutate(input);
    },
    errors,
    alert,
    isPending: mutation.isPending,
  };
}
