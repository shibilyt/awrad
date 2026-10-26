import { HttpResponse, http, type HttpHandler } from "msw";
import spec from "../../../contracts/api/openapi.bundled.json";

/**
 * MSW handlers built from contracts/api/openapi.bundled.json: each mock returns
 * the spec's own example for that operation and status. A mock can't drift from
 * the contract, and a spec change that breaks the UI fails these tests.
 */
interface MediaType {
  example?: unknown;
}
interface Header {
  example?: unknown;
  $ref?: string;
}
interface Response {
  content?: Record<string, MediaType>;
  headers?: Record<string, Header>;
  $ref?: string;
}
interface Operation {
  operationId: string;
  responses: Record<string, Response>;
  "x-error-codes"?: string[];
}
interface Spec {
  paths: Record<string, Record<string, Operation>>;
  components: { responses: Record<string, Response> };
}
const document = spec as unknown as Spec;
const METHODS = { get: http.get, post: http.post, put: http.put, patch: http.patch, delete: http.delete } as const;

function resolve<T extends { $ref?: string }>(node: T): T {
  if (node.$ref === undefined) return node;
  const path = node.$ref.replace(/^#\//, "").split("/");
  return path.reduce<unknown>((child, key) => (child as Record<string, unknown>)[key], spec) as T;
}

function find(operationId: string): { path: string; method: keyof typeof METHODS; operation: Operation } {
  for (const [path, item] of Object.entries(document.paths)) {
    for (const [method, operation] of Object.entries(item)) {
      if (operation.operationId === operationId && method in METHODS) {
        return { path, method: method as keyof typeof METHODS, operation };
      }
    }
  }
  throw new Error(`operationId ${operationId} isn't in the spec`);
}

/** The documented response headers that have examples (`Retry-After`, `x-request-id`, …). */
function exampleHeaders(response: Response): Record<string, string> {
  const headers: Record<string, string> = {};
  for (const [name, header] of Object.entries(response.headers ?? {})) {
    const example = resolve(header).example;
    if (typeof example === "string" || typeof example === "number") headers[name] = String(example);
  }
  return headers;
}

interface Options {
  /** Answer only the first matching request (to script a sequence of responses). */
  once?: boolean;
}

function handler(operationId: string, status: number, response: Response, body: unknown, options: Options) {
  const { path, method } = find(operationId);
  const [contentType] = Object.keys(response.content ?? {});
  const headers = {
    ...exampleHeaders(response),
    ...(contentType === undefined ? {} : { "Content-Type": contentType }),
  };
  const resolver = () =>
    body === undefined
      ? new HttpResponse(null, { status, headers })
      : HttpResponse.json(body as Record<string, unknown>, { status, headers });
  // Absolute URL: in Node, MSW doesn't resolve relative paths against the page.
  const url = new URL(path, window.location.origin).href;
  return METHODS[method](url, resolver, { once: options.once ?? false });
}

/** A handler answering `operationId` with the spec's example for `status` (an empty body when it has none). */
export function specHandler(operationId: string, status: number, options: Options = {}): HttpHandler {
  const declared = find(operationId).operation.responses[String(status)];
  if (declared === undefined) throw new Error(`${operationId}: status ${String(status)} isn't documented`);
  const response = resolve(declared);
  const media = Object.values(response.content ?? {})[0];
  if (media !== undefined && media.example === undefined) {
    throw new Error(`${operationId} ${String(status)}: the spec has no example to mock with`);
  }
  return handler(operationId, status, response, media?.example, options);
}

function problemExample(response: Response): { code?: unknown; status?: unknown } | undefined {
  return Object.values(resolve(response).content ?? {})[0]?.example as { code?: unknown; status?: unknown } | undefined;
}

/**
 * A handler answering `operationId` with the problem `code`. The code must be in
 * the operation's `x-error-codes`, and the example comes from the operation's own
 * responses or, when a status is shared by several codes (`403`), from the
 * spec's shared response for that code, at a status the operation documents.
 */
export function specProblem(operationId: string, code: string, options: Options = {}): HttpHandler {
  const { operation } = find(operationId);
  if (!(operation["x-error-codes"] ?? []).includes(code)) {
    throw new Error(`${operationId}: ${code} isn't in its x-error-codes`);
  }
  const candidates = [...Object.values(operation.responses), ...Object.values(document.components.responses)];
  for (const candidate of candidates) {
    const example = problemExample(candidate);
    if (example?.code === code && typeof example.status === "number" && String(example.status) in operation.responses) {
      return handler(operationId, example.status, resolve(candidate), example, options);
    }
  }
  throw new Error(`${operationId}: the spec has no example for ${code}`);
}
