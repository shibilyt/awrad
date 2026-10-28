import {
  RouterProvider,
  createMemoryHistory,
  createRootRoute,
  createRouter,
  type LinkProps,
} from "@tanstack/react-router";
import { useState, type MouseEvent, type ReactElement } from "react";
import { useTranslation } from "react-i18next";
import { Card } from "@/shared/ui/Card";
import { CollectionTile } from "@/shared/ui/CollectionTile";
import { SearchField } from "@/shared/ui/SearchField";
import { FilterChips, TagChip } from "@/shared/ui/TagChips";
import { GallerySection, Specimen } from "./Specimen";

/** The gallery only shows the tiles; following one would leave the gallery. */
function stay(event: MouseEvent): void {
  event.preventDefault();
}

const COLLECTION: LinkProps = { to: "/library/collections/$key", params: { key: "daily-essentials" } };

function Tiles(): ReactElement {
  const { t } = useTranslation("gallery");
  const { t: ui } = useTranslation();
  const tiles = (
    <ul className="flex gap-md overflow-x-auto">
      <li className="flex">
        <CollectionTile
          {...COLLECTION}
          onClick={stay}
          heading={t("sample.dailyEssentials")}
          count={ui("library.dhikrCount", { count: 4 })}
        />
      </li>
      <li className="flex">
        <CollectionTile
          {...COLLECTION}
          onClick={stay}
          heading={t("sample.asmaUlHusna")}
          count={ui("library.dhikrCount", { count: 100 })}
        />
      </li>
      <li className="flex">
        <CollectionTile
          {...COLLECTION}
          onClick={stay}
          heading={t("sample.longCollection")}
          count={ui("library.dhikrCount", { count: 1 })}
        />
      </li>
    </ul>
  );
  return (
    <>
      <Specimen title={t("specimen.collectionTile")}>{tiles}</Specimen>
      <Specimen title={t("specimen.collectionTileOnCard")}>
        <Card>{tiles}</Card>
      </Specimen>
    </>
  );
}

function SearchFields(): ReactElement {
  const { t } = useTranslation("gallery");
  const [query, setQuery] = useState("");
  const [filled, setFilled] = useState(t("sample.searchValue"));
  return (
    <Specimen title={t("specimen.searchField")}>
      <SearchField label={t("sample.searchLabel")} value={query} onChange={setQuery} />
      <SearchField label={t("sample.searchLabel")} value={filled} onChange={setFilled} />
      <SearchField label={t("sample.searchLabel")} isDisabled />
    </Specimen>
  );
}

function Chips(): ReactElement {
  const { t } = useTranslation("gallery");
  const [selected, setSelected] = useState(["morning"]);
  const chips = [
    { id: "morning", label: t("sample.morningAdhkar") },
    { id: "evening", label: t("sample.eveningAdhkar") },
    { id: "salawat", label: t("sample.salawat") },
  ];
  const tags = (
    <ul className="flex flex-wrap gap-sm">
      {chips.map((chip) => (
        <li key={chip.id}>
          <TagChip>{chip.label}</TagChip>
        </li>
      ))}
    </ul>
  );
  return (
    <>
      <Specimen title={t("specimen.tagChips")}>
        {tags}
        <Card>{tags}</Card>
      </Specimen>
      <Specimen title={t("specimen.filterChips")}>
        <FilterChips label={t("sample.filter")} chips={chips} selected={selected} onChange={setSelected} />
      </Specimen>
    </>
  );
}

function LibrarySpecimens(): ReactElement {
  return (
    <div className="flex flex-col gap-section-gap">
      <Tiles />
      <SearchFields />
      <Chips />
    </div>
  );
}

/** Collection tiles are router links, so they render inside a router of their own here. */
const router = createRouter({
  routeTree: createRootRoute({ component: LibrarySpecimens }),
  history: createMemoryHistory({ initialEntries: ["/"] }),
});

export function LibrarySection(): ReactElement {
  const { t } = useTranslation("gallery");
  return (
    <GallerySection title={t("section.library")}>
      <RouterProvider router={router} />
    </GallerySection>
  );
}
