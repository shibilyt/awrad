import { useQueryClient } from "@tanstack/react-query";
import { useNavigate } from "@tanstack/react-router";
import { useState, type ReactElement } from "react";
import { Form } from "react-aria-components";
import { useTranslation } from "react-i18next";
import { DangerButton } from "@/shared/ui/Button";
import { ConfirmDialog } from "@/shared/ui/ConfirmDialog";
import { FormAlert } from "../AccountScreen";
import { CurrentPasswordField } from "../fields";
import { readCurrentPassword } from "../formValues";
import { useSignedInAccount } from "./AccountArea";
import { deleteAccount, forgetAccount } from "./api";
import { SettingsScreen } from "./SettingsScreen";
import { useSettingsAction } from "./useSettingsAction";

function Explanation(): ReactElement {
  const { t } = useTranslation();
  const account = useSignedInAccount();
  return (
    <>
      <p>{t("account.delete.intro")}</p>
      <ul className="flex list-disc flex-col gap-xs ps-xl">
        <li>{t("account.delete.everythingDeleted")}</li>
        <li>{t("account.delete.signedOutEverywhere")}</li>
        <li>{t("account.delete.deviceDataStays")}</li>
        <li>
          {t("account.delete.confirmationEmail")} <bdi className="font-semibold text-on-surface">{account.email}</bdi>
        </li>
        <li className="font-semibold text-error">{t("account.delete.noUndo")}</li>
      </ul>
    </>
  );
}

/**
 * Delete the account now (slice 2b decision 1): the password, then a
 * confirmation dialog. Afterwards this browser is signed out, and home says so.
 */
export function DeleteAccountPage(): ReactElement {
  const { t } = useTranslation();
  const queryClient = useQueryClient();
  const navigate = useNavigate();
  const [confirmPassword, setConfirmPassword] = useState<string | null>(null);

  const remove = useSettingsAction({
    action: deleteAccount,
    onSuccess: () => {
      // Leave first: the account area would otherwise send a signed-out visitor to sign in.
      void navigate({ to: "/", search: { notice: "account_deleted" } }).then(() => {
        forgetAccount(queryClient);
      });
    },
    onProblem: () => {
      setConfirmPassword(null);
      return false;
    },
  });

  const submit = (data: FormData) => {
    const errors: Record<string, string> = {};
    const password = readCurrentPassword(data, errors);
    // The client's checks first; the dialog only opens for something to send.
    if (Object.keys(errors).length > 0) remove.submit(null, errors);
    else setConfirmPassword(password);
  };

  return (
    <SettingsScreen title={t("account.delete.title")} intro={<Explanation />}>
      <Form
        validationBehavior="aria"
        validationErrors={remove.errors}
        onSubmit={(event) => {
          event.preventDefault();
          submit(new FormData(event.currentTarget));
        }}
        className="flex flex-col gap-xl"
      >
        <CurrentPasswordField />
        <FormAlert message={remove.alert} />
        <DangerButton type="submit">{t("account.delete.submit")}</DangerButton>
      </Form>
      <ConfirmDialog
        isOpen={confirmPassword !== null}
        onOpenChange={(open) => {
          if (!open && !remove.isPending) setConfirmPassword(null);
        }}
        title={t("account.delete.confirmTitle")}
        confirmLabel={t("account.delete.confirm")}
        cancelLabel={t("account.cancel")}
        onConfirm={() => {
          if (confirmPassword !== null) remove.submit(confirmPassword, {});
        }}
        isPending={remove.isPending}
      >
        <p>{t("account.delete.confirmBody")}</p>
      </ConfirmDialog>
    </SettingsScreen>
  );
}
