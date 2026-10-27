import { QueryClientProvider } from "@tanstack/react-query";
import { RouterProvider } from "@tanstack/react-router";
import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { queryClient, router } from "@/app/router";
import { initI18n } from "@/shared/i18n";
import "@/shared/ui/theme.css";

const root = document.getElementById("root");
if (root === null) throw new Error("index.html is missing #root");

/** The dev-only component gallery's path. Production builds drop it, and the gallery's code, entirely. */
const GALLERY_PATH = "/dev/components";

await initI18n();
if (import.meta.env.DEV && window.location.pathname === GALLERY_PATH) {
  const { renderGallery } = await import("@/dev/gallery/ComponentGallery");
  await renderGallery(root);
} else {
  createRoot(root).render(
    <StrictMode>
      <QueryClientProvider client={queryClient}>
        <RouterProvider router={router} />
      </QueryClientProvider>
    </StrictMode>,
  );
}
