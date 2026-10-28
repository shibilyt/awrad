import type { ReactElement } from "react";
import { Form } from "react-aria-components";
import { useTranslation } from "react-i18next";
import { Checkbox, Switch } from "@/shared/ui/Checkbox";
import { SegmentPanel, SegmentedPills } from "@/shared/ui/SegmentedPills";
import { TextField } from "@/shared/ui/TextField";
import { GallerySection, Specimen } from "./Specimen";

function Fields(): ReactElement {
  const { t } = useTranslation("gallery");
  return (
    <>
      <Specimen title={t("specimen.field")}>
        <TextField label={t("sample.name")} placeholder={t("sample.namePlaceholder")} />
        <TextField
          label={t("sample.password")}
          type="password"
          defaultValue="correct horse battery"
          description={t("sample.passwordHint")}
        />
        <TextField label={t("sample.code")} defaultValue="123456" isDisabled />
      </Specimen>
      <Specimen title={t("specimen.fieldMultiline")}>
        <TextField label={t("sample.translation")} multiline defaultValue={t("sample.translationValue")} />
        <TextField label={t("sample.arabicText")} multiline textLanguage="ar" defaultValue="سُبْحَانَ ٱللَّهِ" />
      </Specimen>
      <Specimen title={t("specimen.fieldError")}>
        <Form validationBehavior="aria" validationErrors={{ email: t("sample.emailError") }}>
          <TextField name="email" label={t("sample.email")} defaultValue={t("sample.emailValue")} />
        </Form>
      </Specimen>
    </>
  );
}

function Toggles(): ReactElement {
  const { t } = useTranslation("gallery");
  return (
    <>
      <Specimen title={t("specimen.checkbox")}>
        <div className="flex flex-col">
          <Checkbox>{t("sample.remember")}</Checkbox>
          <Checkbox defaultSelected>{t("sample.agree")}</Checkbox>
          <Checkbox isDisabled>{t("sample.locked")}</Checkbox>
          <Checkbox isDisabled defaultSelected>
            {t("sample.locked")}
          </Checkbox>
        </div>
      </Specimen>
      <Specimen title={t("specimen.switch")}>
        <div className="flex flex-col">
          <Switch>{t("sample.reminders")}</Switch>
          <Switch defaultSelected>{t("sample.sound")}</Switch>
          <Switch isDisabled>{t("sample.vibration")}</Switch>
          <Switch isDisabled defaultSelected>
            {t("sample.vibration")}
          </Switch>
        </div>
      </Specimen>
    </>
  );
}

function Pills(): ReactElement {
  const { t } = useTranslation("gallery");
  const segments = [
    { id: "active", label: t("sample.active") },
    { id: "history", label: t("sample.history") },
    { id: "archived", label: t("sample.archived") },
  ];
  return (
    <Specimen title={t("specimen.pills")}>
      <SegmentedPills
        label={t("sample.views")}
        segments={segments}
        defaultSelectedKey="active"
        disabledKeys={["archived"]}
      >
        {segments.map((segment) => (
          <SegmentPanel key={segment.id} id={segment.id}>
            <p className="text-body text-on-surface-variant">{t(`sample.${segment.id}Body`)}</p>
          </SegmentPanel>
        ))}
      </SegmentedPills>
    </Specimen>
  );
}

export function InputsSection(): ReactElement {
  const { t } = useTranslation("gallery");
  return (
    <GallerySection title={t("section.inputs")}>
      <Fields />
      <Toggles />
      <Pills />
    </GallerySection>
  );
}
