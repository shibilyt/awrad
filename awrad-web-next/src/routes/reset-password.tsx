import { createFileRoute } from "@tanstack/react-router";
import { ResetPasswordPage } from "@/features/account/ResetPasswordPage";

export const Route = createFileRoute("/reset-password")({
  component: ResetPasswordPage,
});
