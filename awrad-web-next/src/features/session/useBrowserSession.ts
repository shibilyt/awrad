import { useQuery } from "@tanstack/react-query";
import { api, setCsrfToken } from "@/shared/api/client";
import { toProblem } from "@/shared/api/problem";

export type BrowserSession =
  | { status: "checking" }
  | { status: "signed_in" }
  | { status: "signed_out" }
  | { status: "unavailable"; retry: () => void };

/**
 * Whether this browser has a signed-in session, from `get_browser_csrf_token`.
 * A signed-in session's token is kept for later writes. `401 unauthenticated`
 * means signed out, not an error.
 */
export function useBrowserSession(): BrowserSession {
  const query = useQuery({
    queryKey: ["browser", "csrf_token"],
    retry: false,
    queryFn: async () => {
      const { data, error, response } = await api.GET("/api/v1/browser/csrf_token");
      if (error !== undefined) {
        const problem = toProblem(error, response);
        if (problem.code === "unauthenticated") return { signedIn: false } as const;
        throw problem;
      }
      setCsrfToken(data.csrf_token);
      return { signedIn: true } as const;
    },
  });

  if (query.isPending) return { status: "checking" };
  if (query.isError) {
    return { status: "unavailable", retry: () => void query.refetch() };
  }
  return { status: query.data.signedIn ? "signed_in" : "signed_out" };
}
