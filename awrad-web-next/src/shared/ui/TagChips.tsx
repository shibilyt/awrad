import type { ReactElement } from "react";
import { Tag, TagGroup, TagList } from "react-aria-components";
import { cx } from "./cx";
import { CheckIcon } from "./icons.gen";
import { useSecondaryFill } from "./Surface";

/**
 * A tag shown on a dhikr (components.md "Tag chip"): `chip` shape, the secondary fill
 * (`background` on a surface), `label` text, padding `sm` × `md`. Display only.
 */
export function TagChip({ children }: { children: string }): ReactElement {
  const fill = useSecondaryFill();
  return <span className={cx("inline-flex rounded-chip px-md py-xs text-label", fill)}>{children}</span>;
}

export interface FilterChip {
  id: string;
  label: string;
}

/**
 * Tag chips that filter a list: any number can be on (a React Aria tag group with multiple
 * selection, so arrow keys move between chips and Space toggles one). An off chip is a tag chip
 * a `touchTarget` tall; an on chip is `primary` with an `onPrimary` label and a leading check, and
 * the colours cross-fade (`select`), like a selected segmented pill.
 */
export function FilterChips({
  label,
  chips,
  selected,
  onChange,
}: {
  /** Names the group for screen readers. */
  label: string;
  chips: readonly FilterChip[];
  selected: readonly string[];
  onChange: (selected: string[]) => void;
}): ReactElement {
  const fill = useSecondaryFill();
  return (
    <TagGroup
      aria-label={label}
      selectionMode="multiple"
      selectedKeys={selected}
      onSelectionChange={(keys) => {
        onChange(
          keys === "all" ? chips.map((chip) => chip.id) : chips.flatMap((chip) => (keys.has(chip.id) ? [chip.id] : [])),
        );
      }}
    >
      <TagList className="flex flex-wrap gap-sm">
        {chips.map((chip) => (
          <Tag
            key={chip.id}
            id={chip.id}
            textValue={chip.label}
            className={cx(
              "inline-flex min-h-touch-target cursor-default items-center gap-xs rounded-chip px-lg text-label select-fade",
              fill,
              "data-selected:bg-primary data-selected:text-on-primary",
              "data-focus-visible:outline-focus-ring data-focus-visible:outline-offset-focus-ring data-focus-visible:outline-accent",
              "data-pressed:opacity-90 data-disabled:opacity-disabled",
            )}
          >
            {({ isSelected }) => (
              <>
                {isSelected && <CheckIcon size="small" />}
                {chip.label}
              </>
            )}
          </Tag>
        ))}
      </TagList>
    </TagGroup>
  );
}
