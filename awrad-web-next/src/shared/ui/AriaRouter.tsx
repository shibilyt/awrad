import { useRouter, type NavigateOptions, type ToOptions } from "@tanstack/react-router";
import type { ReactElement, ReactNode } from "react";
import { RouterProvider } from "react-aria-components";

declare module "react-aria-components" {
  interface RouterConfig {
    href: NonNullable<ToOptions["to"]>;
    routerOptions: Omit<NavigateOptions, keyof ToOptions>;
  }
}

/**
 * Lets React Aria links (a bottom-bar tab with an `href`) navigate through TanStack Router, so
 * they're real links that change the page without a reload, and their `href`s are typed paths.
 */
export function AriaRouter({ children }: { children: ReactNode }): ReactElement {
  const router = useRouter();
  return (
    <RouterProvider
      navigate={(to, options) => {
        void router.navigate({ ...options, to });
      }}
      useHref={(to) => router.buildLocation({ to }).href}
    >
      {children}
    </RouterProvider>
  );
}
