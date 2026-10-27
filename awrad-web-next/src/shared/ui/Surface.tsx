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

/**
 * The fill for a field, secondary button or unselected pill. The design has no
 * outlines, so these are filled shapes: `surface` on the page, `background` on a card.
 */
export function useFill(): "bg-surface" | "bg-background" {
  return useContext(ContainerContext) === "surface" ? "bg-background" : "bg-surface";
}
