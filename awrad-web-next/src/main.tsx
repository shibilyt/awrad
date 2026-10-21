import { QueryClientProvider } from "@tanstack/react-query";
import { RouterProvider } from "@tanstack/react-router";
import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { queryClient, router } from "@/app/router";
import { initI18n } from "@/shared/i18n";
import "@/shared/ui/theme.css";

const root = document.getElementById("root");
if (root === null) throw new Error("index.html is missing #root");

await initI18n();
createRoot(root).render(
  <StrictMode>
    <QueryClientProvider client={queryClient}>
      <RouterProvider router={router} />
    </QueryClientProvider>
  </StrictMode>,
);
