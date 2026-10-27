import { createFileRoute } from "@tanstack/react-router";
import { DhikrPage } from "@/features/library/DhikrPage";
import { loadCatalog } from "@/shared/dhikr-catalog";

export const Route = createFileRoute("/library/dhikrs/$key")({
  loader: async () => {
    await loadCatalog();
  },
  component: DhikrPage,
});
