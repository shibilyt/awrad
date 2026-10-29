import { afterEach, describe, expect, it, vi } from "vitest";
import { guardViewTransitions } from "./viewTransitions";

/** Vitest runs on Node, whose process reports promise rejections nobody handled; the app types exclude Node. */
interface NodeProcess {
  on: (event: "unhandledRejection", listener: () => void) => void;
  off: (event: "unhandledRejection", listener: () => void) => void;
}
const nodeProcess = (globalThis as unknown as { process: NodeProcess }).process;

const original = Object.getOwnPropertyDescriptor(document, "startViewTransition");

afterEach(() => {
  if (original) Object.defineProperty(document, "startViewTransition", original);
  else Reflect.deleteProperty(document, "startViewTransition");
  vi.restoreAllMocks();
});

function abortedTransition(): ViewTransition {
  const abort = (): Promise<undefined> =>
    Promise.reject(new DOMException("Transition was aborted because of invalid state", "InvalidStateError"));
  return {
    ready: abort(),
    finished: abort(),
    updateCallbackDone: Promise.resolve(undefined),
    skipTransition: vi.fn(),
    types: new Set<string>(),
  };
}

describe("guardViewTransitions", () => {
  it("lets an aborted transition's ready and finished rejections go unnoticed", async () => {
    const unhandled = vi.fn();
    nodeProcess.on("unhandledRejection", unhandled);
    try {
      const start = vi.fn(abortedTransition);
      Object.defineProperty(document, "startViewTransition", { value: start, configurable: true, writable: true });
      guardViewTransitions();

      const update = vi.fn();
      const started = document.startViewTransition(update);
      await new Promise((resolve) => setTimeout(resolve, 20));

      expect(start).toHaveBeenCalledWith(update);
      await expect(started.updateCallbackDone).resolves.toBeUndefined();
      expect(unhandled).not.toHaveBeenCalled();
    } finally {
      nodeProcess.off("unhandledRejection", unhandled);
    }
  });

  it("wraps only once and does nothing in a browser without the API", () => {
    Object.defineProperty(document, "startViewTransition", {
      value: vi.fn(abortedTransition),
      configurable: true,
      writable: true,
    });
    guardViewTransitions();
    const wrapped: unknown = Reflect.get(document, "startViewTransition");
    guardViewTransitions();
    expect(Reflect.get(document, "startViewTransition")).toBe(wrapped);

    Reflect.deleteProperty(document, "startViewTransition");
    expect(() => {
      guardViewTransitions();
    }).not.toThrow();
  });
});
