import { useId, type ReactElement, type ReactNode } from "react";
import { useTranslation } from "react-i18next";
import { useLanguage } from "@/shared/i18n";
import {
  CALCULATION_METHODS,
  DAY_RESETS,
  MADHABS,
  WEEK_STARTS,
  type DeviceLocation,
  type PracticePolicy,
  type PracticeToday,
} from "@/shared/practice";
import { OptionRadioGroup, OptionRow } from "@/shared/ui/OptionRow";
import { weekdayText } from "./format";
import type { PolicyChange } from "./usePolicyEditor";

/** A titled part of the page, with an optional line under its title. */
export function Section({
  title,
  intro,
  children,
}: {
  title: string;
  intro?: string;
  children: ReactNode;
}): ReactElement {
  const heading = useId();
  return (
    <section aria-labelledby={heading} className="flex flex-col gap-row-gap">
      <h2 id={heading} className="text-section-title text-on-surface">
        {title}
      </h2>
      {intro !== undefined && <p className="text-body-small text-on-surface-variant">{intro}</p>}
      {children}
    </section>
  );
}

/** A line explaining what a setting does here and now. */
export function Hint({ children }: { children: ReactNode }): ReactElement {
  return <p className="text-body-small text-on-surface-variant">{children}</p>;
}

type Setting = "day_reset" | "calculation_method" | "madhab" | "week_start";

/** One setting as option rows: choosing one sends the change at once. */
function Choice<K extends Setting>({
  label,
  setting,
  options,
  optionLabel,
  policy,
  onChange,
}: {
  label: string;
  setting: K;
  options: readonly PracticePolicy[K][];
  optionLabel: (option: PracticePolicy[K]) => string;
  policy: PracticePolicy;
  onChange: (change: PolicyChange) => void;
}): ReactElement {
  return (
    <OptionRadioGroup
      aria-label={label}
      value={policy[setting]}
      onChange={(value) => {
        const option = options.find((candidate) => candidate === value);
        if (option !== undefined) onChange((current) => ({ ...current, [setting]: option }));
      }}
    >
      {options.map((option) => (
        <OptionRow key={option} value={option} label={optionLabel(option)} />
      ))}
    </OptionRadioGroup>
  );
}

/** When the day starts, with the hint when Maghrib can't be used here today. */
export function DayResetSection({
  policy,
  location,
  today,
  onChange,
}: {
  policy: PracticePolicy;
  location: DeviceLocation | null;
  today: PracticeToday;
  onChange: (change: PolicyChange) => void;
}): ReactElement {
  const { t } = useTranslation();
  const title = t("practice.dayReset.title");
  const fallback =
    policy.day_reset !== "maghrib"
      ? null
      : location === null
        ? t("practice.dayReset.noLocation")
        : today.maghrib === null
          ? t("practice.dayReset.noMaghribToday")
          : null;
  return (
    <Section title={title}>
      <Choice
        label={title}
        setting="day_reset"
        options={DAY_RESETS}
        optionLabel={(option) => t(`practice.dayReset.${option}`)}
        policy={policy}
        onChange={onChange}
      />
      {fallback !== null && <Hint>{fallback}</Hint>}
    </Section>
  );
}

/** Calculation method, madhab and week start. */
export function CalculationSections({
  policy,
  onChange,
}: {
  policy: PracticePolicy;
  onChange: (change: PolicyChange) => void;
}): ReactElement {
  const { t } = useTranslation();
  const language = useLanguage();
  return (
    <>
      <Section title={t("practice.method.title")} intro={t("practice.method.intro")}>
        <Choice
          label={t("practice.method.title")}
          setting="calculation_method"
          options={CALCULATION_METHODS}
          optionLabel={(option) => t(`practice.method.${option}`)}
          policy={policy}
          onChange={onChange}
        />
      </Section>
      <Section title={t("practice.madhab.title")} intro={t("practice.madhab.intro")}>
        <Choice
          label={t("practice.madhab.title")}
          setting="madhab"
          options={MADHABS}
          optionLabel={(option) => t(`practice.madhab.${option}`)}
          policy={policy}
          onChange={onChange}
        />
      </Section>
      <Section title={t("practice.weekStart.title")}>
        <Choice
          label={t("practice.weekStart.title")}
          setting="week_start"
          options={WEEK_STARTS}
          optionLabel={(option) => weekdayText(option, language)}
          policy={policy}
          onChange={onChange}
        />
      </Section>
    </>
  );
}
