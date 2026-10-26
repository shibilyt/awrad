import { createFileRoute } from "@tanstack/react-router";
import { ChangePasswordPage } from "@/features/account/settings/ChangePasswordPage";

export const Route = createFileRoute("/account/password")({
  component: ChangePasswordPage,
});
