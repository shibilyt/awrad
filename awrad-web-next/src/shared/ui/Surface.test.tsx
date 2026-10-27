import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { Card } from "./Card";
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
        <OnSurface>
          <TextField label="Card field" />
        </OnSurface>
      </>,
    );

    expect(classesOf(screen.getByRole("textbox", { name: "Page field" }))).toContain("bg-surface");
    expect(classesOf(screen.getByRole("textbox", { name: "Card field" }))).toContain("bg-background");
  });

  it("cards alternate: surface on the page, background inside a surface area, and their content follows", () => {
    render(
      <>
        <Card>
          <TextField label="In a card" />
        </Card>
        <OnSurface>
          <Card>
            <TextField label="In a card on the sheet" />
          </Card>
        </OnSurface>
      </>,
    );

    const inCard = screen.getByRole("textbox", { name: "In a card" });
    const onSheet = screen.getByRole("textbox", { name: "In a card on the sheet" });
    expect(classesOf(inCard)).toContain("bg-background");
    expect(classesOf(onSheet)).toContain("bg-surface");
    expect(inCard.closest(".rounded-card")).toHaveClass("bg-surface");
    expect(onSheet.closest(".rounded-card")).toHaveClass("bg-background");
  });

  it("draw no visible line at rest, and the error stroke only when invalid", () => {
    render(
      <>
        <TextField label="Fine" />
        <TextField label="Wrong" isInvalid />
      </>,
    );

    const fine = screen.getByRole("textbox", { name: "Fine" });
    const wrong = screen.getByRole("textbox", { name: "Wrong" });
    expect(classesOf(fine)).toEqual(expect.arrayContaining(["border-field-error", "border-transparent"]));
    expect(classesOf(fine).filter((c) => /^(border-outline|ring-|focus-visible:)/.test(c))).toEqual([]);
    expect(wrong).toHaveAttribute("data-invalid", "true");
    expect(classesOf(wrong)).toContain("data-invalid:border-error");
  });
});
