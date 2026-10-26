import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { SecondaryButton } from "./Button";
import { OnSurface } from "./Surface";
import { TextField } from "./TextField";

function classesOf(element: HTMLElement): string[] {
  return element.className.split(/\s+/);
}

describe("filled controls (no outlines)", () => {
  it("fill with surface on the page and with background on a card", () => {
    render(
      <>
        <TextField label="Page field" />
        <SecondaryButton>Page button</SecondaryButton>
        <OnSurface>
          <TextField label="Card field" />
          <SecondaryButton>Card button</SecondaryButton>
        </OnSurface>
      </>,
    );

    expect(classesOf(screen.getByRole("textbox", { name: "Page field" }))).toContain("bg-surface");
    expect(classesOf(screen.getByRole("button", { name: "Page button" }))).toContain("bg-surface");
    expect(classesOf(screen.getByRole("textbox", { name: "Card field" }))).toContain("bg-background");
    expect(classesOf(screen.getByRole("button", { name: "Card button" }))).toContain("bg-background");
  });

  it("draw no visible border at rest, and an error border only when invalid", () => {
    render(
      <>
        <TextField label="Fine" />
        <TextField label="Wrong" isInvalid />
      </>,
    );

    const fine = screen.getByRole("textbox", { name: "Fine" });
    const wrong = screen.getByRole("textbox", { name: "Wrong" });
    expect(classesOf(fine)).toContain("border-transparent");
    expect(classesOf(fine).filter((c) => /^(border-outline|ring-|focus-visible:)/.test(c))).toEqual([]);
    expect(wrong).toHaveAttribute("data-invalid", "true");
    expect(classesOf(wrong)).toContain("data-invalid:border-error");
  });
});
