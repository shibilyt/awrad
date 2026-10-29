import "@testing-library/jest-dom/vitest";
import { cleanup, configure } from "@testing-library/react";
import i18next from "i18next";
import { setupServer } from "msw/node";
import { afterAll, afterEach, beforeAll } from "vitest";
import { setCsrfToken } from "@/shared/api/client";
import { initI18n } from "@/shared/i18n";

// Whole-app tests load route chunks lazily; give slow CI machines room.
configure({ asyncUtilTimeout: 3000 });

// jsdom doesn't implement scrolling; the router restores scroll on every navigation, and a
// failed editor save scrolls to its first error.
window.scrollTo = () => undefined;
Element.prototype.scrollIntoView = () => undefined;

// jsdom never loads media, so a picked recording's length can't be read from it: without object
// URLs, measuring gives up at once (`duration_ms: null`) instead of after its timeout.
// file.test.ts puts one back to test the measurement.
Object.defineProperty(URL, "createObjectURL", { value: undefined, configurable: true, writable: true });

/** Requests no test handled fail loudly instead of reaching the network. */
export const server = setupServer();

beforeAll(async () => {
  server.listen({ onUnhandledFrame: "error" });
  await initI18n("en");
});
afterEach(async () => {
  server.resetHandlers();
  server.events.removeAllListeners();
  cleanup();
  setCsrfToken(null);
  await i18next.changeLanguage("en");
  window.localStorage.clear();
});
afterAll(() => {
  server.close();
});
