import type { ReactElement } from "react";
import { useTranslation } from "react-i18next";
import { Button } from "@/shared/ui/Button";
import { TextLink } from "@/shared/ui/TextLink";
import type { Yours } from "./data";
import { problemKey } from "./useEdit";

/**
 * What the page shows until the account's dhikrs are here: loading, a sign-in link when signed
 * out (the web edits online and signed in only), or a retry. `null` once they're ready.
 */
export function NotReady({ yours }: { yours: Yours }): ReactElement | null {
  const { t } = useTranslation();
  switch (yours.status) {
    case "loading":
      return (
        <p role="status" className="text-caption text-on-surface-variant">
          {t("library.yours.loading")}
        </p>
      );
    case "signedOut":
      return (
        <div className="flex flex-col items-start gap-sm">
          <p className="text-body text-on-surface-variant">{t("library.yours.signedOut")}</p>
          <TextLink to="/sign-in">{t("library.yours.signIn")}</TextLink>
        </div>
      );
    case "error":
      return (
        <div className="flex flex-col items-start gap-sm">
          <p className="text-body text-on-surface-variant">{t(problemKey(yours.error))}</p>
          <Button variant="secondary" size="row" onPress={yours.retry}>
            {t("library.yours.retry")}
          </Button>
        </div>
      );
    case "ready":
      return null;
  }
}
