import { createFileRoute } from "@tanstack/react-router";
import { AccountPage } from "@/features/account/AccountPage";
import { accountSearch } from "@/features/account/search";

export const Route = createFileRoute("/account/")({
  validateSearch: accountSearch,
  component: AccountPage,
});
