import { screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import i18next from "i18next";
import { describe, expect, test } from "vitest";
import { recordRequests, renderRoute } from "@/test/render";
import { server } from "@/test/setup";
import { specHandler, specProblem } from "@/test/spec";
import { LANGUAGE_STORAGE_KEY, initI18n, storedLanguage } from ".";

describe("the chosen language", () => {
  test("is remembered when picked, and only the language is stored", async () => {
    server.use(specProblem("get_current_account", "unauthenticated"));
    renderRoute("/");

    await userEvent.click(await screen.findByRole("button", { name: "മലയാളം" }));

    expect(window.localStorage.getItem(LANGUAGE_STORAGE_KEY)).toBe("ml");
    expect(Object.keys(window.localStorage)).toEqual([LANGUAGE_STORAGE_KEY]);
    expect(storedLanguage()).toBe("ml");
  });

  test("survives a reload: the page starts in it, right-to-left for Arabic, and the API hears it", async () => {
    window.localStorage.setItem(LANGUAGE_STORAGE_KEY, "ar");
    await initI18n(); // what main.tsx does on load

    expect(i18next.language).toBe("ar");
    expect(document.documentElement).toHaveAttribute("lang", "ar");
    expect(document.documentElement).toHaveAttribute("dir", "rtl");

    server.use(specHandler("get_current_account", 200));
    const requests = recordRequests();
    renderRoute("/");
    expect(await screen.findByRole("heading", { name: "السلام عليكم" })).toBeInTheDocument();
    expect(requests[0]?.headers.get("Accept-Language")).toBe("ar");
  });

  test("an unknown or missing stored value falls back to English", () => {
    expect(storedLanguage()).toBeNull();
    window.localStorage.setItem(LANGUAGE_STORAGE_KEY, "xx");
    expect(storedLanguage()).toBeNull();
  });
});
