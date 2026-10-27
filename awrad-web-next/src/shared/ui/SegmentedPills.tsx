import type { ReactElement, ReactNode } from "react";
import { Tab, TabList, TabPanel, Tabs, type TabPanelProps, type TabsProps } from "react-aria-components";
import { cx } from "./cx";
import { useSecondaryFill } from "./Surface";

export interface Segment {
  id: string;
  label: string;
}

/**
 * Two to four mutually exclusive views (Active / History), announced as tabs (components.md
 * "Segmented pills"). Pills are `chip` shaped, `touchTarget` tall, `sm` apart; the selected one
 * is `primary` with a `tabIndicator` bar `xs` under it, the others `secondaryContainer`. The web
 * cross-fades the colours (`select`) instead of moving the fill and bar. Put a `SegmentPanel`
 * per segment in `children`.
 */
export function SegmentedPills({
  label,
  segments,
  children,
  ...props
}: Pick<TabsProps, "selectedKey" | "defaultSelectedKey" | "onSelectionChange" | "isDisabled" | "disabledKeys"> & {
  /** Names the tab list for screen readers. */
  label: string;
  segments: Segment[];
  children?: ReactNode;
}): ReactElement {
  const fill = useSecondaryFill();
  return (
    <Tabs {...props} className="flex flex-col gap-lg">
      <TabList aria-label={label} items={segments} className="flex flex-wrap gap-sm">
        {(segment) => (
          <Tab
            id={segment.id}
            className="group flex cursor-default flex-col items-center gap-xs outline-none data-disabled:opacity-disabled"
          >
            <span
              className={cx(
                "flex min-h-touch-target items-center rounded-chip px-lg text-button select-fade",
                fill,
                "group-data-selected:bg-primary group-data-selected:text-on-primary group-data-pressed:opacity-90",
                "group-data-focus-visible:outline-focus-ring group-data-focus-visible:outline-offset-focus-ring",
                "group-data-focus-visible:outline-accent",
              )}
            >
              {segment.label}
            </span>
            <span
              aria-hidden="true"
              className="h-tab-indicator-height w-tab-indicator-width rounded-tab-indicator select-fade group-data-selected:bg-primary"
            />
          </Tab>
        )}
      </TabList>
      {children}
    </Tabs>
  );
}

/** The content for one segment, shown while its pill is selected. */
export function SegmentPanel(props: Omit<TabPanelProps, "className" | "style">): ReactElement {
  return <TabPanel {...props} className="focus-ring rounded-xs" />;
}
