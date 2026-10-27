import { QueryClient } from "@tanstack/react-query";
import { createRouter } from "@tanstack/react-router";
import { routeTree } from "@/routeTree.gen";

export const queryClient = new QueryClient();

export const router = createRouter({
  routeTree,
  context: { queryClient },
  defaultPreload: "intent",
  // Page changes fade (src/shared/ui/motion.css) where the browser has view transitions.
  defaultViewTransition: true,
});

declare module "@tanstack/react-router" {
  interface Register {
    router: typeof router;
  }
}
