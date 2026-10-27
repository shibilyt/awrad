import type { ReactElement, ReactNode } from "react";
import { Dialog, Heading, Modal, ModalOverlay } from "react-aria-components";

/**
 * A sheet anchored to the bottom of the page (components.md "Bottom sheet", web): a React Aria
 * modal dialog, so focus moves in and stays, Escape or a press on the `scrim` closes it (unless
 * `isDismissable` is false), and focus returns to what opened it. `surfaceBar` fill, top
 * corners `sheet`, a decorative drag handle, up to `contentMaxWidth` wide. It fades in and
 * out (`overlay-fade`); it doesn't slide, since web motion is fades only. Controls inside fill
 * as on the page (`surfaceBar` isn't a `surface` card).
 */
export function BottomSheet({
  isOpen,
  onOpenChange,
  title,
  children,
  isDismissable = true,
}: {
  isOpen: boolean;
  onOpenChange: (isOpen: boolean) => void;
  /** The sheet's heading, which also names the dialog. */
  title: string;
  children: ReactNode;
  isDismissable?: boolean;
}): ReactElement {
  return (
    <ModalOverlay
      isOpen={isOpen}
      onOpenChange={onOpenChange}
      isDismissable={isDismissable}
      isKeyboardDismissDisabled={!isDismissable}
      className="overlay-fade fixed inset-0 z-10 flex items-end justify-center bg-scrim"
    >
      <Modal className="flex max-h-dvh w-full max-w-content flex-col rounded-t-sheet bg-surface-bar">
        <Dialog className="flex flex-col gap-lg overflow-y-auto px-page-margin pb-2xl outline-none">
          <span aria-hidden="true" className="mx-auto mt-md h-xs w-3xl shrink-0 rounded-tab-indicator bg-outline" />
          <Heading slot="title" className="text-card-title text-on-surface">
            {title}
          </Heading>
          {children}
        </Dialog>
      </Modal>
    </ModalOverlay>
  );
}
