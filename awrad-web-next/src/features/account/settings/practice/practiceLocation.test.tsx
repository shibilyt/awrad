import { screen, waitFor, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, beforeEach, describe, expect, test } from "vitest";
import { DEFAULT_POLICY, storeLocation, storedLocation } from "@/shared/practice";
import { policyWith, resetClock, sentCommands, setClock, signedInWithPolicy } from "@/test/practice";
import { recordRequests, renderRoute } from "@/test/render";
import { server } from "@/test/setup";
import { ACCOUNT_ID, applied } from "@/test/sync";

const realGeolocation = Object.getOwnPropertyDescriptor(navigator, "geolocation");

beforeEach(() => {
  setClock();
});
afterEach(() => {
  resetClock();
  if (realGeolocation === undefined) Reflect.deleteProperty(navigator, "geolocation");
  else Object.defineProperty(navigator, "geolocation", realGeolocation);
});

/** The browser's geolocation answering one reading, or refusing with a `GeolocationPositionError` code. */
function browserLocation(answer: { latitude: number; longitude: number } | { code: number }): void {
  Object.defineProperty(navigator, "geolocation", {
    configurable: true,
    value: {
      getCurrentPosition: (ok: PositionCallback, fail: PositionErrorCallback) => {
        if ("code" in answer)
          fail({ code: answer.code, message: "", PERMISSION_DENIED: 1 } as GeolocationPositionError);
        else ok({ coords: answer, timestamp: 0 } as unknown as GeolocationPosition);
      },
    },
  });
}

async function openPage(): Promise<void> {
  renderRoute("/account/practice");
  expect(await screen.findByRole("heading", { level: 1, name: "Practice settings" })).toBeInTheDocument();
  // The settings show once the changes feed is read.
  expect(await screen.findByRole("radiogroup", { name: "New day starts at" })).toBeInTheDocument();
}

const placeCard = () => screen.getByText("Place").closest("dl") as HTMLElement;

describe("location", () => {
  test("a city from the bundled list is kept in this browser for the account, never sent, and gives today's Maghrib", async () => {
    const requests = recordRequests();
    server.use(...signedInWithPolicy(DEFAULT_POLICY, 1));
    await openPage();
    expect(within(placeCard()).getByText("No location yet")).toBeInTheDocument();
    expect(within(placeCard()).getByText("Choose a location to see it")).toBeInTheDocument();

    await userEvent.click(screen.getByRole("button", { name: "Choose a city" }));
    const sheet = await screen.findByRole("dialog", { name: "Choose a city" });
    await userEvent.type(within(sheet).getByRole("searchbox", { name: "Search cities" }), "calicut");
    const result = await within(sheet).findByRole("button", { name: "Kozhikode, Kerala, India" }, { timeout: 15_000 });
    expect(within(sheet).getByText("City data © GeoNames (geonames.org), CC BY 4.0")).toBeInTheDocument();
    await userEvent.click(result);

    expect(within(placeCard()).getByText("Kozhikode")).toBeInTheDocument();
    // Maghrib in Kozhikode is 12:33 UTC that day: 6:03 PM in Kolkata.
    expect(within(placeCard()).getByText("6:03 PM")).toBeInTheDocument();
    expect(storedLocation(ACCOUNT_ID)).toEqual({
      latitude: 11.248,
      longitude: 75.7804,
      name: "Kozhikode",
      source: "city",
      city_id: 1265873,
    });
    expect(storedLocation("0192f000-0000-7000-8000-00000000ffff")).toBeNull();
    expect(JSON.stringify(requests.map((request) => request.body))).not.toContain("latitude");
  }, 30_000);

  test("Use my location takes one reading from the browser", async () => {
    browserLocation({ latitude: 25.2048, longitude: 55.2708 });
    server.use(...signedInWithPolicy(DEFAULT_POLICY, 1));
    await openPage();

    await userEvent.click(screen.getByRole("button", { name: "Use my location" }));

    expect(await within(placeCard()).findByText("Your location (25.2°, 55.27°)")).toBeInTheDocument();
    expect(storedLocation(ACCOUNT_ID)).toMatchObject({ source: "gps", name: null, city_id: null });
  });

  test("a refused reading says how to allow it", async () => {
    browserLocation({ code: 1 });
    server.use(...signedInWithPolicy(DEFAULT_POLICY, 1));
    await openPage();

    await userEvent.click(screen.getByRole("button", { name: "Use my location" }));

    expect(await screen.findByRole("alert")).toHaveTextContent(
      "This site isn't allowed to use your location. Allow it in your browser, or choose a city.",
    );
  });

  test("with the Maghrib reset, after Maghrib it's the next day's Hijri date", async () => {
    storeLocation(ACCOUNT_ID, { latitude: 11.248, longitude: 75.7804, name: "Kozhikode", source: "city", city_id: 1 });
    setClock("2026-10-29T13:00:00Z");
    server.use(...signedInWithPolicy(policyWith({ day_reset: "maghrib" }), 1));
    await openPage();

    expect(screen.getByText("19 Jumada al-Ula 1448")).toBeInTheDocument();
  });

  test("Remove location forgets it, and the Maghrib reset falls back to midnight with its hint", async () => {
    storeLocation(ACCOUNT_ID, { latitude: 11.248, longitude: 75.7804, name: "Kozhikode", source: "city", city_id: 1 });
    server.use(...signedInWithPolicy(policyWith({ day_reset: "maghrib" }), 1));
    await openPage();
    expect(within(placeCard()).getByText("Kozhikode")).toBeInTheDocument();
    expect(screen.queryByText(/^This browser has no location yet/)).not.toBeInTheDocument();

    await userEvent.click(screen.getByRole("button", { name: "Remove location" }));

    expect(within(placeCard()).getByText("No location yet")).toBeInTheDocument();
    expect(within(placeCard()).getByText("Choose a location to see it")).toBeInTheDocument();
    expect(
      screen.getByText(/^This browser has no location yet, so here the day starts at midnight/),
    ).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Remove location" })).not.toBeInTheDocument();
    expect(storedLocation(ACCOUNT_ID)).toBeNull();
  });

  test("where the sun doesn't set today, the Maghrib reset says it falls back to midnight", async () => {
    storeLocation(ACCOUNT_ID, { latitude: 69.6496, longitude: 18.956, name: "Tromso", source: "city", city_id: 2 });
    setClock("2026-06-21T10:00:00Z", "Europe/Oslo");
    server.use(...signedInWithPolicy(policyWith({ day_reset: "maghrib" }), 1));
    await openPage();

    expect(within(placeCard()).getByText("The sun doesn't set here today")).toBeInTheDocument();
    expect(screen.getByText("The sun doesn't set here today, so the day starts at midnight.")).toBeInTheDocument();
  });
});

describe("Hijri corrections", () => {
  test("today's date, and Adjust this month offers only the offsets that keep months 29 or 30 days", async () => {
    const requests = recordRequests();
    server.use(...signedInWithPolicy(DEFAULT_POLICY, 2), applied(3));
    await openPage();
    expect(screen.getByText("18 Jumada al-Ula 1448")).toBeInTheDocument();
    // Not near the end of the month: only this month.
    expect(screen.queryByRole("button", { name: /^Adjust Jumada al-Akhirah/ })).not.toBeInTheDocument();

    await userEvent.click(screen.getByRole("button", { name: "Adjust this month" }));
    const sheet = await screen.findByRole("dialog", { name: "When did Jumada al-Ula 1448 start?" });
    // Rabi' al-Thani already has 30 days, so the month can't start later.
    expect(
      within(sheet)
        .getAllByRole("radio")
        .map((option) => option.getAttribute("aria-label")),
    ).toEqual(["1 day earlier: Sunday, October 11", "As calculated (Umm al-Qura): Monday, October 12"]);
    expect(within(sheet).getByRole("radio", { name: /^As calculated/ })).toBeChecked();
    await userEvent.click(within(sheet).getByRole("radio", { name: /^1 day earlier/ }));

    await waitFor(() => {
      expect(sentCommands(requests)).toMatchObject([
        { base_version: 2, document: { hijri_corrections: [{ year: 1448, month: 5, offset_days: -1 }] } },
      ]);
    });
  });

  test("in a month's last days the next month can be adjusted too", async () => {
    setClock("2026-11-09T06:00:00Z");
    server.use(...signedInWithPolicy(DEFAULT_POLICY, 1));
    await openPage();

    expect(screen.getByText("29 Jumada al-Ula 1448")).toBeInTheDocument();
    await userEvent.click(screen.getByRole("button", { name: "Adjust Jumada al-Akhirah 1448" }));
    expect(await screen.findByRole("dialog", { name: "When did Jumada al-Akhirah 1448 start?" })).toBeInTheDocument();
  });

  test("Remove is disabled where removing the correction would leave an invalid set", async () => {
    const corrections = [
      { year: 1447, month: 9, offset_days: 1 },
      { year: 1447, month: 10, offset_days: 1 },
    ];
    server.use(...signedInWithPolicy(policyWith({ hijri_corrections: corrections }), 4));
    await openPage();

    const list = screen.getByRole("list", { name: "Your corrections" });
    const buttons = within(list).getAllByRole("button");
    expect(buttons.map((button) => button.hasAttribute("disabled"))).toEqual([true, false]);
  });

  test("earlier corrections are listed, and removing one sends the rest", async () => {
    const requests = recordRequests();
    const corrections = [
      { year: 1447, month: 9, offset_days: 1 },
      { year: 1447, month: 10, offset_days: 0 },
    ];
    server.use(...signedInWithPolicy(policyWith({ hijri_corrections: corrections }), 4), applied(5));
    await openPage();

    const list = screen.getByRole("list", { name: "Your corrections" });
    expect(within(list).getByText("Ramadan 1447")).toBeInTheDocument();
    expect(within(list).getByText("1 day later")).toBeInTheDocument();
    expect(within(list).getByText("Shawwal 1447")).toBeInTheDocument();

    await userEvent.click(within(list).getByRole("button", { name: "Remove the correction for Shawwal 1447" }));

    await waitFor(() => {
      expect(sentCommands(requests)).toMatchObject([
        { base_version: 4, document: { hijri_corrections: [{ year: 1447, month: 9, offset_days: 1 }] } },
      ]);
    });
  });
});
