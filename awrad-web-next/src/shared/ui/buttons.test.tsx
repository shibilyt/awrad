import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";
import { Button, IconButton, RoundButton, TextButton } from "./Button";
import { Card, ClickableCard } from "./Card";
import { MoreIcon, AddIcon } from "./icons.gen";
import { BackButton } from "./TopBar";

describe("Button", () => {
  it("is a button filled by variant, control tall and full width; row buttons are touch-target tall", () => {
    render(
      <>
        <Button>Main</Button>
        <Button variant="secondary">Secondary</Button>
        <Button variant="error">Error</Button>
        <Button variant="secondary" size="row">
          Row
        </Button>
      </>,
    );
    expect(screen.getByRole("button", { name: "Main" })).toHaveClass(
      "bg-primary",
      "text-on-primary",
      "min-h-control",
      "w-full",
    );
    expect(screen.getByRole("button", { name: "Secondary" })).toHaveClass("bg-secondary-container");
    expect(screen.getByRole("button", { name: "Error" })).toHaveClass("bg-error", "text-on-error");
    const row = screen.getByRole("button", { name: "Row" });
    expect(row).toHaveClass("min-h-touch-target");
    expect(row).not.toHaveClass("w-full");
  });

  it("fills a secondary button with background on a surface card, where secondaryContainer would vanish", () => {
    render(
      <Card>
        <Button variant="secondary">On a card</Button>
      </Card>,
    );
    expect(screen.getByRole("button", { name: "On a card" })).toHaveClass("bg-background", "text-on-surface");
  });

  it("disabled: ignores presses and is drawn at the disabled opacity", async () => {
    const onPress = vi.fn();
    render(
      <Button isDisabled onPress={onPress}>
        Continue
      </Button>,
    );
    const button = screen.getByRole("button", { name: "Continue" });
    expect(button).toBeDisabled();
    expect(button).toHaveClass("disabled:opacity-disabled", "focus-ring");
    await userEvent.click(button);
    expect(onPress).not.toHaveBeenCalled();
  });

  it("loading: keeps its label and size, shows a progress bar, ignores presses, isn't disabled", async () => {
    const onPress = vi.fn();
    render(
      <Button isPending onPress={onPress}>
        Save
      </Button>,
    );
    const button = screen.getByRole("button", { name: /Save/ });
    expect(button).not.toBeDisabled();
    expect(button).toHaveAttribute("aria-disabled", "true");
    expect(screen.getByRole("progressbar", { name: "Loading" })).toBeInTheDocument();
    expect(screen.getByText("Save")).toHaveClass("opacity-0");
    await userEvent.click(button);
    expect(onPress).not.toHaveBeenCalled();
  });

  it("puts a leading icon before the label, hidden from screen readers", () => {
    render(<Button icon={AddIcon}>Add</Button>);
    const button = screen.getByRole("button", { name: "Add" });
    expect(button.querySelector("svg")).toHaveAttribute("aria-hidden", "true");
  });

  it("is named by its text label itself (aria-label), not only through the wrapper span; an explicit name wins", () => {
    render(
      <>
        <Button type="submit">Sign in</Button>
        <Button isPending>Save</Button>
        <Button aria-label="Remove the Qur'an reference">Remove</Button>
      </>,
    );
    expect(screen.getByRole("button", { name: "Sign in" })).toHaveAttribute("aria-label", "Sign in");
    expect(screen.getByRole("button", { name: "Save Loading" })).toHaveAttribute("aria-label", "Save");
    expect(screen.getByRole("button", { name: "Remove the Qur'an reference" })).toBeInTheDocument();
  });
});

describe("text, round and icon buttons", () => {
  it("text button: accent, label style, touch-target tall", () => {
    render(<TextButton>View all</TextButton>);
    expect(screen.getByRole("button", { name: "View all" })).toHaveClass(
      "text-accent",
      "text-label",
      "min-h-touch-target",
    );
  });

  it("round buttons are named by their label; the small one keeps a 48 touch target", () => {
    render(
      <>
        <RoundButton icon={AddIcon} aria-label="Add a goal" />
        <RoundButton size="small" icon={AddIcon} aria-label="Open collection" isDisabled />
      </>,
    );
    expect(screen.getByRole("button", { name: "Add a goal" })).toHaveClass("size-round-button", "bg-primary");
    const small = screen.getByRole("button", { name: "Open collection" });
    expect(small).toHaveClass("size-touch-target");
    expect(small).toBeDisabled();
  });

  it("icon buttons have no fill, and Back is translated and mirrors in RTL", () => {
    render(
      <>
        <IconButton icon={MoreIcon} aria-label="More options" />
        <BackButton onPress={() => undefined} />
      </>,
    );
    expect(screen.getByRole("button", { name: "More options" })).not.toHaveClass("bg-primary");
    const back = screen.getByRole("button", { name: "Back" });
    expect(back.querySelector("svg")).toHaveClass("rtl:-scale-x-100");
  });

  it("keyboard: focus reaches a button and Enter presses it", async () => {
    const onPress = vi.fn();
    render(<Button onPress={onPress}>Go</Button>);
    await userEvent.tab();
    expect(screen.getByRole("button", { name: "Go" })).toHaveFocus();
    await userEvent.keyboard("{Enter}");
    expect(onPress).toHaveBeenCalledOnce();
  });
});

describe("Card", () => {
  it("a clickable card is one button; disabled, it ignores presses", async () => {
    const onPress = vi.fn();
    render(
      <>
        <ClickableCard onPress={onPress}>Morning adhkar</ClickableCard>
        <ClickableCard isDisabled onPress={onPress}>
          Evening adhkar
        </ClickableCard>
      </>,
    );
    await userEvent.click(screen.getByRole("button", { name: "Morning adhkar" }));
    await userEvent.click(screen.getByRole("button", { name: "Evening adhkar" }));
    expect(onPress).toHaveBeenCalledOnce();
    expect(screen.getByRole("button", { name: "Evening adhkar" })).toBeDisabled();
  });

  it("card or tile shape, padded unless its rows carry their own padding", () => {
    const { container } = render(
      <>
        <Card>Grouped</Card>
        <Card shape="tile" padded={false}>
          Rows
        </Card>
      </>,
    );
    const [grouped, rows] = container.children;
    expect(grouped).toHaveClass("rounded-card", "p-card-padding", "gap-row-gap");
    expect(rows).toHaveClass("rounded-tile");
    expect(rows).not.toHaveClass("p-card-padding");
  });
});
