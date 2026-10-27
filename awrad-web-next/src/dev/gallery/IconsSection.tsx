import type { ReactElement } from "react";
import { useTranslation } from "react-i18next";
import { Card } from "@/shared/ui/Card";
import { ICONS, type IconName } from "@/shared/ui/icons.gen";
import { GallerySection, Specimen } from "./Specimen";

/** Every icon in icons.gen.tsx, `icon` sized in `onSurface`, under its shared name. */
export function IconsSection(): ReactElement {
  const { t } = useTranslation("gallery");
  const names = Object.keys(ICONS) as IconName[];
  return (
    <GallerySection title={t("section.icons")}>
      <Specimen title={t("specimen.icons")}>
        <Card>
          <ul className="grid grid-cols-3 gap-row-gap">
            {names.map((name) => {
              const Icon = ICONS[name];
              return (
                <li key={name} className="flex min-w-0 flex-col items-center gap-xs text-on-surface">
                  <Icon />
                  <span className="max-w-full truncate text-caption text-on-surface-variant">{name}</span>
                </li>
              );
            })}
          </ul>
        </Card>
      </Specimen>
    </GallerySection>
  );
}
