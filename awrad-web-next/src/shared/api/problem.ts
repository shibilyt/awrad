import type { components } from "./schema.gen";

/** An RFC 9457 problem from the API (contracts/api/STYLE.md §7). */
export type Problem = components["schemas"]["Problem"];

/**
 * Thrown for every non-2xx response. Callers switch on `code`, never on
 * `detail`: the API's English isn't shown to users. Map `code` to a
 * translation key instead.
 */
export class ApiProblem extends Error {
  readonly code: string;
  readonly status: number;

  constructor(problem: Pick<Problem, "code" | "status" | "detail">) {
    super(problem.detail);
    this.name = "ApiProblem";
    this.code = problem.code;
    this.status = problem.status;
  }
}

function isProblem(value: unknown): value is Problem {
  return (
    typeof value === "object" &&
    value !== null &&
    "code" in value &&
    typeof value.code === "string" &&
    "status" in value &&
    typeof value.status === "number"
  );
}

/** Turns an openapi-fetch error body into an `ApiProblem`, even when the body isn't a problem. */
export function toProblem(error: unknown, response: Response): ApiProblem {
  if (isProblem(error)) return new ApiProblem(error);
  return new ApiProblem({ code: "unexpected_response", status: response.status, detail: response.statusText });
}
