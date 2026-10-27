import i18next from "i18next";
import { StrictMode, useEffect, useState, type ReactElement } from "react";
import { createRoot } from "react-dom/client";
import { useTranslation } from "react-i18next";
import { Card } from "@/shared/ui/Card";
import { Switch } from "@/shared/ui/Checkbox";
import { ButtonsSection } from "./ButtonsSection";
import { ContainersSection } from "./ContainersSection";
import { IconsSection } from "./IconsSection";
import { InputsSection } from "./InputsSection";
import ar from "./locales/ar.json";
import en from "./locales/en.json";
import ml from "./locales/ml.json";
import { NavigationSection } from "./NavigationSection";

/*
 * The component gallery (components.md): every key component in every state, in light and
 * dark, left to right and right to left (Arabic). Development builds only: main.tsx loads this
 * module behind `import.meta.env.DEV`, so neither the page nor its strings reach `dist`.
 * The sample text lives in the `gallery` namespace (./locales); component strings (aria
 * labels) are the app's own.
 */
for (const [language, strings] of Object.entries({ en, ar, ml })) {
  i18next.addResourceBundle(language, "gallery", strings);
}

type Scheme = "light" | "dark";

/** `?scheme=dark|light` picks the first scheme (for screenshots); otherwise the system's. */
function initialScheme(): Scheme {
  const asked = new URLSearchParams(window.location.search).get("scheme");
  if (asked === "light" || asked === "dark") return asked;
  return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
}

function GalleryPage(): ReactElement {
  const { t, i18n } = useTranslation("gallery");
  const [scheme, setScheme] = useState(initialScheme);

  // Forces the scheme on the whole page (colors.gen.css `data-color-scheme`).
  useEffect(() => {
    document.documentElement.dataset["colorScheme"] = scheme;
  }, [scheme]);

  return (
    <main className="mx-auto flex w-full max-w-content flex-col gap-section-gap px-page-margin py-2xl">
      <header className="flex flex-col gap-sm">
        <h1 className="text-title text-on-surface">{t("title")}</h1>
        <p className="text-body-small text-on-surface-variant">{t("intro")}</p>
      </header>
      <Card>
        <h2 className="sr-only">{t("settings")}</h2>
        <Switch
          isSelected={scheme === "dark"}
          onChange={(dark) => {
            setScheme(dark ? "dark" : "light");
          }}
        >
          {t("dark")}
        </Switch>
        <Switch isSelected={i18n.language === "ar"} onChange={(rtl) => void i18n.changeLanguage(rtl ? "ar" : "en")}>
          {t("rtl")}
        </Switch>
      </Card>
      <ContainersSection />
      <ButtonsSection />
      <InputsSection />
      <NavigationSection />
      <IconsSection />
    </main>
  );
}

/** Renders the gallery into `root`. `?dir=rtl|ltr` picks Arabic or English first. */
export async function renderGallery(root: HTMLElement): Promise<void> {
  const dir = new URLSearchParams(window.location.search).get("dir");
  if (dir === "rtl") await i18next.changeLanguage("ar");
  if (dir === "ltr") await i18next.changeLanguage("en");
  createRoot(root).render(
    <StrictMode>
      <GalleryPage />
    </StrictMode>,
  );
}
