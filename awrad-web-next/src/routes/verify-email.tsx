import { createFileRoute } from "@tanstack/react-router";
import { VerifyEmailPage } from "@/features/account/VerifyEmailPage";

export const Route = createFileRoute("/verify-email")({
  component: VerifyEmailPage,
});
