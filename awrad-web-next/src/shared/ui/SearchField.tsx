import type { ReactElement } from "react";
import { Group, Input, SearchField as AriaSearchField, type SearchFieldProps } from "react-aria-components";
import { useTranslation } from "react-i18next";
import { IconButton } from "./Button";
import { cx } from "./cx";
import { CloseIcon, SearchIcon } from "./icons.gen";
import { useFill } from "./Surface";

/**
 * A search box (the Library): a filled field like `TextField` (`control` tall, `field` shape,
 * `surface` on the page), with the `search` icon at the start and, once there's text, a clear
 * button at the end (Escape clears too). It has no visible label: `label` ("Search dhikrs") is the
 * placeholder and the accessible name. Keyboard focus rings the whole field.
 */
export function SearchField({
  label,
  ...props
}: Omit<SearchFieldProps, "children" | "className" | "aria-label"> & {
  label: string;
}): ReactElement {
  const { t } = useTranslation();
  const fill = useFill();
  return (
    <AriaSearchField {...props} aria-label={label} className="group flex flex-col data-disabled:opacity-disabled">
      <Group
        className={cx(
          "flex min-h-control items-center gap-sm rounded-field ps-lg pe-xs text-on-surface-variant",
          fill,
          "outline-none data-focus-visible:outline-focus-ring data-focus-visible:outline-offset-focus-ring",
          "data-focus-visible:outline-accent",
        )}
      >
        <SearchIcon />
        <Input
          placeholder={label}
          className="min-w-0 flex-1 bg-transparent text-input text-on-surface caret-accent outline-none placeholder:text-on-surface-variant"
        />
        <span className="group-data-empty:invisible">
          <IconButton icon={CloseIcon} aria-label={t("ui.clearSearch")} />
        </span>
      </Group>
    </AriaSearchField>
  );
}
