import { useQuery } from "@tanstack/react-query";
import { useState, type ReactElement } from "react";
import { useTranslation } from "react-i18next";
import { InlineButton, PrimaryButton, SecondaryButton } from "@/shared/ui/Button";
import { ConfirmDialog } from "@/shared/ui/ConfirmDialog";
import { FormAlert, FormNotice } from "../AccountScreen";
import { problemKey } from "../problems";
import { accountSessionsQuery, type AccountSession } from "./api";
import { relativeTime } from "./relativeTime";
import { isSessionEnded, useEndSessionOn } from "./sessionEnded";
import { SettingsScreen } from "./SettingsScreen";
import { sessionName, useDeviceActions } from "./useDeviceActions";

function SessionRow({
  session,
  now,
  onSignOut,
}: {
  session: AccountSession;
  now: number;
  onSignOut: (session: AccountSession) => void;
}): ReactElement {
  const { t, i18n } = useTranslation();
  const name = sessionName(t, session);
  return (
    <li className="flex items-center gap-4 px-5 py-4">
      <div className="flex min-w-0 flex-1 flex-col gap-1">
        <p className="flex flex-wrap items-center gap-2 font-semibold">
          <bdi className="break-all">{name}</bdi>
          {session.is_current && (
            <span className="rounded-full bg-primary-container px-2.5 py-0.5 text-xs text-on-primary-container">
              {t("account.devices.current")}
            </span>
          )}
        </p>
        <p className="text-sm text-on-surface-variant">
          {t("account.devices.details", {
            platform: t(`account.devices.platform.${session.platform}`),
            when: relativeTime(session.last_seen_at, now, i18n.language),
          })}
        </p>
      </div>
      {!session.is_current && (
        <InlineButton
          aria-label={t("account.devices.signOutNamed", { name })}
          onPress={() => {
            onSignOut(session);
          }}
        >
          {t("account.devices.signOut")}
        </InlineButton>
      )}
    </li>
  );
}

function SessionList({ sessions }: { sessions: AccountSession[] }): ReactElement {
  const { t } = useTranslation();
  const [now] = useState(() => Date.now());
  const actions = useDeviceActions();
  const hasOthers = sessions.some((session) => !session.is_current);
  const target = actions.target === null ? "" : sessionName(t, actions.target);

  return (
    <>
      <FormNotice message={actions.message?.kind === "notice" ? actions.message.text : null} />
      <FormAlert message={actions.message?.kind === "alert" ? actions.message.text : null} />
      <ul
        aria-label={t("account.devices.listLabel")}
        className="flex flex-col divide-y divide-outline rounded-2xl bg-surface"
      >
        {sessions.map((session) => (
          <SessionRow key={session.id} session={session} now={now} onSignOut={actions.ask} />
        ))}
      </ul>
      {hasOthers ? (
        <SecondaryButton onPress={actions.askOthers}>{t("account.devices.signOutOthers")}</SecondaryButton>
      ) : (
        <p className="text-on-surface-variant">{t("account.devices.noOthers")}</p>
      )}
      <ConfirmDialog
        isOpen={actions.target !== null}
        onOpenChange={(open) => {
          if (!open) actions.cancel();
        }}
        title={t("account.devices.confirmTitle", { name: target })}
        confirmLabel={t("account.devices.signOut")}
        cancelLabel={t("account.cancel")}
        onConfirm={actions.confirm}
        isPending={actions.isRevoking}
      >
        <p>{t("account.devices.confirmBody")}</p>
      </ConfirmDialog>
      <ConfirmDialog
        isOpen={actions.confirmingOthers}
        onOpenChange={(open) => {
          if (!open) actions.cancelOthers();
        }}
        title={t("account.devices.othersTitle")}
        confirmLabel={t("account.devices.signOutOthers")}
        cancelLabel={t("account.cancel")}
        onConfirm={actions.confirmOthers}
        isPending={actions.isRevokingOthers}
      >
        <p>{t("account.devices.othersBody")}</p>
      </ConfirmDialog>
    </>
  );
}

/** Every phone and browser signed in to the account, this one marked; any other can be signed out. */
export function DevicesPage(): ReactElement {
  const { t } = useTranslation();
  const sessions = useQuery(accountSessionsQuery);
  useEndSessionOn(sessions.error);

  return (
    <SettingsScreen title={t("account.devices.title")} intro={<p>{t("account.devices.intro")}</p>}>
      {sessions.data !== undefined && <SessionList sessions={sessions.data} />}
      {sessions.data === undefined && sessions.isPending && <p role="status">{t("account.devices.loading")}</p>}
      {sessions.data === undefined && sessions.isError && !isSessionEnded(sessions.error) && (
        <>
          <FormAlert message={t(problemKey(sessions.error))} />
          <PrimaryButton onPress={() => void sessions.refetch()}>{t("account.page.retry")}</PrimaryButton>
        </>
      )}
    </SettingsScreen>
  );
}
