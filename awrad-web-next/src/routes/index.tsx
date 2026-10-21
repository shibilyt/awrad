import { createFileRoute } from "@tanstack/react-router";
import { WelcomePage } from "@/features/session/WelcomePage";

// Route files stay thin: they map a URL to a feature's page.
export const Route = createFileRoute("/")({
  component: WelcomePage,
});
