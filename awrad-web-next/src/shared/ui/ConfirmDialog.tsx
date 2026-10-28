import type { ReactElement, ReactNode } from "react";
import { Dialog, Heading, Modal, ModalOverlay } from "react-aria-components";
import { Button } from "./Button";

/**
 * Asks before an action that can't be taken back (signing a device out,
 * deleting the account). React Aria makes it a modal `alertdialog`: focus moves
 * in and stays there, Escape cancels, and focus returns to the button that
 * opened it. Cancel comes first, so the first Tab from the dialog reaches the safe choice.
 *
 * components.md "Dialog": `surfaceBar`, `dialog` corners, `scrim` behind, `cardPadding`
 * inside, up to `dialogMaxWidth` wide; the title in `cardTitle`, the actions aligned to the
 * end, the confirmation an error button. It fades in and out (`overlay-fade`).
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
      className="overlay-fade fixed inset-0 z-10 flex items-center justify-center bg-scrim p-page-margin"
    >
      <Modal className="w-full max-w-dialog rounded-dialog bg-surface-bar p-card-padding">
        <Dialog role="alertdialog" className="flex flex-col gap-lg outline-none">
          <Heading slot="title" className="text-card-title text-on-surface">
            {title}
          </Heading>
          <div className="flex flex-col gap-sm text-body text-on-surface-variant">{children}</div>
          <div className="flex flex-wrap justify-end gap-sm">
            <Button
              variant="secondary"
              width="label"
              isDisabled={isPending}
              onPress={() => {
                onOpenChange(false);
              }}
            >
              {cancelLabel}
            </Button>
            <Button variant="error" width="label" onPress={onConfirm} isPending={isPending}>
              {confirmLabel}
            </Button>
          </div>
        </Dialog>
      </Modal>
    </ModalOverlay>
  );
}

/**
 * Asks the person to choose between two ways forward, neither destructive (a conflict: Use theirs
 * or Keep mine). The same dialog as `ConfirmDialog`, but it can't be dismissed (no Escape, no
 * press outside): one of the two must be chosen. The first is secondary, the second the main
 * button.
 */
export function ChoiceDialog({
  isOpen,
  title,
  children,
  first,
  second,
  isPending = false,
}: {
  isOpen: boolean;
  title: string;
  children: ReactNode;
  first: { label: string; onPress: () => void };
  second: { label: string; onPress: () => void };
  isPending?: boolean;
}): ReactElement {
  return (
    <ModalOverlay
      isOpen={isOpen}
      isDismissable={false}
      isKeyboardDismissDisabled
      className="overlay-fade fixed inset-0 z-10 flex items-center justify-center bg-scrim p-page-margin"
    >
      <Modal className="max-h-full w-full max-w-dialog overflow-y-auto rounded-dialog bg-surface-bar p-card-padding">
        <Dialog role="alertdialog" className="flex flex-col gap-lg outline-none">
          <Heading slot="title" className="text-card-title text-on-surface">
            {title}
          </Heading>
          <div className="flex flex-col gap-sm text-body text-on-surface-variant">{children}</div>
          <div className="flex flex-wrap justify-end gap-sm">
            <Button variant="secondary" width="label" isDisabled={isPending} onPress={first.onPress}>
              {first.label}
            </Button>
            <Button width="label" onPress={second.onPress} isPending={isPending}>
              {second.label}
            </Button>
          </div>
        </Dialog>
      </Modal>
    </ModalOverlay>
  );
}
