import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { RouterProvider, createMemoryHistory, createRouter } from "@tanstack/react-router";
import { render, type RenderResult } from "@testing-library/react";
import type { ReactElement } from "react";
import { routeTree } from "@/routeTree.gen";
import { server } from "./setup";

function testQueryClient(): QueryClient {
  return new QueryClient({ defaultOptions: { queries: { retry: false }, mutations: { retry: false } } });
}

/** Renders with a fresh, retry-free query client per test. */
export function renderWithQuery(ui: ReactElement): RenderResult {
  return render(<QueryClientProvider client={testQueryClient()}>{ui}</QueryClientProvider>);
}

/** Renders the whole app (real route tree, root layout included) at `path`. */
export function renderRoute(path: string): RenderResult & { router: ReturnType<typeof testRouter> } {
  const queryClient = testQueryClient();
  const router = testRouter(path, queryClient);
  const result = render(
    <QueryClientProvider client={queryClient}>
      <RouterProvider router={router} />
    </QueryClientProvider>,
  );
  return { ...result, router };
}

function testRouter(path: string, queryClient: QueryClient) {
  return createRouter({
    routeTree,
    context: { queryClient },
    history: createMemoryHistory({ initialEntries: [path] }),
  });
}

export interface RecordedRequest {
  method: string;
  path: string;
  headers: Headers;
  body: unknown;
}

/** Records every request the app sends, with its JSON body, in order. */
export function recordRequests(): RecordedRequest[] {
  const requests: RecordedRequest[] = [];
  server.events.on("request:start", ({ request }) => {
    const entry: RecordedRequest = {
      method: request.method,
      path: new URL(request.url).pathname,
      headers: request.headers,
      body: undefined,
    };
    requests.push(entry);
    void request
      .clone()
      .text()
      .then((text) => {
        // JSON from the API; anything else (a file PUT to storage) as its text.
        try {
          entry.body = text === "" ? undefined : JSON.parse(text);
        } catch {
          entry.body = text;
        }
      });
  });
  return requests;
}
