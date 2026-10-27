import type { ReactElement } from "react";
import { useTranslation } from "react-i18next";
import { Button, IconButton, RoundButton, TextButton, type ButtonVariant } from "@/shared/ui/Button";
import { Card } from "@/shared/ui/Card";
import { ArrowIcon, BellIcon, MoreIcon, PlusIcon, type Icon } from "@/shared/ui/icons";
import { BackButton } from "@/shared/ui/TopBar";
import { GallerySection, Row, Specimen, noop } from "./Specimen";

/** One variant enabled, disabled and loading. */
function Variant({
  variant,
  title,
  label,
  icon,
}: {
  variant: ButtonVariant;
  title: string;
  label: string;
  icon?: Icon;
}): ReactElement {
  const iconProps = icon === undefined ? {} : { icon };
  return (
    <Specimen title={title}>
      <Button variant={variant} {...iconProps} onPress={noop}>
        {label}
      </Button>
      <Button variant={variant} {...iconProps} isDisabled>
        {label}
      </Button>
      <Button variant={variant} {...iconProps} isPending>
        {label}
      </Button>
    </Specimen>
  );
}

function DeviceRow({ isPending = false }: { isPending?: boolean }): ReactElement {
  const { t } = useTranslation("gallery");
  return (
    <div className="flex items-center gap-lg">
      <div className="flex min-w-0 flex-1 flex-col gap-xs">
        <p className="text-row-title text-on-surface">{t("sample.device")}</p>
        <p className="text-body-small text-on-surface-variant">{t("sample.deviceDetails")}</p>
      </div>
      <Button variant="secondary" size="row" isPending={isPending} onPress={noop}>
        {t("sample.signOut")}
      </Button>
    </div>
  );
}

function SmallButtons(): ReactElement {
  const { t } = useTranslation("gallery");
  const { t: ui } = useTranslation();
  return (
    <>
      <Specimen title={t("specimen.text")}>
        <Row>
          <TextButton onPress={noop}>{t("sample.viewAll")}</TextButton>
          <TextButton isDisabled>{t("sample.viewAll")}</TextButton>
        </Row>
      </Specimen>
      <Specimen title={t("specimen.row")}>
        <Card>
          <DeviceRow />
          <DeviceRow isPending />
        </Card>
      </Specimen>
      <Specimen title={t("specimen.round")}>
        <Row>
          <RoundButton icon={PlusIcon} aria-label={t("sample.addGoal")} onPress={noop} />
          <RoundButton size="small" icon={ArrowIcon} aria-label={t("sample.openCollection")} onPress={noop} />
          <RoundButton icon={PlusIcon} aria-label={t("sample.addGoal")} isDisabled />
          <RoundButton size="small" icon={ArrowIcon} aria-label={t("sample.openCollection")} isDisabled />
        </Row>
      </Specimen>
      <Specimen title={t("specimen.icon")}>
        <Row>
          <BackButton onPress={noop} />
          <IconButton icon={MoreIcon} aria-label={ui("ui.more")} onPress={noop} />
          <IconButton icon={MoreIcon} aria-label={ui("ui.more")} isDisabled />
        </Row>
      </Specimen>
    </>
  );
}

export function ButtonsSection(): ReactElement {
  const { t } = useTranslation("gallery");
  return (
    <GallerySection title={t("section.buttons")}>
      <Variant variant="main" title={t("specimen.main")} label={t("sample.getStarted")} />
      <Variant variant="secondary" title={t("specimen.secondary")} label={t("sample.notifications")} icon={BellIcon} />
      <Variant variant="error" title={t("specimen.error")} label={t("sample.deleteAccount")} />
      <SmallButtons />
    </GallerySection>
  );
}
