import { fireEvent, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import i18next from "i18next";
import { afterEach, describe, expect, test, vi } from "vitest";
import { findDhikr, type Dhikr } from "@/shared/dhikr-catalog";
import { catalog } from "@/shared/dhikr-catalog/catalog.gen";
import { renderRoute } from "@/test/render";

afterEach(() => {
  vi.restoreAllMocks();
});

function dhikr(key: string): Dhikr {
  const found = findDhikr(catalog, key);
  if (found === undefined) throw new Error(`no dhikr ${key}`);
  return found;
}

/** The Arabic block of a dhikr page: the element marked `lang="ar"` inside the text card. */
function arabicLines(): string[] {
  const block = document.querySelector('main div[lang="ar"]');
  if (block === null) throw new Error("no Arabic block");
  return [...block.querySelectorAll("p")].map((line) => line.textContent);
}

describe("dhikr detail by kind", () => {
  test("Qur'an: one ayah per line, with its reference, then transliteration and translation", async () => {
    renderRoute("/library/dhikrs/surah-ikhlas");

    expect(await screen.findByRole("heading", { level: 1, name: "Surah Ikhlas" })).toBeInTheDocument();
    expect(arabicLines()).toEqual(dhikr("surah-ikhlas").arabic.split("\n"));
    expect(arabicLines()).toHaveLength(5);
    expect(screen.getByText("Qur'an 112:1–4")).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Transliteration" })).toBeInTheDocument();
    expect(screen.getByText(/Qul huwallahu ahad/)).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Translation" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Play audio" })).toBeInTheDocument();
  });

  test("a name of Allah: the name large and its meaning, no transliteration", async () => {
    renderRoute("/library/dhikrs/asma-ul-husna-ar-rahman");

    expect(await screen.findByRole("heading", { level: 1, name: "Ya Rahman" })).toBeInTheDocument();
    const name = screen.getByText("يَا رَحْمَٰنُ");
    expect(name).toHaveClass("text-large-title", "font-arabic");
    expect(name).toHaveAttribute("dir", "rtl");
    expect(screen.getByText("The Most Merciful")).toBeInTheDocument();
    expect(screen.queryByRole("heading", { name: "Transliteration" })).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Play audio" })).not.toBeInTheDocument();
  });

  test("salawat: Arabic, transliteration and translation in the UI language", async () => {
    renderRoute("/library/dhikrs/swalath-al-nariyya");

    expect(await screen.findByRole("heading", { level: 1, name: "Swalath al Nariyya" })).toBeInTheDocument();
    expect(arabicLines()).toHaveLength(1);
    expect(screen.getByText(/^Allahumma swalli swalatan kamilatan/)).toBeInTheDocument();
    expect(screen.getByText(/^O Allah, send complete blessings/)).toBeInTheDocument();
  });

  test("Arabic shows no transliteration; Malayalam shows its own translation and English where it has none", async () => {
    await i18next.changeLanguage("ar");
    const { unmount } = renderRoute("/library/dhikrs/swalath-al-nariyya");
    expect(await screen.findByRole("heading", { level: 1, name: "الصلاة النارية" })).toBeInTheDocument();
    expect(screen.queryByRole("heading", { name: "النطق بالحروف اللاتينية" })).not.toBeInTheDocument();
    expect(screen.getByText("صلاة كاملة وسلام تام على سيدنا محمد.")).toBeInTheDocument();
    unmount();

    await i18next.changeLanguage("ml");
    renderRoute("/library/dhikrs/surah-ikhlas");
    expect(await screen.findByRole("heading", { level: 1, name: "സൂറത് അൽ ഇഖ്ലാസ്" })).toBeInTheDocument();
    // No Malayalam transliteration or translation in the catalog: both fall back to English.
    expect(screen.getByText(/^Bismillahir Rahmanir Raheem/)).toBeInTheDocument();
    expect(screen.getByText(/^In the name of Allah/)).toBeInTheDocument();
    expect(screen.getByText("ഖുർആൻ 112:1–4")).toBeInTheDocument();
  });
});

describe("tags, virtues and references", () => {
  test("virtues are listed with their references' labels", async () => {
    renderRoute("/library/dhikrs/isthighfar");

    const virtues = await screen.findByRole("region", { name: "Virtues" });
    const items = within(virtues).getAllByRole("listitem");
    expect(items).toHaveLength(3);
    expect(items[0]).toHaveTextContent("Sunan Abi Dawud 1518 · Da'if (al-Albani)");
    expect(items[1]).toHaveTextContent("Qur'an 71:10");
    expect(items[2]).toHaveTextContent("Qur'an 71:10–12");
  });

  test("catalog tags show as chips", async () => {
    renderRoute("/library/dhikrs/swalath-for-debt");

    const tags = await screen.findByRole("list", { name: "Tags" });
    expect(within(tags).getByRole("listitem")).toHaveTextContent("Debt");
    expect(screen.queryByRole("region", { name: "Virtues" })).not.toBeInTheDocument();
  });
});

describe("audio", () => {
  test("the round button plays and pauses an <audio> element on the catalog's URL", async () => {
    const play = vi.spyOn(HTMLMediaElement.prototype, "play").mockImplementation(function (this: HTMLMediaElement) {
      this.dispatchEvent(new Event("play"));
      return Promise.resolve();
    });
    const pause = vi.spyOn(HTMLMediaElement.prototype, "pause").mockImplementation(function (this: HTMLMediaElement) {
      this.dispatchEvent(new Event("pause"));
    });
    renderRoute("/library/dhikrs/surah-ikhlas");

    await userEvent.click(await screen.findByRole("button", { name: "Play audio" }));
    expect(play).toHaveBeenCalledTimes(1);
    const audio = document.querySelector("audio");
    expect(audio).toHaveAttribute("src", "https://dhikrs.awrad.app/ikhlas.mp3");
    expect(audio).toHaveAttribute("preload", "none");

    // jsdom's media elements are always paused; report playing as a browser would.
    vi.spyOn(HTMLMediaElement.prototype, "paused", "get").mockReturnValue(false);
    await userEvent.click(await screen.findByRole("button", { name: "Pause audio" }));
    expect(pause).toHaveBeenCalledTimes(1);
    expect(await screen.findByRole("button", { name: "Play audio" })).toBeInTheDocument();
  });

  test("a recording that can't play says so", async () => {
    vi.spyOn(HTMLMediaElement.prototype, "play").mockRejectedValue(new DOMException("blocked", "NotAllowedError"));
    renderRoute("/library/dhikrs/tahleel");

    await userEvent.click(await screen.findByRole("button", { name: "Play audio" }));
    expect(await screen.findByRole("alert")).toHaveTextContent("Couldn't play the audio.");

    const audio = document.querySelector("audio");
    if (audio === null) throw new Error("no audio element");
    fireEvent.play(audio);
    expect(await screen.findByRole("button", { name: "Pause audio" })).toBeInTheDocument();
  });
});
