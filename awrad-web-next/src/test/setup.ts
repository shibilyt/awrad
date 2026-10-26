import "@testing-library/jest-dom/vitest";
import { cleanup, configure } from "@testing-library/react";
import i18next from "i18next";
import { setupServer } from "msw/node";
import { afterAll, afterEach, beforeAll } from "vitest";
import { setCsrfToken } from "@/shared/api/client";
import { initI18n } from "@/shared/i18n";

// Whole-app tests load route chunks lazily; give slow CI machines room.
configure({ asyncUtilTimeout: 3000 });

// jsdom doesn't implement scrolling; the router restores scroll on every navigation.
window.scrollTo = () => undefined;

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
