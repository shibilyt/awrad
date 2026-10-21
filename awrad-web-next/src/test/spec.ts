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
interface Response {
  content?: Record<string, MediaType>;
  $ref?: string;
}
interface Operation {
  operationId: string;
  responses: Record<string, Response>;
}
interface Spec {
  paths: Record<string, Record<string, Operation>>;
}
const document = spec as unknown as Spec;

function resolve(response: Response): Response {
  if (response.$ref === undefined) return response;
  const path = response.$ref.replace(/^#\//, "").split("/");
  return path.reduce<unknown>((node, key) => (node as Record<string, unknown>)[key], spec) as Response;
}

function find(operationId: string): { path: string; method: string; operation: Operation } {
  for (const [path, item] of Object.entries(document.paths)) {
    for (const [method, operation] of Object.entries(item)) {
      if (operation.operationId === operationId) return { path, method, operation };
    }
  }
  throw new Error(`operationId ${operationId} isn't in the spec`);
}

/** A handler answering `operationId` with the spec's example for `status`. */
export function specHandler(operationId: string, status: number): HttpHandler {
  const { path, method, operation } = find(operationId);
  const declared = operation.responses[String(status)];
  if (declared === undefined) throw new Error(`${operationId}: status ${String(status)} isn't documented`);
  const [contentType, media] = Object.entries(resolve(declared).content ?? {})[0] ?? [];
  if (contentType === undefined || media?.example === undefined) {
    throw new Error(`${operationId} ${String(status)}: the spec has no example to mock with`);
  }
  const resolver = () =>
    HttpResponse.json(media.example as Record<string, unknown>, { status, headers: { "Content-Type": contentType } });
  // Absolute URL: in Node, MSW doesn't resolve relative paths against the page.
  const url = new URL(path, window.location.origin).href;
  return method === "get" ? http.get(url, resolver) : http.all(url, resolver);
}
