import { createFileRoute } from "@tanstack/react-router";
import { ChangeEmailPage } from "@/features/account/settings/ChangeEmailPage";

export const Route = createFileRoute("/account/email/")({
  component: ChangeEmailPage,
});
