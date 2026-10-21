import "@testing-library/jest-dom/vitest";
import { cleanup } from "@testing-library/react";
import { setupServer } from "msw/node";
import { afterAll, afterEach, beforeAll } from "vitest";
import { initI18n } from "@/shared/i18n";

/** Requests no test handled fail loudly instead of reaching the network. */
export const server = setupServer();

beforeAll(async () => {
  server.listen({ onUnhandledFrame: "error" });
  await initI18n("en");
});
afterEach(() => {
  server.resetHandlers();
  cleanup();
});
afterAll(() => {
  server.close();
});
