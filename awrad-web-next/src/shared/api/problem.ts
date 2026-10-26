import type { components } from "./schema.gen";

/** An RFC 9457 problem from the API (contracts/api/STYLE.md §7). */
export type Problem = components["schemas"]["Problem"];
export type FieldError = components["schemas"]["FieldError"];

/**
 * Thrown for every non-2xx response. Callers switch on `code`, never on
 * `detail`: the API's English isn't shown to users. Map `code` to a
 * translation key instead.
 */
export class ApiProblem extends Error {
  readonly code: string;
  readonly status: number;
  /** Field validation errors (`validation_failed`); their `code`s map to translations too. */
  readonly errors: readonly FieldError[];
  /** Seconds from `Retry-After` on a `429`, when the server sent it. */
  readonly retryAfter: number | null;

  constructor(
    problem: Pick<Problem, "code" | "status" | "detail"> & { errors?: readonly FieldError[] },
    retryAfter: number | null = null,
  ) {
    super(problem.detail);
    this.name = "ApiProblem";
    this.code = problem.code;
    this.status = problem.status;
    this.errors = problem.errors ?? [];
    this.retryAfter = retryAfter;
  }
}

export function isProblem(value: unknown): value is Problem {
  return (
    typeof value === "object" &&
    value !== null &&
    "code" in value &&
    typeof value.code === "string" &&
    "status" in value &&
    typeof value.status === "number"
  );
}

function retryAfter(response: Response): number | null {
  const seconds = Number(response.headers.get("Retry-After") ?? Number.NaN);
  return Number.isInteger(seconds) && seconds > 0 ? seconds : null;
}

/** Turns an openapi-fetch error body into an `ApiProblem`, even when the body isn't a problem. */
export function toProblem(error: unknown, response: Response): ApiProblem {
  if (isProblem(error)) {
    const errors = Array.isArray(error.errors) ? error.errors : [];
    return new ApiProblem({ ...error, errors }, retryAfter(response));
  }
  return new ApiProblem({ code: "unexpected_response", status: response.status, detail: response.statusText });
}

/**
 * The problem in an openapi-fetch result, or `null` when it succeeded. Checks
 * the status rather than `error`, which is `undefined` for an empty error body.
 */
export function problemOf(result: { error?: unknown; response: Response }): ApiProblem | null {
  return result.response.ok ? null : toProblem(result.error, result.response);
}
