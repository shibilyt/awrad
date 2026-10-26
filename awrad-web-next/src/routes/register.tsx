import { createFileRoute } from "@tanstack/react-router";
import { RegisterPage } from "@/features/account/RegisterPage";

export const Route = createFileRoute("/register")({
  component: RegisterPage,
});
