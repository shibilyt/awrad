import type { ReactElement, ReactNode } from "react";
import { Dialog, Heading, Modal, ModalOverlay } from "react-aria-components";
import { DangerButton, SecondaryButton } from "./Button";
import { OnSurface } from "./Surface";

/**
 * Asks before an action that can't be taken back (signing a device out,
 * deleting the account). React Aria makes it a modal `alertdialog`: focus moves
 * in and stays there, Escape cancels, and focus returns to the button that
 * opened it. Cancel comes first, so the dialog's initial focus is the safe choice.
 */
export function ConfirmDialog({
  isOpen,
  onOpenChange,
  title,
  children,
  confirmLabel,
  cancelLabel,
  onConfirm,
  isPending = false,
}: {
  isOpen: boolean;
  onOpenChange: (isOpen: boolean) => void;
  title: string;
  children: ReactNode;
  confirmLabel: string;
  cancelLabel: string;
  onConfirm: () => void;
  isPending?: boolean;
}): ReactElement {
  return (
    <ModalOverlay
      isOpen={isOpen}
      onOpenChange={onOpenChange}
      isDismissable={!isPending}
      className="fixed inset-0 z-10 flex items-center justify-center bg-scrim p-page-margin"
    >
      <Modal className="w-full max-w-dialog rounded-dialog bg-surface p-2xl">
        <Dialog role="alertdialog" className="flex flex-col gap-lg outline-none">
          <Heading slot="title" className="text-card-title text-on-surface">
            {title}
          </Heading>
          <div className="flex flex-col gap-sm text-on-surface-variant">{children}</div>
          <div className="flex flex-col gap-row-gap">
            <OnSurface>
              <SecondaryButton
                isDisabled={isPending}
                onPress={() => {
                  onOpenChange(false);
                }}
              >
                {cancelLabel}
              </SecondaryButton>
              <DangerButton onPress={onConfirm} isPending={isPending}>
                {confirmLabel}
              </DangerButton>
            </OnSurface>
          </div>
        </Dialog>
      </Modal>
    </ModalOverlay>
  );
}
