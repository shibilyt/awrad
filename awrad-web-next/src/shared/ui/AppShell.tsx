import { useRouterState } from "@tanstack/react-router";
import type { ReactElement, ReactNode } from "react";
import { useTranslation } from "react-i18next";
import { BottomBar, BottomBarPanel, type BottomBarItem } from "./BottomBar";
import { HomeIcon, LibraryIcon } from "./icons.gen";
import { LanguagePicker } from "./LanguagePicker";
import { TextLink } from "./TextLink";
import { TopBar } from "./TopBar";

/** The main tab a path belongs to: the Library and its pages, or Home for everything else. */
export function mainTabOf(pathname: string): "home" | "library" {
  return pathname === "/library" || pathname.startsWith("/library/") ? "library" : "home";
}

/**
 * The frame around every page: a top bar with the app name (home) and the language picker, the
 * page, and the floating bottom bar (Home, Library), whose items are links. It pads everything by
 * the safe-area insets (index.html has `viewport-fit=cover`), so nothing sits under a notch or the
 * home indicator; the page is padded to clear the bar.
 */
export function AppShell({ children }: { children: ReactNode }): ReactElement {
  const { t } = useTranslation();
  const selected = mainTabOf(useRouterState({ select: (state) => state.location.pathname }));
  const items: BottomBarItem[] = [
    { id: "home", label: t("nav.home"), icon: HomeIcon, href: "/" },
    { id: "library", label: t("nav.library"), icon: LibraryIcon, href: "/library" },
  ];
  return (
    <div className="flex min-h-dvh flex-col safe-area-x safe-area-top safe-area-bottom">
      <header>
        <TopBar
          start={
            <TextLink to="/" className="text-card-title">
              {t("app.name")}
            </TextLink>
          }
          end={<LanguagePicker />}
        />
      </header>
      <BottomBar label={t("nav.label")} items={items} selectedKey={selected}>
        <div className="page-transition flex flex-col">
          <BottomBarPanel id={selected}>{children}</BottomBarPanel>
        </div>
      </BottomBar>
    </div>
  );
}
