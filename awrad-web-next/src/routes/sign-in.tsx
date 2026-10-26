import { createFileRoute } from "@tanstack/react-router";
import { SignInPage } from "@/features/account/SignInPage";
import { signInSearch } from "@/features/account/search";

export const Route = createFileRoute("/sign-in")({
  validateSearch: signInSearch,
  component: SignInPage,
});
