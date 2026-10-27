import { useCanGoBack, useNavigate, useRouter } from "@tanstack/react-router";
import type { ReactElement } from "react";
import { useTranslation } from "react-i18next";
import { TextLink } from "@/shared/ui/TextLink";
import { BackButton, TopBar } from "@/shared/ui/TopBar";

/**
 * A top bar with Back: to the previous page (a collection, a search), or to the Library when
 * this page was opened directly. With a `title`, the bar also shows it as the page's heading, in
 * `title`, cut off with an ellipsis when it doesn't fit.
 */
export function BackBar({ title }: { title?: string }): ReactElement {
  const router = useRouter();
  const navigate = useNavigate();
  const canGoBack = useCanGoBack();
  return (
    <TopBar
      {...(title === undefined ? {} : { title: <h1 className="truncate">{title}</h1> })}
      start={
        <BackButton
          onPress={() => {
            if (canGoBack) router.history.back();
            else void navigate({ to: "/library" });
          }}
        />
      }
    />
  );
}

/** A collection or dhikr key the catalog doesn't have (an old or mistyped link). */
export function NotFound({ message }: { message: string }): ReactElement {
  const { t } = useTranslation();
  return (
    <main className="mx-auto flex w-full max-w-content flex-col">
      <BackBar />
      <div className="flex flex-col items-center gap-2xl px-page-margin py-5xl text-center">
        <h1 className="text-title text-on-surface">{t("library.notFound.title")}</h1>
        <p className="text-on-surface-variant">{message}</p>
        <TextLink to="/library">{t("library.notFound.back")}</TextLink>
      </div>
    </main>
  );
}
