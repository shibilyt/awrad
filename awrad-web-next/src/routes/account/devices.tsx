import { createFileRoute } from "@tanstack/react-router";
import { DevicesPage } from "@/features/account/settings/DevicesPage";

export const Route = createFileRoute("/account/devices")({
  component: DevicesPage,
});
