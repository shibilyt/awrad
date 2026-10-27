import type { ReactElement, ReactNode } from "react";
import { Tab, TabList, TabPanel, Tabs, type TabPanelProps, type TabsProps } from "react-aria-components";
import { cx } from "./cx";
import type { Icon } from "./icons.gen";

export interface BottomBarItem {
  id: string;
  label: string;
  icon: Icon;
}

/**
 * The floating main navigation (components.md "Bottom bar"): Home, Goals, Library, Community,
 * announced as a tab bar with each item's selected state. `navBar` tall, `surfaceBar`, the
 * `navBar` shape and the `floating` shadow (none in dark), `pageMargin` inside the side safe areas
 * and `lg` above the bottom one (`bottom-bar-offset`). From `contentMaxWidth` up it stays that wide, centred. Items are
 * equal widths: the icon over the label, `onSurfaceVariant`; the selected one has a
 * `primaryContainer` pill behind an `onPrimaryContainer` icon and an `accent` label. The icon is
 * the same outline icon selected or not (`home`, `goals`, `library`, `community` from
 * icons.gen.tsx): the pill shows the selection. On the web the pill and colours cross-fade
 * (`select`); nothing grows, pops or moves.
 *
 * Put the content in `BottomBarPanel`s (`children`): they're padded so their end clears the bar.
 */
export function BottomBar({
  label,
  items,
  children,
  ...props
}: Pick<TabsProps, "selectedKey" | "defaultSelectedKey" | "onSelectionChange" | "disabledKeys"> & {
  /** Names the tab bar for screen readers. */
  label: string;
  items: BottomBarItem[];
  children?: ReactNode;
}): ReactElement {
  return (
    <Tabs {...props} className="flex flex-col">
      {/* The list comes first (React Aria gives the panels its ids); it floats, so the order doesn't show. */}
      <TabList
        aria-label={label}
        items={items}
        className={cx(
          "fixed bottom-bar-offset z-10 mx-auto flex h-nav-bar max-w-content items-stretch",
          "rounded-nav-bar bg-surface-bar px-sm shadow-floating",
        )}
      >
        {(item) => (
          <Tab
            id={item.id}
            className={cx(
              "group flex min-w-0 flex-1 cursor-default flex-col items-center justify-center gap-xs rounded-tile",
              "outline-none data-focus-visible:outline-focus-ring data-focus-visible:outline-offset-focus-ring",
              "data-focus-visible:outline-accent data-pressed:opacity-90 data-disabled:opacity-disabled",
            )}
          >
            <span
              className={cx(
                "flex h-nav-pill-height w-nav-pill-width items-center justify-center rounded-nav-pill select-fade",
                "text-on-surface-variant group-data-selected:bg-primary-container",
                "group-data-selected:text-on-primary-container",
              )}
            >
              <item.icon size="icon" />
            </span>
            <span className="max-w-full truncate text-nav-label text-on-surface-variant select-fade group-data-selected:text-accent">
              {item.label}
            </span>
          </Tab>
        )}
      </TabList>
      {children}
    </Tabs>
  );
}

/**
 * One tab's content, padded at the end so its last item scrolls clear of the floating bar. The
 * bottom safe area comes from the page frame (AppShell's `safe-area-bottom`).
 */
export function BottomBarPanel(props: Omit<TabPanelProps, "className" | "style">): ReactElement {
  return <TabPanel {...props} className="bottom-bar-clearance focus-ring" />;
}
