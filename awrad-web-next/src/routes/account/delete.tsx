import { createFileRoute } from "@tanstack/react-router";
import { DeleteAccountPage } from "@/features/account/settings/DeleteAccountPage";

export const Route = createFileRoute("/account/delete")({
  component: DeleteAccountPage,
});
