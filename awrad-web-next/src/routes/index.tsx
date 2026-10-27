import { createFileRoute } from "@tanstack/react-router";
import type { ReactElement } from "react";
import { WelcomePage } from "@/features/account/WelcomePage";
import { homeSearch } from "@/features/account/search";
import { FeaturedCollections } from "@/features/library/CollectionTiles";

/** Home puts two features together: features never import each other, so the route does it. */
function HomePage(): ReactElement {
  return (
    <WelcomePage>
      <FeaturedCollections />
    </WelcomePage>
  );
}

// Route files stay thin: they map a URL to a feature's page.
export const Route = createFileRoute("/")({
  validateSearch: homeSearch,
  component: HomePage,
});
