import { createFileRoute } from "@tanstack/react-router";
import { ConfirmEmailChangePage } from "@/features/account/settings/ConfirmEmailChangePage";

export const Route = createFileRoute("/account/email/confirm")({
  component: ConfirmEmailChangePage,
});
