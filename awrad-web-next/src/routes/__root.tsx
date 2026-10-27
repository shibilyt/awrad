import type { QueryClient } from "@tanstack/react-query";
import { Outlet, createRootRouteWithContext } from "@tanstack/react-router";
import { AppShell } from "@/shared/ui/AppShell";
import { AriaRouter } from "@/shared/ui/AriaRouter";

export interface RouterContext {
  queryClient: QueryClient;
}

export const Route = createRootRouteWithContext<RouterContext>()({
  component: () => (
    <AriaRouter>
      <AppShell>
        <Outlet />
      </AppShell>
    </AriaRouter>
  ),
});
