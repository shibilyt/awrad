import { render, screen, within } from "@testing-library/react";
import i18next from "i18next";
import { beforeEach, describe, expect, it } from "vitest";
import { BottomBar } from "./BottomBar";
import { Checkbox, Switch } from "./Checkbox";
import { HomeIcon, LibraryIcon } from "./icons.gen";
import { OptionCheckboxGroup, OptionRadioGroup, OptionRow } from "./OptionRow";
import { SegmentedPills } from "./SegmentedPills";
import { FilterChips } from "./TagChips";

/**
 * Some accessibility trees don't look into the spans that hold a control's text, so every shared
 * control whose text sits in one also carries it as `aria-label`. Each test checks the role and
 * name (what the full tree computes) and the attribute (what the simplified trees read), with the
 * app's real labels in English and Arabic.
 */
const LANGUAGES = ["en", "ar"];

/** The app's text for `key` in the current language (a missing key would come back as itself). */
function t(key: string): string {
  const text = i18next.t(key);
  expect(text).not.toBe(key);
  return text;
}

function expectNamed(element: HTMLElement, name: string): void {
  expect(element).toHaveAccessibleName(name);
  expect(element).toHaveAttribute("aria-label", name);
}

describe.each(LANGUAGES)("navigation and toggles are named by their own text (%s)", (language) => {
  beforeEach(async () => {
    await i18next.changeLanguage(language);
  });

  it("the bottom bar's tabs, keeping the selected state", () => {
    render(
      <BottomBar
        label={t("nav.label")}
        selectedKey="library"
        items={[
          { id: "home", label: t("nav.home"), icon: HomeIcon, href: "/" },
          { id: "library", label: t("nav.library"), icon: LibraryIcon, href: "/library" },
        ]}
      />,
    );
    const bar = screen.getByRole("tablist", { name: t("nav.label") });
    const home = within(bar).getByRole("tab", { name: t("nav.home") });
    const library = within(bar).getByRole("tab", { name: t("nav.library") });
    expectNamed(home, t("nav.home"));
    expectNamed(library, t("nav.library"));
    expect(home).toHaveAttribute("aria-selected", "false");
    expect(library).toHaveAttribute("aria-selected", "true");
  });

  it("a checkbox and a switch, by their labels, not their values", () => {
    render(
      <>
        <Checkbox name="remember_me" value="true" defaultSelected>
          {t("account.fields.rememberMe")}
        </Checkbox>
        <Switch defaultSelected>{t("library.detail.transliteration")}</Switch>
        <Checkbox aria-label={t("library.detail.translation")}>{t("library.detail.tags")}</Checkbox>
      </>,
    );
    const checkbox = screen.getByRole("checkbox", { name: t("account.fields.rememberMe") });
    expectNamed(checkbox, t("account.fields.rememberMe"));
    expect(checkbox).toBeChecked();
    const toggle = screen.getByRole("switch", { name: t("library.detail.transliteration") });
    expectNamed(toggle, t("library.detail.transliteration"));
    expect(toggle).toBeChecked();
    // An explicit name wins.
    expectNamed(
      screen.getByRole("checkbox", { name: t("library.detail.translation") }),
      t("library.detail.translation"),
    );
  });
});

describe.each(LANGUAGES)("choices are named by their own text (%s)", (language) => {
  beforeEach(async () => {
    await i18next.changeLanguage(language);
  });

  it("option rows, as radios or checkboxes", () => {
    render(
      <>
        <OptionRadioGroup aria-label={t("app.language")} defaultValue="en">
          <OptionRow value="en" avatar="Aa" label={t("language.en")} />
          <OptionRow value="ar" label={t("language.ar")} />
        </OptionRadioGroup>
        <OptionCheckboxGroup aria-label={t("library.filter.title")} defaultValue={["quran"]}>
          <OptionRow value="quran" label={t("library.kinds.quran")} />
          <OptionRow value="dua" label={t("library.kinds.dua")} />
        </OptionCheckboxGroup>
      </>,
    );
    const english = screen.getByRole("radio", { name: t("language.en") });
    expectNamed(english, t("language.en"));
    expect(english).toBeChecked();
    expectNamed(screen.getByRole("radio", { name: t("language.ar") }), t("language.ar"));
    expectNamed(screen.getByRole("checkbox", { name: t("library.kinds.quran") }), t("library.kinds.quran"));
    expectNamed(screen.getByRole("checkbox", { name: t("library.kinds.dua") }), t("library.kinds.dua"));
  });

  it("filter chips and segmented pills, keeping their pressed and selected states", () => {
    render(
      <>
        <FilterChips
          label={t("library.filter.title")}
          chips={[
            { id: "dhikr", label: t("library.kinds.dhikr") },
            { id: "salawat", label: t("library.kinds.salawat") },
          ]}
          selected={["salawat"]}
          onChange={() => undefined}
        />
        <SegmentedPills
          label={t("library.title")}
          defaultSelectedKey="collections"
          segments={[
            { id: "collections", label: t("library.collections") },
            { id: "all", label: t("library.allDhikrs") },
          ]}
        />
      </>,
    );
    const salawat = screen.getByRole("button", { name: t("library.kinds.salawat") });
    expectNamed(salawat, t("library.kinds.salawat"));
    expect(salawat).toHaveAttribute("aria-pressed", "true");
    expect(screen.getByRole("button", { name: t("library.kinds.dhikr") })).toHaveAttribute("aria-pressed", "false");
    const collections = screen.getByRole("tab", { name: t("library.collections") });
    expectNamed(collections, t("library.collections"));
    expect(collections).toHaveAttribute("aria-selected", "true");
    expectNamed(screen.getByRole("tab", { name: t("library.allDhikrs") }), t("library.allDhikrs"));
  });
});
