import { createFileRoute } from "@tanstack/react-router";
import { WelcomePage } from "@/features/account/WelcomePage";

// Route files stay thin: they map a URL to a feature's page.
export const Route = createFileRoute("/")({
  component: WelcomePage,
});
