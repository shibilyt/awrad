import { useState, type ReactElement } from "react";
import { useTranslation } from "react-i18next";
import { useLanguage } from "@/shared/i18n";
import {
  allowedOffsets,
  areValidCorrections,
  monthStart,
  nextMonth,
  offsetFor,
  withMonthOffset,
  withoutCorrection,
  type HijriCorrection,
  type PracticePolicy,
  type PracticeToday,
} from "@/shared/practice";
import { BottomSheet } from "@/shared/ui/BottomSheet";
import { Button } from "@/shared/ui/Button";
import { Card } from "@/shared/ui/Card";
import { OptionRadioGroup, OptionRow } from "@/shared/ui/OptionRow";
import { Hint, Section } from "./ChoiceSections";
import { dateText, hijriText, monthText, offsetText } from "./format";
import type { PolicyChange } from "./usePolicyEditor";

/** From this day of a month, "Adjust next month" is offered too: sightings are announced at its end. */
const NEXT_MONTH_FROM_DAY = 29;

interface Month {
  year: number;
  month: number;
}

/** "When did Jumada al-Ula 1448 start?": only the offsets that keep every month 29 or 30 days. */
function AdjustMonthSheet({
  month,
  corrections,
  onClose,
  onChange,
}: {
  month: Month | null;
  corrections: readonly HijriCorrection[];
  onClose: () => void;
  onChange: (change: PolicyChange) => void;
}): ReactElement {
  const { t } = useTranslation();
  const language = useLanguage();
  const { year, month: number } = month ?? { year: 0, month: 1 };
  const title = month === null ? "" : t("practice.hijri.sheetTitle", { month: monthText(t, year, number, language) });
  return (
    <BottomSheet
      isOpen={month !== null}
      onOpenChange={(open) => {
        if (!open) onClose();
      }}
      title={title}
    >
      {month !== null && (
        <OptionRadioGroup
          aria-label={title}
          value={String(offsetFor(corrections, year, number))}
          onChange={(value) => {
            const offset = Number(value);
            onChange((policy) => ({
              ...policy,
              hijri_corrections: withMonthOffset(policy.hijri_corrections, year, number, offset),
            }));
            onClose();
          }}
        >
          {allowedOffsets(corrections, year, number).map((offset) => (
            <OptionRow
              key={offset}
              value={String(offset)}
              label={t("practice.hijri.option", {
                offset: offsetText(t, offset),
                date: dateText(monthStart(year, number, offset) ?? "", language),
              })}
            />
          ))}
        </OptionRadioGroup>
      )}
    </BottomSheet>
  );
}

/** The corrections the account has, each removable when the rest stays valid. */
function Corrections({
  corrections,
  onChange,
}: {
  corrections: readonly HijriCorrection[];
  onChange: (change: PolicyChange) => void;
}): ReactElement {
  const { t } = useTranslation();
  const language = useLanguage();
  if (corrections.length === 0) return <Hint>{t("practice.hijri.noCorrections")}</Hint>;
  return (
    <Card padded={false}>
      <ul aria-label={t("practice.hijri.corrections")} className="flex flex-col">
        {corrections.map(({ year, month, offset_days: offset }) => {
          const name = monthText(t, year, month, language);
          const removable = areValidCorrections(withoutCorrection(corrections, year, month));
          return (
            <li key={`${String(year)}-${String(month)}`} className="flex items-center gap-lg px-card-padding py-md">
              <div className="flex min-w-0 flex-1 flex-col gap-xs">
                <p className="text-row-title">{name}</p>
                <p className="text-body-small text-on-surface-variant">{offsetText(t, offset)}</p>
              </div>
              <Button
                variant="secondary"
                size="row"
                width="label"
                isDisabled={!removable}
                aria-label={t("practice.hijri.removeNamed", { month: name })}
                onPress={() => {
                  onChange((policy) => ({
                    ...policy,
                    hijri_corrections: withoutCorrection(policy.hijri_corrections, year, month),
                  }));
                }}
              >
                {t("practice.hijri.remove")}
              </Button>
            </li>
          );
        })}
      </ul>
    </Card>
  );
}

/** Today's Hijri date, "Adjust this month" (and next, near a month's end), and the corrections made. */
export function HijriSection({
  policy,
  today,
  onChange,
}: {
  policy: PracticePolicy;
  today: PracticeToday;
  onChange: (change: PolicyChange) => void;
}): ReactElement {
  const { t } = useTranslation();
  const language = useLanguage();
  const [adjusting, setAdjusting] = useState<Month | null>(null);
  const { hijri } = today;
  const next = hijri !== null && hijri.day >= NEXT_MONTH_FROM_DAY ? nextMonth(hijri.year, hijri.month) : null;
  return (
    <Section title={t("practice.hijri.title")} intro={t("practice.hijri.intro")}>
      <Card>
        <dl className="flex flex-col gap-xs">
          <dt className="text-body-small text-on-surface-variant">{t("practice.hijri.today")}</dt>
          <dd aria-live="polite" className="text-row-title">
            {hijri === null ? t("practice.hijri.outsideTable") : hijriText(t, hijri, language)}
          </dd>
        </dl>
      </Card>
      {hijri !== null && (
        <div className="flex flex-wrap gap-row-gap">
          <Button
            variant="secondary"
            width="label"
            onPress={() => {
              setAdjusting(hijri);
            }}
          >
            {t("practice.hijri.adjustThis")}
          </Button>
          {next !== null && (
            <Button
              variant="secondary"
              width="label"
              onPress={() => {
                setAdjusting(next);
              }}
            >
              {t("practice.hijri.adjustNext", { month: monthText(t, next.year, next.month, language) })}
            </Button>
          )}
        </div>
      )}
      <Corrections corrections={policy.hijri_corrections} onChange={onChange} />
      <AdjustMonthSheet
        month={adjusting}
        corrections={policy.hijri_corrections}
        onClose={() => {
          setAdjusting(null);
        }}
        onChange={onChange}
      />
    </Section>
  );
}
