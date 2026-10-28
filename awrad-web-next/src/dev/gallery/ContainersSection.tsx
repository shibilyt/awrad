import { useState, type ReactElement } from "react";
import { useTranslation } from "react-i18next";
import { BottomSheet } from "@/shared/ui/BottomSheet";
import { Button } from "@/shared/ui/Button";
import { Card, ClickableCard, ContentSheet, ContentSheetSection } from "@/shared/ui/Card";
import { ChoiceDialog, ConfirmDialog, NoticeDialog } from "@/shared/ui/ConfirmDialog";
import { OptionCheckboxGroup, OptionRadioGroup, OptionRow } from "@/shared/ui/OptionRow";
import { GallerySection, Specimen, noop } from "./Specimen";

/** A goal with its progress: sample content for cards. */
export function GoalRow({ title, done, total }: { title: string; done: number; total: number }): ReactElement {
  const { t } = useTranslation("gallery");
  return (
    <div className="flex items-center justify-between gap-md">
      <span className="text-row-title text-on-surface">{title}</span>
      <span className="text-body-small text-on-surface-variant">{t("sample.progress", { done, total })}</span>
    </div>
  );
}

function Cards(): ReactElement {
  const { t } = useTranslation("gallery");
  return (
    <>
      <Specimen title={t("specimen.card")}>
        <Card>
          <h4 className="text-card-title text-on-surface">{t("sample.todaysGoals")}</h4>
          <GoalRow title={t("sample.morningAdhkar")} done={33} total={100} />
          <GoalRow title={t("sample.eveningAdhkar")} done={0} total={100} />
        </Card>
      </Specimen>
      <Specimen title={t("specimen.tile")}>
        <Card shape="tile">
          <GoalRow title={t("sample.salawat")} done={70} total={100} />
        </Card>
      </Specimen>
      <Specimen title={t("specimen.clickable")}>
        <ClickableCard shape="tile" onPress={noop}>
          <GoalRow title={t("sample.istighfar")} done={12} total={100} />
        </ClickableCard>
        <ClickableCard shape="tile" isDisabled>
          <GoalRow title={t("sample.istighfar")} done={12} total={100} />
        </ClickableCard>
      </Specimen>
      <Specimen title={t("specimen.contentSheet")}>
        <ContentSheet>
          <ContentSheetSection title={t("sample.todaysGoals")}>
            <Card shape="tile">
              <GoalRow title={t("sample.morningAdhkar")} done={33} total={100} />
            </Card>
            <Card shape="tile">
              <GoalRow title={t("sample.salawat")} done={70} total={100} />
            </Card>
          </ContentSheetSection>
        </ContentSheet>
      </Specimen>
    </>
  );
}

function SheetDemo(): ReactElement {
  const { t } = useTranslation("gallery");
  const [isOpen, setOpen] = useState(false);
  const [time, setTime] = useState("morning");
  return (
    <Specimen title={t("specimen.bottomSheet")}>
      <Button
        variant="secondary"
        onPress={() => {
          setOpen(true);
        }}
      >
        {t("sample.openSheet")}
      </Button>
      <BottomSheet isOpen={isOpen} onOpenChange={setOpen} title={t("sample.sheetTitle")}>
        <OptionRadioGroup aria-label={t("sample.reminderTimes")} value={time} onChange={setTime}>
          <OptionRow value="morning" label={t("sample.morning")} />
          <OptionRow value="evening" label={t("sample.evening")} />
          <OptionRow value="night" label={t("sample.night")} />
        </OptionRadioGroup>
        <Button
          onPress={() => {
            setOpen(false);
          }}
        >
          {t("sample.done")}
        </Button>
      </BottomSheet>
    </Specimen>
  );
}

function DialogDemo(): ReactElement {
  const { t } = useTranslation("gallery");
  const [isOpen, setOpen] = useState(false);
  return (
    <Specimen title={t("specimen.dialog")}>
      <Button
        variant="secondary"
        onPress={() => {
          setOpen(true);
        }}
      >
        {t("sample.openDialog")}
      </Button>
      <ConfirmDialog
        isOpen={isOpen}
        onOpenChange={setOpen}
        title={t("sample.dialogTitle")}
        confirmLabel={t("sample.delete")}
        cancelLabel={t("sample.cancel")}
        onConfirm={() => {
          setOpen(false);
        }}
      >
        <p>{t("sample.dialogBody")}</p>
      </ConfirmDialog>
    </Specimen>
  );
}

function ChoiceDemo(): ReactElement {
  const { t } = useTranslation("gallery");
  const [isOpen, setOpen] = useState(false);
  const close = () => {
    setOpen(false);
  };
  return (
    <Specimen title={t("specimen.choiceDialog")}>
      <Button
        variant="secondary"
        onPress={() => {
          setOpen(true);
        }}
      >
        {t("sample.openDialog")}
      </Button>
      <ChoiceDialog
        isOpen={isOpen}
        title={t("sample.choiceTitle")}
        first={{ label: t("sample.keepMine"), onPress: close }}
        second={{ label: t("sample.useTheirs"), onPress: close }}
      >
        <p>{t("sample.choiceBody")}</p>
      </ChoiceDialog>
    </Specimen>
  );
}

function NoticeDemo(): ReactElement {
  const { t } = useTranslation("gallery");
  const [isOpen, setOpen] = useState(false);
  return (
    <Specimen title={t("specimen.noticeDialog")}>
      <Button
        variant="secondary"
        onPress={() => {
          setOpen(true);
        }}
      >
        {t("sample.openDialog")}
      </Button>
      <NoticeDialog
        isOpen={isOpen}
        onClose={() => {
          setOpen(false);
        }}
        title={t("sample.noticeTitle")}
        closeLabel={t("sample.ok")}
      >
        <p>{t("sample.noticeBody")}</p>
      </NoticeDialog>
    </Specimen>
  );
}

function Options(): ReactElement {
  const { t } = useTranslation("gallery");
  return (
    <>
      <Specimen title={t("specimen.optionSingle")}>
        <OptionRadioGroup aria-label={t("sample.language")} defaultValue="en">
          <OptionRow value="en" avatar="Aa" label={t("sample.english")} />
          <OptionRow value="ar" avatar="ع" label={t("sample.arabic")} />
          <OptionRow value="ml" avatar="അ" label={t("sample.malayalam")} isDisabled />
        </OptionRadioGroup>
      </Specimen>
      <Specimen title={t("specimen.optionMultiple")}>
        <OptionCheckboxGroup aria-label={t("sample.reminderTimes")} defaultValue={["morning", "evening"]}>
          <OptionRow value="morning" label={t("sample.morning")} />
          <OptionRow value="evening" label={t("sample.evening")} />
          <OptionRow value="night" label={t("sample.night")} />
        </OptionCheckboxGroup>
      </Specimen>
    </>
  );
}

export function ContainersSection(): ReactElement {
  const { t } = useTranslation("gallery");
  return (
    <GallerySection title={t("section.containers")}>
      <Cards />
      <SheetDemo />
      <DialogDemo />
      <ChoiceDemo />
      <NoticeDemo />
      <Options />
    </GallerySection>
  );
}
