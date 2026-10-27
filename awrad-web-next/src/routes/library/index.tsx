import { createFileRoute } from "@tanstack/react-router";
import { LibraryPage } from "@/features/library/LibraryPage";
import { librarySearch } from "@/features/library/search";
import { loadCatalog } from "@/shared/dhikr-catalog";

export const Route = createFileRoute("/library/")({
  validateSearch: librarySearch,
  // The catalog is a chunk of its own; the page renders once it's here.
  loader: async () => {
    await loadCatalog();
  },
  component: LibraryPage,
});
