import type { ReactElement, ReactNode } from "react";
import { useTranslation } from "react-i18next";
import { IconButton } from "./Button";
import { cx } from "./cx";
import { BackIcon } from "./icons";

/**
 * The bar at the top of a screen (components.md "Top bar"): `topBar` tall, `pageMargin` from the
 * edges, no fill and no divider. `start` holds an optional back button, the middle an optional
 * title (`title` style) or the step indicator, `end` up to two icon buttons or a text button.
 */
export function TopBar({
  start,
  title,
  end,
}: {
  start?: ReactNode;
  /** Shown in the middle: a title in the `title` style, or a `StepIndicator`. */
  title?: ReactNode;
  end?: ReactNode;
}): ReactElement {
  return (
    <div className="flex min-h-top-bar items-center gap-sm px-page-margin">
      <div className="flex min-w-0 flex-1 items-center justify-start">{start}</div>
      {title !== undefined && (
        <div className="flex min-w-0 shrink items-center justify-center text-title text-on-surface">{title}</div>
      )}
      <div className="flex min-w-0 flex-1 items-center justify-end gap-xs">{end}</div>
    </div>
  );
}

/** Back: an icon button with a chevron that flips in right-to-left layouts. */
export function BackButton({ onPress }: { onPress: () => void }): ReactElement {
  const { t } = useTranslation();
  return <IconButton icon={BackIcon} aria-label={t("ui.back")} onPress={onPress} />;
}

/**
 * The position in a fixed flow (onboarding): `stepDot` squares `xs` apart, done and current
 * `onSurface`, ahead `outline`. Announced once as "Step 2 of 7", not as separate dots; the
 * squares follow the reading direction, so they mirror in right-to-left layouts.
 */
export function StepIndicator({ current, total }: { current: number; total: number }): ReactElement {
  const { t } = useTranslation();
  return (
    <div role="img" aria-label={t("ui.stepOf", { current, total })} className="flex items-center gap-xs">
      {Array.from({ length: total }, (_, index) => (
        <span
          key={index}
          className={cx("size-step-dot rounded-step-dot select-fade", index < current ? "bg-on-surface" : "bg-outline")}
        />
      ))}
    </div>
  );
}
