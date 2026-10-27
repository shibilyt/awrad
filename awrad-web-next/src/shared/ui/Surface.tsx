import { createContext, useContext, type ReactElement, type ReactNode } from "react";

/** What a control sits on: the page (`background`) or a card (`surface`). */
type Container = "background" | "surface";

const ContainerContext = createContext<Container>("background");

/**
 * Marks its children as sitting on a `surface` card (a list, a dialog), so
 * fields, secondary buttons and pills inside fill with `background` instead.
 */
export function OnSurface({ children }: { children: ReactNode }): ReactElement {
  return <ContainerContext value="surface">{children}</ContainerContext>;
}

/** Marks its children as sitting on `background` again: a card inside a `surface` area. */
export function OnBackground({ children }: { children: ReactNode }): ReactElement {
  return <ContainerContext value="background">{children}</ContainerContext>;
}

/**
 * The fill for a field, card or unselected pill. The design has no outlines, so
 * these are filled shapes: `surface` on the page, `background` on a card.
 */
export function useFill(): "bg-surface" | "bg-background" {
  return useContext(ContainerContext) === "surface" ? "bg-background" : "bg-surface";
}

/**
 * The fill and content colours for a secondary button, an unselected option row or pill:
 * `secondaryContainer` (components.md), except on a `surface` card, where it would vanish
 * (light `secondaryContainer` is the `surface` colour), so it's `background` there, like a field.
 * `surfaceBar` (dialogs, sheets) counts as the page.
 */
export function useSecondaryFill():
  "bg-secondary-container text-on-secondary-container" | "bg-background text-on-surface" {
  return useContext(ContainerContext) === "surface"
    ? "bg-background text-on-surface"
    : "bg-secondary-container text-on-secondary-container";
}

/** Gives children the container a fill makes: `surface` for `bg-surface`, `background` for `bg-background`. */
export function Inside({
  fill,
  children,
}: {
  fill: "bg-surface" | "bg-background";
  children: ReactNode;
}): ReactElement {
  return fill === "bg-surface" ? <OnSurface>{children}</OnSurface> : <OnBackground>{children}</OnBackground>;
}
