import { createFileRoute } from "@tanstack/react-router";
import { PracticeSettingsPage } from "@/features/account/settings/practice/PracticeSettingsPage";

export const Route = createFileRoute("/account/practice")({
  component: PracticeSettingsPage,
});
