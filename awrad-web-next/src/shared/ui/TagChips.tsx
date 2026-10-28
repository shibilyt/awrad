import type { ReactElement } from "react";
import { ToggleButton, ToggleButtonGroup } from "react-aria-components";
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
 * Chips that filter a list (components.md "Filter chip"): any number can be on. Each is a toggle
 * button named by its label (`aria-label`: the label sits in a span) that announces whether it's
 * on (`aria-pressed`), in a React Aria toggle button group (a toolbar: arrow keys move between
 * chips, Space or Enter toggles one).
 * - Off: the secondary fill (`background` on a surface) with its label colour.
 * - On: `primary` with an `onPrimary` label and a leading `check` (`iconSmall`, `inlineGap` to
 *   the label). The colours cross-fade (`select`).
 * - `chip` shape, padding `sm` × `md`, chips `sm` apart. Each sits in a `touchTarget` (48) tall
 *   touch area, so the chip itself keeps its own size. Pressed, it dims.
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
    <ToggleButtonGroup
      aria-label={label}
      selectionMode="multiple"
      selectedKeys={selected}
      onSelectionChange={(keys) => {
        onChange(chips.flatMap((chip) => (keys.has(chip.id) ? [chip.id] : [])));
      }}
      className="flex flex-wrap gap-x-sm"
    >
      {chips.map((chip) => (
        <ToggleButton
          key={chip.id}
          id={chip.id}
          aria-label={chip.label}
          className="group inline-flex min-h-touch-target cursor-default items-center outline-none data-disabled:opacity-disabled"
        >
          {({ isSelected }) => (
            <span
              className={cx(
                "inline-flex items-center gap-inline-gap rounded-chip px-md py-sm text-label select-fade",
                isSelected ? "bg-primary text-on-primary" : fill,
                "group-data-focus-visible:outline-focus-ring group-data-focus-visible:outline-offset-focus-ring",
                "group-data-focus-visible:outline-accent group-data-pressed:opacity-90",
              )}
            >
              {isSelected && <CheckIcon size="small" />}
              {chip.label}
            </span>
          )}
        </ToggleButton>
      ))}
    </ToggleButtonGroup>
  );
}
