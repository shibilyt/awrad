import { createFileRoute } from "@tanstack/react-router";
import { WelcomePage } from "@/features/account/WelcomePage";
import { homeSearch } from "@/features/account/search";

// Route files stay thin: they map a URL to a feature's page.
export const Route = createFileRoute("/")({
  validateSearch: homeSearch,
  component: WelcomePage,
});
