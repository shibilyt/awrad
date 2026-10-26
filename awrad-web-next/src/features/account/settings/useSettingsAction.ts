import { useAccountAction, type AccountAction } from "../useAccountAction";
import { isSessionEnded, useEndSession } from "./sessionEnded";

interface Options<Input, Result> {
  action: (input: Input) => Promise<Result>;
  onSuccess: (result: Result, input: Input) => void;
  onProblem?: (error: unknown, input: Input) => boolean;
}

/**
 * `useAccountAction` for a signed-in form: a `401` means the session ended
 * meanwhile, so the person is signed out with a message instead of seeing a
 * form error.
 */
export function useSettingsAction<Input, Result>({
  action,
  onSuccess,
  onProblem,
}: Options<Input, Result>): AccountAction<Input> {
  const endSession = useEndSession();
  return useAccountAction({
    action,
    onSuccess,
    onProblem: (error, input) => {
      if (isSessionEnded(error)) {
        void endSession();
        return true;
      }
      return onProblem?.(error, input) ?? false;
    },
  });
}
