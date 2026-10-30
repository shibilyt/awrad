import { useEffect, useState, type ReactElement } from "react";
import { useTranslation } from "react-i18next";
import { ApiProblem } from "@/shared/api/problem";
import { clock, DEFAULT_POLICY, practiceToday, useDeviceLocation } from "@/shared/practice";
import { useSessionProblem, useSyncState, type SyncState } from "@/shared/sync";
import { Button } from "@/shared/ui/Button";
import { FormAlert, FormNotice } from "../../AccountScreen";
import { problemKey } from "../../problems";
import { useSignedInAccount } from "../AccountArea";
import { useEndSessionOn } from "../sessionEnded";
import { SettingsScreen } from "../SettingsScreen";
import { CalculationSections, DayResetSection } from "./ChoiceSections";
import { HijriSection } from "./HijriSection";
import { LocationSection } from "./LocationSection";
import { usePolicyEditor, type EditFailure } from "./usePolicyEditor";

function failureKey(failure: EditFailure): string {
  if (failure.kind === "problem") return problemKey(failure.error);
  return failure.kind === "rejected" ? "practice.failure.rejected" : "practice.failure.invalid";
}

/** The settings themselves, once the account's entities are read. */
function PracticeSettings({ accountId, state }: { accountId: string; state: SyncState }): ReactElement {
  const { t } = useTranslation();
  const editor = usePolicyEditor(accountId);
  const policy = editor.policy(state.practice_policy[accountId]?.document ?? DEFAULT_POLICY);
  const [location, setLocation] = useDeviceLocation(accountId);
  const [now] = useState(() => clock.now());
  const timeZone = clock.timeZone();
  const today = practiceToday({ now, timeZone, policy, location });
  useEndSessionOn(editor.failure?.kind === "problem" ? editor.failure.error : null);

  return (
    <>
      <FormNotice message={editor.notice === null ? null : t(`practice.notice.${editor.notice}`)} />
      <FormAlert message={editor.failure === null ? null : t(failureKey(editor.failure))} />
      <DayResetSection policy={policy} location={location} today={today} onChange={editor.change} />
      <LocationSection location={location} onLocation={setLocation} today={today} timeZone={timeZone} />
      <CalculationSections policy={policy} onChange={editor.change} />
      <HijriSection policy={policy} today={today} onChange={editor.change} />
    </>
  );
}

/**
 * Practice settings (slice 3d): the account practice policy, read from the changes feed and
 * saved one change at a time, and this browser's own location for Maghrib.
 */
export function PracticeSettingsPage(): ReactElement {
  const { t } = useTranslation();
  const account = useSignedInAccount();
  const sync = useSyncState(account.id);
  const onSessionProblem = useSessionProblem();
  useEndSessionOn(sync.error);
  const error = sync.error;
  useEffect(() => {
    // Another account signed in from another tab; a signed-out session is handled above.
    if (error instanceof ApiProblem && error.code === "account_mismatch") onSessionProblem(error);
  }, [error, onSessionProblem]);

  return (
    <SettingsScreen title={t("practice.title")} intro={<p>{t("practice.intro")}</p>}>
      {sync.data !== undefined && <PracticeSettings accountId={account.id} state={sync.data} />}
      {sync.data === undefined && sync.isPending && <p role="status">{t("practice.loading")}</p>}
      {sync.data === undefined && sync.isError && (
        <>
          <FormAlert message={t(problemKey(sync.error))} />
          <Button onPress={() => void sync.refetch()}>{t("practice.retry")}</Button>
        </>
      )}
    </SettingsScreen>
  );
}
