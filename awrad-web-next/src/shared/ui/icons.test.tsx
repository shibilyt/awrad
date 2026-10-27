import { render } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { ICONS, type IconName } from "./icons.gen";

describe("generated icons", () => {
  it("are decorative, in the text colour, on the 960 grid, icon or iconSmall sized", () => {
    for (const Icon of Object.values(ICONS)) {
      const { container, unmount } = render(<Icon />);
      const svg = container.querySelector("svg");
      expect(svg).toHaveAttribute("aria-hidden", "true");
      expect(svg).toHaveAttribute("fill", "currentColor");
      expect(svg).toHaveAttribute("viewBox", "0 -960 960 960");
      expect(svg).toHaveClass("size-icon");
      expect(svg?.querySelectorAll("path").length).toBeGreaterThan(0);
      unmount();
    }
    const { container } = render(<ICONS.check size="small" />);
    expect(container.querySelector("svg")).toHaveClass("size-icon-small");
  });

  it("only back and forward flip in right-to-left layouts", () => {
    const mirrored = (Object.keys(ICONS) as IconName[]).filter((name) => {
      const Icon = ICONS[name];
      const { container, unmount } = render(<Icon />);
      const flips = container.querySelector("svg")?.classList.contains("rtl:-scale-x-100") ?? false;
      unmount();
      return flips;
    });
    expect(mirrored).toEqual(["forward", "back"]);
  });
});
