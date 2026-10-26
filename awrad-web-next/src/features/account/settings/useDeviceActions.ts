import { useMutation, useQueryClient } from "@tanstack/react-query";
import type { TFunction } from "i18next";
import { useState } from "react";
import { useTranslation } from "react-i18next";
import { ApiProblem } from "@/shared/api/problem";
import { problemKey } from "../problems";
import { accountSessionsQuery, revokeAccountSession, revokeOtherAccountSessions, type AccountSession } from "./api";
import { isSessionEnded, useEndSession } from "./sessionEnded";

/** The name shown for a session; the contract leaves it `null` when the server couldn't tell. */
export function sessionName(t: TFunction, session: AccountSession): string {
  if (session.name !== null) return session.name;
  return session.kind === "browser" ? t("account.devices.webBrowser") : t("account.devices.unknownDevice");
}

export interface DeviceMessage {
  kind: "notice" | "alert";
  text: string;
}

export interface DeviceActions {
  message: DeviceMessage | null;
  /** The session waiting for "sign out?" to be confirmed. */
  target: AccountSession | null;
  ask: (session: AccountSession) => void;
  cancel: () => void;
  confirm: () => void;
  isRevoking: boolean;
  confirmingOthers: boolean;
  askOthers: () => void;
  cancelOthers: () => void;
  confirmOthers: () => void;
  isRevokingOthers: boolean;
}

/**
 * Signing out one device, or every other one, each behind a confirmation.
 * Afterwards the list is fetched again. A `404` means that device had already
 * gone, which is what the person wanted, so it's a notice, not an error.
 */
export function useDeviceActions(): DeviceActions {
  const { t } = useTranslation();
  const queryClient = useQueryClient();
  const endSession = useEndSession();
  const [message, setMessage] = useState<DeviceMessage | null>(null);
  const [target, setTarget] = useState<AccountSession | null>(null);
  const [confirmingOthers, setConfirmingOthers] = useState(false);

  const refresh = () => queryClient.invalidateQueries({ queryKey: accountSessionsQuery.queryKey });
  const fail = (error: unknown) => {
    if (isSessionEnded(error)) {
      void endSession();
      return;
    }
    if (error instanceof ApiProblem && error.code === "not_found") {
      setMessage({ kind: "notice", text: t("account.devices.alreadyEnded") });
      void refresh();
      return;
    }
    setMessage({ kind: "alert", text: t(problemKey(error)) });
  };

  const revoke = useMutation({
    mutationFn: (session: AccountSession) => revokeAccountSession(session.id),
    onSuccess: (_, session) => {
      setMessage({ kind: "notice", text: t("account.devices.signedOut", { name: sessionName(t, session) }) });
      void refresh();
    },
    onError: fail,
    onSettled: () => {
      setTarget(null);
    },
  });

  const revokeOthers = useMutation({
    mutationFn: revokeOtherAccountSessions,
    onSuccess: () => {
      setMessage({ kind: "notice", text: t("account.devices.othersSignedOut") });
      void refresh();
    },
    onError: fail,
    onSettled: () => {
      setConfirmingOthers(false);
    },
  });

  return {
    message,
    target,
    ask: (session: AccountSession) => {
      setMessage(null);
      setTarget(session);
    },
    cancel: () => {
      if (!revoke.isPending) setTarget(null);
    },
    confirm: () => {
      if (target !== null) revoke.mutate(target);
    },
    isRevoking: revoke.isPending,
    confirmingOthers,
    askOthers: () => {
      setMessage(null);
      setConfirmingOthers(true);
    },
    cancelOthers: () => {
      if (!revokeOthers.isPending) setConfirmingOthers(false);
    },
    confirmOthers: () => {
      revokeOthers.mutate();
    },
    isRevokingOthers: revokeOthers.isPending,
  };
}
