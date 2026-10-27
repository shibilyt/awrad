import { createLink } from "@tanstack/react-router";
import type { AnchorHTMLAttributes, ReactElement, Ref } from "react";

function StyledAnchor({
  ref,
  className,
  children,
  ...props
}: AnchorHTMLAttributes<HTMLAnchorElement> & { ref?: Ref<HTMLAnchorElement> }): ReactElement {
  return (
    <a
      ref={ref}
      {...props}
      className={[
        "focus-ring rounded-xs font-semibold text-accent underline-offset-4 hover:underline focus-visible:underline",
        className ?? "",
      ].join(" ")}
    >
      {children}
    </a>
  );
}

/** An in-app link: a real anchor (keyboard, middle-click, screen readers) with the router's typed `to`. */
export const TextLink = createLink(StyledAnchor);
