import { createFileRoute } from "@tanstack/react-router";
import { CollectionPage } from "@/features/library/CollectionPage";
import { loadCatalog } from "@/shared/dhikr-catalog";

export const Route = createFileRoute("/library/collections/$key")({
  loader: async () => {
    await loadCatalog();
  },
  component: CollectionPage,
});
