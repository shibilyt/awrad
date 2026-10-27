import type { ReactElement } from "react";

/** The Awrad logo (misbaha ring and Arabic mark), `logo` sized. Decorative, so screen readers skip it. */
export function LogoMark(): ReactElement {
  return (
    <picture>
      <source srcSet="/images/awrad_logo_dark.png" media="(prefers-color-scheme: dark)" />
      <img src="/images/awrad_logo_light.png" alt="" className="size-logo" />
    </picture>
  );
}
