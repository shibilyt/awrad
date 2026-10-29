import { useQuery } from "@tanstack/react-query";
import { useState, type ReactElement } from "react";
import { Button as AriaButton } from "react-aria-components";
import { useTranslation } from "react-i18next";
import { useLanguage } from "@/shared/i18n";
import { loadCities, searchCities, type City, type DeviceLocation } from "@/shared/practice";
import { BottomSheet } from "@/shared/ui/BottomSheet";
import { Button, TextButton } from "@/shared/ui/Button";
import { cx } from "@/shared/ui/cx";
import { FormAlert } from "@/shared/ui/FormAlert";
import { SearchField } from "@/shared/ui/SearchField";
import { useSecondaryFill } from "@/shared/ui/Surface";
import { countryText } from "./format";

/** The bundled list never changes while the page is open: loaded once, its own chunk. */
const citiesQuery = { queryKey: ["places", "cities"], queryFn: loadCities, staleTime: Infinity, retry: false };

const RESULTS = 20;

/** A city as the browser's location: its name and coordinates, and its GeoNames ID. */
function asLocation(city: City): DeviceLocation {
  return { latitude: city.latitude, longitude: city.longitude, name: city.name, source: "city", city_id: city.id };
}

function CityResult({ city, onChoose }: { city: City; onChoose: (city: City) => void }): ReactElement {
  const language = useLanguage();
  const fill = useSecondaryFill();
  const where = [city.region, countryText(city.country, language)].filter((part) => part !== null).join(", ");
  return (
    <li>
      <AriaButton
        onPress={() => {
          onChoose(city);
        }}
        aria-label={`${city.name}, ${where}`}
        className={cx(
          "flex min-h-list-row w-full flex-col items-start justify-center gap-xxs rounded-tile px-md py-sm text-start",
          fill,
          "focus-ring data-pressed:opacity-90",
        )}
      >
        <span className="text-row-title">{city.name}</span>
        <span className="text-caption">{where}</span>
      </AriaButton>
    </li>
  );
}

/** What the list finds for the query, with the list's attribution under it. */
function Results({ query, onChoose }: { query: string; onChoose: (city: City) => void }): ReactElement {
  const { t } = useTranslation();
  const list = useQuery(citiesQuery);
  if (list.isError) {
    return (
      <>
        <FormAlert message={t("practice.location.searchFailed")} />
        <Button variant="secondary" onPress={() => void list.refetch()}>
          {t("practice.retry")}
        </Button>
      </>
    );
  }
  if (list.data === undefined) return <p role="status">{t("practice.location.searchLoading")}</p>;
  const found = searchCities(list.data.cities, query, RESULTS);
  return (
    <>
      {query.trim() !== "" && found.length === 0 && <p role="status">{t("practice.location.noResults", { query })}</p>}
      {found.length > 0 && (
        <ul aria-label={t("practice.location.results")} className="flex flex-col gap-row-gap">
          {found.map((city) => (
            <CityResult key={city.id} city={city} onChoose={onChoose} />
          ))}
        </ul>
      )}
      <p className="text-caption text-on-surface-variant" dir="ltr">
        {list.data.attribution}
      </p>
    </>
  );
}

/** "Choose a city": the bundled list, searched as you type, in a bottom sheet. */
export function CitySearchSheet({
  isOpen,
  onOpenChange,
  onChoose,
}: {
  isOpen: boolean;
  onOpenChange: (isOpen: boolean) => void;
  onChoose: (location: DeviceLocation) => void;
}): ReactElement {
  const { t } = useTranslation();
  const [query, setQuery] = useState("");
  return (
    <BottomSheet isOpen={isOpen} onOpenChange={onOpenChange} title={t("practice.location.searchTitle")}>
      <SearchField
        label={t("practice.location.searchLabel")}
        value={query}
        onChange={setQuery}
        // The sheet exists to search; the field is the first thing to use.
        // eslint-disable-next-line jsx-a11y/no-autofocus
        autoFocus
      />
      <Results
        query={query}
        onChoose={(city) => {
          onChoose(asLocation(city));
          onOpenChange(false);
        }}
      />
      <div className="flex justify-end">
        <TextButton
          onPress={() => {
            onOpenChange(false);
          }}
        >
          {t("practice.close")}
        </TextButton>
      </div>
    </BottomSheet>
  );
}
