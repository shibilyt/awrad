import { createFileRoute } from "@tanstack/react-router";
import { AccountArea } from "@/features/account/settings/AccountArea";

// Every page under /account needs a signed-in account; the layout checks it once.
export const Route = createFileRoute("/account")({
  component: AccountArea,
});
