import { useCanGoBack, useNavigate, useRouter } from "@tanstack/react-router";
import { useId, type ReactElement, type ReactNode } from "react";
import { useTranslation } from "react-i18next";
import { cx } from "@/shared/ui/cx";
import { TextLink } from "@/shared/ui/TextLink";
import { BackButton, TopBar } from "@/shared/ui/TopBar";

/**
 * A top bar with Back: to the previous page (a collection, a search), or to the Library when
 * this page was opened directly. With a `title`, the bar also shows it as the page's heading, in
 * `title`, cut off with an ellipsis when it doesn't fit; `end` is an action at the bar's end (Edit).
 */
export function BackBar({ title, end }: { title?: string; end?: ReactNode }): ReactElement {
  const router = useRouter();
  const navigate = useNavigate();
  const canGoBack = useCanGoBack();
  return (
    <TopBar
      {...(title === undefined ? {} : { title: <h1 className="truncate">{title}</h1> })}
      {...(end === undefined ? {} : { end })}
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

/**
 * A titled part of a Library page: the title in `sectionTitle` inside the page margin, with an
 * optional action (a text button) at its end.
 */
export function Section({
  title,
  action,
  children,
}: {
  title: string;
  action?: ReactNode;
  children: ReactNode;
}): ReactElement {
  const heading = useId();
  return (
    <section aria-labelledby={heading} className="flex flex-col gap-row-gap">
      <div
        className={cx(
          "flex items-center justify-between gap-md px-page-margin",
          action !== undefined && "min-h-touch-target",
        )}
      >
        <h2 id={heading} className="text-section-title text-on-surface">
          {title}
        </h2>
        {action}
      </div>
      {children}
    </section>
  );
}
