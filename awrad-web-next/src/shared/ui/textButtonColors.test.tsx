import { render, screen, within } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import colors from "../../../../contracts/design-tokens/v1/colors.json";
import { TextButton } from "./Button";
import { ChoiceDialog } from "./ConfirmDialog";

type Scheme = "light" | "dark";

const ROLES: Record<string, Record<Scheme, string> | undefined> = colors.roles;

/** `on-secondary-container` (a class's role) → `onSecondaryContainer` (colors.json's). */
function camel(role: string): string {
  return role.replace(/-([a-z])/g, (_, letter: string) => letter.toUpperCase());
}

/** A colour role's value in one scheme (colors.json, which colors.gen.css is generated from). */
function roleColor(role: string, scheme: Scheme): string {
  const value = ROLES[camel(role)]?.[scheme];
  if (value === undefined) throw new Error(`no ${scheme} colour for ${role}`);
  return value;
}

/** The colour role a Tailwind `prefix-<role>` class on the element names (`text-accent` → `accent`). */
function roleOf(element: Element | null, prefix: "text" | "bg"): string {
  const roles = (element?.className.split(/\s+/) ?? [])
    .filter((name) => name.startsWith(`${prefix}-`))
    .map((name) => name.slice(prefix.length + 1))
    .filter((role) => ROLES[camel(role)] !== undefined);
  const [role] = roles;
  if (roles.length !== 1 || role === undefined)
    throw new Error(`expected one ${prefix} colour role, got ${String(roles)}`);
  return role;
}

describe("text button colours (components.md: on a fill, the fill's paired content colour)", () => {
  it("conflict banner: Keep mine and Use theirs differ from the secondaryContainer fill in dark and light mode", () => {
    render(
      <ChoiceDialog
        isOpen
        title="Changed on another device"
        first={{ label: "Keep mine", onPress: () => undefined }}
        second={{ label: "Use theirs", onPress: () => undefined }}
      >
        <p>Changed elsewhere.</p>
      </ChoiceDialog>,
    );
    const dialog = screen.getByRole("alertdialog", { name: "Changed on another device" });
    const fill = roleOf(dialog.closest(".rounded-card"), "bg");
    expect(fill).toBe("secondary-container");
    for (const name of ["Keep mine", "Use theirs"]) {
      const label = roleOf(within(dialog).getByRole("button", { name }), "text");
      expect(label).toBe("on-secondary-container");
      expect(roleColor(label, "dark")).not.toBe(roleColor(fill, "dark"));
      expect(roleColor(label, "light")).not.toBe(roleColor(fill, "light"));
    }
  });

  it("the accent the banner used to have is the fill's own colour in dark mode", () => {
    expect(roleColor("accent", "dark")).toBe(roleColor("secondary-container", "dark"));
  });

  it("is accent with no fill, and onPrimary on a primary fill", () => {
    render(
      <>
        <TextButton>View all</TextButton>
        <TextButton on="primary">Undo</TextButton>
      </>,
    );
    expect(roleOf(screen.getByRole("button", { name: "View all" }), "text")).toBe("accent");
    const onPrimary = roleOf(screen.getByRole("button", { name: "Undo" }), "text");
    expect(onPrimary).toBe("on-primary");
    expect(roleColor(onPrimary, "dark")).not.toBe(roleColor("primary", "dark"));
  });
});
