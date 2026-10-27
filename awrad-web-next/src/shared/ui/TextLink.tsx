import { createLink } from "@tanstack/react-router";
import type { AnchorHTMLAttributes, ReactElement, Ref } from "react";
import { TEXT_BUTTON } from "./Button";
import { cx } from "./cx";

type AnchorProps = AnchorHTMLAttributes<HTMLAnchorElement> & { ref?: Ref<HTMLAnchorElement> };

function StyledAnchor({ ref, className, children, ...props }: AnchorProps): ReactElement {
  return (
    <a
      ref={ref}
      {...props}
      className={cx(
        "focus-ring rounded-xs font-semibold text-accent underline-offset-4 hover:underline focus-visible:underline",
        className,
      )}
    >
      {children}
    </a>
  );
}

/** An in-app link: a real anchor (keyboard, middle-click, screen readers) with the router's typed `to`. */
export const TextLink = createLink(StyledAnchor);

function TextButtonAnchor({ ref, className, children, ...props }: AnchorProps): ReactElement {
  return (
    <a ref={ref} {...props} className={cx(TEXT_BUTTON, "active:opacity-90", className)}>
      {children}
    </a>
  );
}

/** A text button (components.md, "View All") that goes to another page: a real anchor, styled as `TextButton`. */
export const TextButtonLink = createLink(TextButtonAnchor);
