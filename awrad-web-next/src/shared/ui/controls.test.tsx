import { render, screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import i18next from "i18next";
import { useState } from "react";
import { describe, expect, it } from "vitest";
import { BottomBar, BottomBarPanel } from "./BottomBar";
import { BottomSheet } from "./BottomSheet";
import { Checkbox, Switch } from "./Checkbox";
import { ConfirmDialog } from "./ConfirmDialog";
import { GoalsIcon, HomeIcon, LibraryIcon } from "./icons";
import { OptionCheckboxGroup, OptionRadioGroup, OptionRow } from "./OptionRow";
import { SegmentPanel, SegmentedPills } from "./SegmentedPills";
import { StepIndicator } from "./TopBar";

describe("option rows", () => {
  it("one choice: radios with their selected state, arrow keys move the choice, disabled rows are skipped", async () => {
    render(
      <OptionRadioGroup aria-label="Language" defaultValue="en">
        <OptionRow value="en" avatar="Aa" label="English" />
        <OptionRow value="ar" label="Arabic" />
        <OptionRow value="ml" label="Malayalam" isDisabled />
      </OptionRadioGroup>,
    );
    const group = screen.getByRole("radiogroup", { name: "Language" });
    expect(within(group).getByRole("radio", { name: "English" })).toBeChecked();
    expect(within(group).getByRole("radio", { name: "Malayalam" })).toBeDisabled();
    await userEvent.click(screen.getByRole("radio", { name: "Arabic" }));
    expect(screen.getByRole("radio", { name: "Arabic" })).toBeChecked();
    await userEvent.keyboard("{ArrowDown}");
    expect(screen.getByRole("radio", { name: "English" })).toBeChecked();
  });

  it("several choices: checkboxes", async () => {
    render(
      <OptionCheckboxGroup aria-label="Reminders" defaultValue={["fajr"]}>
        <OptionRow value="fajr" label="After Fajr" />
        <OptionRow value="asr" label="After Asr" />
      </OptionCheckboxGroup>,
    );
    expect(screen.getByRole("checkbox", { name: "After Fajr" })).toBeChecked();
    await userEvent.click(screen.getByRole("checkbox", { name: "After Asr" }));
    expect(screen.getByRole("checkbox", { name: "After Fajr" })).toBeChecked();
    expect(screen.getByRole("checkbox", { name: "After Asr" })).toBeChecked();
  });
});

describe("checkbox and switch", () => {
  it("checkbox: a real checkbox, ticked by a press, disabled ignores it", async () => {
    render(
      <>
        <Checkbox>Keep me signed in</Checkbox>
        <Checkbox isDisabled>Locked</Checkbox>
      </>,
    );
    await userEvent.click(screen.getByText("Keep me signed in"));
    expect(screen.getByRole("checkbox", { name: "Keep me signed in" })).toBeChecked();
    await userEvent.click(screen.getByText("Locked"));
    expect(screen.getByRole("checkbox", { name: "Locked" })).not.toBeChecked();
    expect(screen.getByRole("checkbox", { name: "Locked" })).toBeDisabled();
  });

  it("switch: announced as a switch, toggled by Space", async () => {
    render(<Switch>Daily reminders</Switch>);
    const toggle = screen.getByRole("switch", { name: "Daily reminders" });
    expect(toggle).not.toBeChecked();
    await userEvent.tab();
    await userEvent.keyboard(" ");
    expect(toggle).toBeChecked();
  });
});

describe("segmented pills", () => {
  it("are tabs: the selected one is marked and shows its panel", async () => {
    render(
      <SegmentedPills
        label="Goal views"
        segments={[
          { id: "active", label: "Active" },
          { id: "history", label: "History" },
        ]}
      >
        <SegmentPanel id="active">Three in progress</SegmentPanel>
        <SegmentPanel id="history">Twelve done</SegmentPanel>
      </SegmentedPills>,
    );
    expect(screen.getByRole("tablist", { name: "Goal views" })).toBeInTheDocument();
    expect(screen.getByRole("tab", { name: "Active" })).toHaveAttribute("aria-selected", "true");
    expect(screen.getByRole("tabpanel")).toHaveTextContent("Three in progress");
    await userEvent.click(screen.getByRole("tab", { name: "History" }));
    expect(screen.getByRole("tab", { name: "History" })).toHaveAttribute("aria-selected", "true");
    expect(screen.getByRole("tab", { name: "Active" })).toHaveAttribute("aria-selected", "false");
    expect(screen.getByRole("tabpanel")).toHaveTextContent("Twelve done");
  });
});

describe("step indicator", () => {
  it('is announced once as "Step 2 of 7", in the UI language', async () => {
    render(<StepIndicator current={2} total={7} />);
    expect(screen.getByRole("img", { name: "Step 2 of 7" })).toBeInTheDocument();
    expect(screen.getByRole("img").children).toHaveLength(7);
    await i18next.changeLanguage("ar");
    expect(await screen.findByRole("img", { name: "الخطوة 2 من 7" })).toBeInTheDocument();
  });
});

describe("bottom bar", () => {
  const items = [
    { id: "home", label: "Home", icon: HomeIcon },
    { id: "goals", label: "Goals", icon: GoalsIcon },
    { id: "library", label: "Library", icon: LibraryIcon },
  ];

  it("is a tab bar with each item's selected state; selecting shows that panel", async () => {
    render(
      <BottomBar label="Main navigation" items={items} defaultSelectedKey="goals" disabledKeys={["library"]}>
        {items.map((item) => (
          <BottomBarPanel key={item.id} id={item.id}>
            {item.label} content
          </BottomBarPanel>
        ))}
      </BottomBar>,
    );
    const bar = screen.getByRole("tablist", { name: "Main navigation" });
    expect(bar).toHaveClass("shadow-floating", "max-w-content");
    expect(within(bar).getByRole("tab", { name: "Goals" })).toHaveAttribute("aria-selected", "true");
    expect(within(bar).getByRole("tab", { name: "Library" })).toHaveAttribute("aria-disabled", "true");
    expect(screen.getByRole("tabpanel")).toHaveTextContent("Goals content");
    await userEvent.click(within(bar).getByRole("tab", { name: "Home" }));
    expect(within(bar).getByRole("tab", { name: "Home" })).toHaveAttribute("aria-selected", "true");
    expect(screen.getByRole("tabpanel")).toHaveTextContent("Home content");
  });
});

function SheetHarness(): React.ReactElement {
  const [isOpen, setOpen] = useState(true);
  return (
    <BottomSheet isOpen={isOpen} onOpenChange={setOpen} title="Choose a time">
      <button type="button">After Fajr</button>
    </BottomSheet>
  );
}

describe("overlays", () => {
  it("bottom sheet: a modal dialog named by its title, closed by Escape", async () => {
    render(<SheetHarness />);
    const sheet = screen.getByRole("dialog", { name: "Choose a time" });
    expect(sheet.closest(".rounded-t-sheet")).toHaveClass("bg-surface-bar");
    await userEvent.keyboard("{Escape}");
    expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
  });

  it("dialog: an alertdialog that takes focus, Cancel first, confirming with the error button", async () => {
    render(
      <ConfirmDialog
        isOpen
        onOpenChange={() => undefined}
        title="Delete this goal?"
        confirmLabel="Delete"
        cancelLabel="Cancel"
        onConfirm={() => undefined}
      >
        <p>Its history goes too.</p>
      </ConfirmDialog>,
    );
    expect(screen.getByRole("alertdialog", { name: "Delete this goal?" })).toBeInTheDocument();
    // Focus moves into the dialog; the first Tab reaches Cancel, the safe choice.
    await waitFor(() => {
      expect(screen.getByRole("alertdialog")).toHaveFocus();
    });
    await userEvent.tab();
    expect(screen.getByRole("button", { name: "Cancel" })).toHaveFocus();
    expect(screen.getByRole("button", { name: "Delete" })).toHaveClass("bg-error");
  });
});
