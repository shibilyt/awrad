import { useState, type ReactElement } from "react";
import { useTranslation } from "react-i18next";
import { useLanguage } from "@/shared/i18n";
import { readBrowserLocation, type DeviceLocation, type PracticeToday } from "@/shared/practice";
import { Button } from "@/shared/ui/Button";
import { Card } from "@/shared/ui/Card";
import { FormAlert } from "@/shared/ui/FormAlert";
import { LocationIcon } from "@/shared/ui/icons.gen";
import { Section } from "./ChoiceSections";
import { CitySearchSheet } from "./CitySearchSheet";
import { locationText, timeText } from "./format";

/** `GeolocationPositionError.PERMISSION_DENIED`: the person or the browser said no. */
const PERMISSION_DENIED = 1;

/** One row of the location card: a label over its value. */
function Fact({ label, value }: { label: string; value: string }): ReactElement {
  return (
    <div className="flex flex-col gap-xs">
      <dt className="text-body-small text-on-surface-variant">{label}</dt>
      <dd className="text-row-title">{value}</dd>
    </div>
  );
}

/** The place, and today's Maghrib there (or why there's none). */
function Place({
  location,
  today,
  timeZone,
}: {
  location: DeviceLocation | null;
  today: PracticeToday;
  timeZone: string;
}): ReactElement {
  const { t } = useTranslation();
  const language = useLanguage();
  const place =
    location === null
      ? t("practice.location.none")
      : location.source === "gps"
        ? t("practice.location.current", { place: locationText(t, location, language) })
        : locationText(t, location, language);
  const maghrib =
    location === null
      ? t("practice.location.maghribNeedsPlace")
      : today.maghrib === null
        ? t("practice.location.noMaghrib")
        : timeText(today.maghrib, timeZone, language);
  return (
    <Card>
      <dl aria-live="polite" className="flex flex-col gap-row-gap">
        <Fact label={t("practice.location.place")} value={place} />
        <Fact label={t("practice.location.maghrib")} value={maghrib} />
      </dl>
    </Card>
  );
}

/**
 * Where this browser is, for Maghrib: "Use my location" (one coarse reading) or a city from the
 * bundled list. It stays in this browser (device context) and is never sent to the server.
 */
export function LocationSection({
  location,
  onLocation,
  today,
  timeZone,
}: {
  location: DeviceLocation | null;
  onLocation: (location: DeviceLocation | null) => void;
  today: PracticeToday;
  timeZone: string;
}): ReactElement {
  const { t } = useTranslation();
  const [locating, setLocating] = useState(false);
  const [alert, setAlert] = useState<string | null>(null);
  const [searching, setSearching] = useState(false);

  const locate = async (): Promise<void> => {
    setAlert(null);
    setLocating(true);
    try {
      onLocation(await readBrowserLocation());
    } catch (error) {
      const denied = (error as Partial<GeolocationPositionError> | null)?.code === PERMISSION_DENIED;
      setAlert(t(denied ? "practice.location.denied" : "practice.location.unavailable"));
    } finally {
      setLocating(false);
    }
  };

  return (
    <Section title={t("practice.location.title")} intro={t("practice.location.intro")}>
      <Place location={location} today={today} timeZone={timeZone} />
      <FormAlert message={alert} />
      <div className="flex flex-wrap gap-row-gap">
        <Button
          variant="secondary"
          width="label"
          icon={LocationIcon}
          isPending={locating}
          onPress={() => void locate()}
        >
          {t("practice.location.useMine")}
        </Button>
        <Button
          variant="secondary"
          width="label"
          onPress={() => {
            setAlert(null);
            setSearching(true);
          }}
        >
          {t("practice.location.chooseCity")}
        </Button>
        {location !== null && (
          <Button
            variant="secondary"
            width="label"
            onPress={() => {
              setAlert(null);
              onLocation(null);
            }}
          >
            {t("practice.location.remove")}
          </Button>
        )}
      </div>
      <CitySearchSheet isOpen={searching} onOpenChange={setSearching} onChoose={onLocation} />
    </Section>
  );
}
