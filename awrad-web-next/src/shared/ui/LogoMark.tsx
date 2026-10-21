import type { ReactElement } from "react";

/** The Awrad logo (misbaha ring and Arabic mark). Decorative, so screen readers skip it. */
export function LogoMark({ size = 148 }: { size?: number }): ReactElement {
  return (
    <picture>
      <source srcSet="/images/awrad_logo_dark.png" media="(prefers-color-scheme: dark)" />
      <img src="/images/awrad_logo_light.png" alt="" width={size} height={size} />
    </picture>
  );
}
