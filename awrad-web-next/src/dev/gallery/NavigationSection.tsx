import type { ReactElement } from "react";
import { useTranslation } from "react-i18next";
import { BottomBar, BottomBarPanel, type BottomBarItem } from "@/shared/ui/BottomBar";
import { IconButton, RoundButton, TextButton } from "@/shared/ui/Button";
import { Card, ContentSheet, ContentSheetSection } from "@/shared/ui/Card";
import { CommunityIcon, GoalsIcon, HomeIcon, LibraryIcon, MoreIcon, AddIcon } from "@/shared/ui/icons.gen";
import { LargeTitleHeader } from "@/shared/ui/LargeTitleHeader";
import { SegmentedPills } from "@/shared/ui/SegmentedPills";
import { BackButton, StepIndicator, TopBar } from "@/shared/ui/TopBar";
import { GoalRow } from "./ContainersSection";
import { GallerySection, Specimen, noop } from "./Specimen";

function TopBars(): ReactElement {
  const { t } = useTranslation("gallery");
  const { t: ui } = useTranslation();
  return (
    <>
      <Specimen title={t("specimen.topBar")}>
        <div className="-mx-page-margin flex flex-col gap-sm">
          <TopBar
            start={<BackButton onPress={noop} />}
            title={t("sample.myGoals")}
            end={<IconButton icon={MoreIcon} aria-label={ui("ui.more")} onPress={noop} />}
          />
          <TopBar start={<BackButton onPress={noop} />} title={<StepIndicator current={2} total={7} />} />
          <TopBar title={t("sample.onboarding")} end={<TextButton onPress={noop}>{t("sample.viewAll")}</TextButton>} />
        </div>
      </Specimen>
      <Specimen title={t("specimen.steps")}>
        <div className="flex flex-col gap-md">
          <StepIndicator current={1} total={7} />
          <StepIndicator current={2} total={7} />
          <StepIndicator current={7} total={7} />
        </div>
      </Specimen>
    </>
  );
}

/** A screen-sized frame that scrolls: the large title goes, and the compact bar fades in. */
function LargeTitleFrame(): ReactElement {
  const { t } = useTranslation("gallery");
  const goals = [t("sample.morningAdhkar"), t("sample.eveningAdhkar"), t("sample.salawat"), t("sample.istighfar")];
  return (
    <Specimen title={t("specimen.largeTitle")}>
      <div className="relative -mx-page-margin contain-layout">
        <div className="flex aspect-square flex-col overflow-y-auto bg-background pt-lg">
          <LargeTitleHeader
            title={t("sample.myGoals")}
            action={<RoundButton icon={AddIcon} aria-label={t("sample.addGoal")} onPress={noop} />}
          />
          <div className="px-page-margin pb-lg">
            <SegmentedPills
              label={t("sample.views")}
              segments={[
                { id: "active", label: t("sample.active") },
                { id: "history", label: t("sample.history") },
              ]}
            />
          </div>
          <ContentSheet>
            <ContentSheetSection title={t("sample.todaysGoals")}>
              {[...goals, ...goals].map((goal, index) => (
                <Card key={index} shape="tile">
                  <GoalRow title={goal} done={index * 10} total={100} />
                </Card>
              ))}
            </ContentSheetSection>
          </ContentSheet>
        </div>
      </div>
    </Specimen>
  );
}

/** The bottom bar floats at the bottom of this frame (layout containment makes it the bar's box). */
function BottomBarFrame(): ReactElement {
  const { t } = useTranslation("gallery");
  const items: BottomBarItem[] = [
    { id: "home", label: t("sample.home"), icon: HomeIcon },
    { id: "goals", label: t("sample.goals"), icon: GoalsIcon },
    { id: "library", label: t("sample.library"), icon: LibraryIcon },
    { id: "community", label: t("sample.community"), icon: CommunityIcon },
  ];
  return (
    <Specimen title={t("specimen.bottomBar")}>
      <div className="relative -mx-page-margin aspect-square overflow-hidden contain-layout">
        <BottomBar label={t("sample.mainNavigation")} items={items} defaultSelectedKey="goals">
          {items.map((item) => (
            <BottomBarPanel key={item.id} id={item.id}>
              <div className="flex flex-col gap-row-gap px-page-margin pt-lg">
                <Card>
                  <h4 className="text-card-title text-on-surface">{item.label}</h4>
                  <p className="text-body text-on-surface-variant">{t(`sample.${item.id}Body`)}</p>
                </Card>
                <Card shape="tile">
                  <GoalRow title={t("sample.morningAdhkar")} done={33} total={100} />
                </Card>
              </div>
            </BottomBarPanel>
          ))}
        </BottomBar>
      </div>
    </Specimen>
  );
}

export function NavigationSection(): ReactElement {
  const { t } = useTranslation("gallery");
  return (
    <GallerySection title={t("section.navigation")}>
      <TopBars />
      <LargeTitleFrame />
      <BottomBarFrame />
    </GallerySection>
  );
}
