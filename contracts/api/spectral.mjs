// Spectral ruleset: contracts/api/STYLE.md as automated checks (ADR-2026-10-16).
// Every rule names the STYLE.md section it enforces. Run `npm test` in contracts/.
import { oas } from "@stoplight/spectral-rulesets";
import { defined, falsy, pattern, truthy } from "@stoplight/spectral-functions";

const SNAKE = "^[a-z][a-z0-9_]*$";
const COORDINATES = new Set(["latitude", "longitude"]);
const ANY_OPERATION = "$.paths[*][get,put,post,patch,delete,options,head,trace]";
const ANY_RESPONSE = `${ANY_OPERATION}.responses[*]`;

/** Yields [schema, path] for an object schema and every nested object schema. */
function* objectSchemas(schema, path, seen = new Set()) {
  if (!schema || typeof schema !== "object" || seen.has(schema)) return;
  seen.add(schema);
  if (schema.type === "object" || schema.properties) yield [schema, path];
  for (const [key, child] of Object.entries(schema.properties ?? {})) {
    yield* objectSchemas(child, [...path, "properties", key], seen);
  }
  if (schema.items) yield* objectSchemas(schema.items, [...path, "items"], seen);
  for (const combinator of ["allOf", "oneOf", "anyOf"]) {
    for (const [i, child] of (schema[combinator] ?? []).entries()) {
      yield* objectSchemas(child, [...path, combinator, i], seen);
    }
  }
}

/** Yields [schema, path, propertyName] for every schema node with a scalar type. */
function* typedSchemas(schema, path, name = null, seen = new Set()) {
  if (!schema || typeof schema !== "object" || seen.has(schema)) return;
  seen.add(schema);
  if (schema.type) yield [schema, path, name];
  for (const [key, child] of Object.entries(schema.properties ?? {})) {
    yield* typedSchemas(child, [...path, "properties", key], key, seen);
  }
  if (schema.items) yield* typedSchemas(schema.items, [...path, "items"], name, seen);
  for (const combinator of ["allOf", "oneOf", "anyOf"]) {
    for (const [i, child] of (schema[combinator] ?? []).entries()) {
      yield* typedSchemas(child, [...path, combinator, i], name, seen);
    }
  }
}

/** STYLE §12: request bodies reject unknown fields. */
function requestBodyClosed(schema, _opts, { path }) {
  const results = [];
  for (const [object, at] of objectSchemas(schema, path)) {
    if (object.additionalProperties !== false) {
      results.push({ message: "Request object schemas must set additionalProperties: false", path: at });
    }
  }
  return results;
}

/** STYLE §3: response fields are always present (null for no value). */
function responseFieldsRequired(schema, _opts, { path }) {
  const results = [];
  for (const [object, at] of objectSchemas(schema, path)) {
    const required = new Set(object.required ?? []);
    for (const key of Object.keys(object.properties ?? {})) {
      if (!required.has(key)) {
        results.push({ message: `Response field "${key}" must be listed in required`, path: [...at, "properties", key] });
      }
    }
  }
  return results;
}

/** STYLE §5: integers are bounded; only coordinates are fractional. */
function numbersFollowStyle(schema, _opts, { path }) {
  const results = [];
  for (const [node, at, name] of typedSchemas(schema, path)) {
    const types = [node.type].flat();
    if (types.includes("number") && !COORDINATES.has(name)) {
      results.push({ message: `"${name ?? "value"}" is fractional; only latitude/longitude may use type number`, path: at });
    }
    if (types.includes("integer") && (node.minimum === undefined || node.maximum === undefined)) {
      results.push({ message: "Integer schemas must declare minimum and maximum", path: at });
    }
  }
  return results;
}

/** STYLE §8: a list response carries next_cursor next to items. */
function listsHaveCursor(schema, _opts, { path }) {
  const results = [];
  for (const [object, at] of objectSchemas(schema, path)) {
    const items = object.properties?.items;
    if (items?.type === "array" && !object.properties?.next_cursor) {
      results.push({ message: "List responses with items must also define next_cursor", path: at });
    }
  }
  return results;
}

/** STYLE §7, §15: an operation with 4xx responses lists its error codes in x-error-codes. */
function documentsErrorCodes(operation) {
  const statuses = Object.keys(operation?.responses ?? {});
  if (statuses.some((status) => /^4/.test(status)) && !Array.isArray(operation["x-error-codes"])) {
    return [{ message: "Operations with 4xx responses must list their error codes in x-error-codes" }];
  }
  return [];
}

/** STYLE §15: every JSON request or response body has an example. */
function hasExample(media) {
  if (!media || media.example !== undefined || media.examples !== undefined) return [];
  return [{ message: "Request and response bodies must include an example" }];
}

/** STYLE §7: error responses use problem+json; success bodies use application/json. */
function contentTypeForStatus(response, _opts, { path }) {
  const status = String(path[path.length - 1]);
  const types = Object.keys(response?.content ?? {});
  if (/^[45]/.test(status)) {
    if (!types.includes("application/problem+json") || types.length !== 1) {
      return [{ message: `${status} responses must use only application/problem+json` }];
    }
  } else if (types.some((type) => type !== "application/json")) {
    return [{ message: `${status} responses must use application/json` }];
  }
  return [];
}

export default {
  extends: [[oas, "recommended"]],
  rules: {
    // The spec stays free of contact details; ownership is the repo.
    "info-contact": "off",
    // Shared components (Count, Cursor, Problem responses…) exist before the
    // slices that use them; unused ones are expected while the API grows.
    "oas3-unused-component": "off",

    "awrad-paths-under-api-v1": {
      description: "STYLE §1: every HTTP path starts with /api/v1/.",
      given: "$.paths",
      severity: "error",
      then: { field: "@key", function: pattern, functionOptions: { match: "^/api/v1/" } },
    },
    "awrad-path-segments": {
      description: "STYLE §1: snake_case segments; path parameters are snake_case and never just {id}.",
      given: "$.paths",
      severity: "error",
      then: {
        field: "@key",
        function: pattern,
        functionOptions: { match: "^(/([a-z][a-z0-9_]*|\\{(?!id\\})[a-z][a-z0-9_]*\\}))+$" },
      },
    },
    "awrad-no-patch": {
      description: "STYLE §2: PATCH isn't used; replace whole documents with PUT and expected_revision.",
      given: "$.paths[*]",
      severity: "error",
      then: { field: "patch", function: falsy },
    },
    "awrad-operation-id-snake-case": {
      description: "STYLE §3: operationIds are snake_case.",
      given: ANY_OPERATION,
      severity: "error",
      then: { field: "operationId", function: pattern, functionOptions: { match: SNAKE } },
    },
    "awrad-property-names-snake-case": {
      description: "STYLE §3: field names are snake_case.",
      given: "$..properties",
      severity: "error",
      then: { field: "@key", function: pattern, functionOptions: { match: SNAKE } },
    },
    "awrad-enum-values-snake-case": {
      description: "STYLE §3: enum values are lowercase snake_case strings.",
      given: "$..enum[*]",
      severity: "error",
      then: { function: pattern, functionOptions: { match: SNAKE } },
    },
    "awrad-security-declared": {
      description: "STYLE §11: every operation declares its auth schemes (an empty list for public).",
      given: ANY_OPERATION,
      severity: "error",
      then: { field: "security", function: defined },
    },
    "awrad-error-codes-documented": {
      description: "STYLE §7: operations list the error codes clients must handle.",
      given: ANY_OPERATION,
      severity: "error",
      then: { function: documentsErrorCodes },
    },
    "awrad-idempotency-key-on-post": {
      description: "STYLE §10: every POST accepts Idempotency-Key.",
      given: "$.paths[*].post",
      severity: "error",
      then: {
        field: "parameters",
        function: (parameters) =>
          (parameters ?? []).some((p) => p?.name === "Idempotency-Key" && p?.in === "header")
            ? []
            : [{ message: "POST operations must accept the Idempotency-Key header" }],
      },
    },
    "awrad-response-content-type": {
      description: "STYLE §7: errors are application/problem+json; success bodies application/json.",
      given: ANY_RESPONSE,
      severity: "error",
      then: { function: contentTypeForStatus },
    },
    "awrad-cache-control-declared": {
      description: "STYLE §12: every response declares Cache-Control.",
      given: ANY_RESPONSE,
      severity: "error",
      then: { field: "headers.Cache-Control", function: truthy },
    },
    "awrad-request-id-declared": {
      description: "STYLE §12: every response declares x-request-id.",
      given: ANY_RESPONSE,
      severity: "error",
      then: { field: "headers.x-request-id", function: truthy },
    },
    "awrad-examples-present": {
      description: "STYLE §15: request and response bodies carry examples.",
      given: [`${ANY_OPERATION}.requestBody.content[*]`, `${ANY_RESPONSE}.content[*]`],
      severity: "error",
      then: { function: hasExample },
    },
    "awrad-request-unknown-fields-rejected": {
      description: "STYLE §12: request object schemas set additionalProperties: false.",
      given: `${ANY_OPERATION}.requestBody.content[*].schema`,
      severity: "error",
      then: { function: requestBodyClosed },
    },
    "awrad-response-fields-always-present": {
      description: "STYLE §3: every response property is required (null for no value).",
      given: `${ANY_RESPONSE}.content['application/json'].schema`,
      severity: "error",
      then: { function: responseFieldsRequired },
    },
    "awrad-numbers": {
      description: "STYLE §5: bounded integers; only coordinates are fractional.",
      given: [
        `${ANY_OPERATION}.requestBody.content[*].schema`,
        `${ANY_RESPONSE}.content[*].schema`,
        `${ANY_OPERATION}.parameters[*].schema`,
      ],
      severity: "error",
      then: { function: numbersFollowStyle },
    },
    "awrad-lists-have-cursor": {
      description: "STYLE §8: list responses are {items, next_cursor}.",
      given: `${ANY_RESPONSE}.content['application/json'].schema`,
      severity: "error",
      then: { function: listsHaveCursor },
    },
  },
};
