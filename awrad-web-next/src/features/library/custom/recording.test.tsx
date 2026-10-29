import { fireEvent, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, describe, expect, test, vi } from "vitest";
import type { Change, CustomDhikrDocument } from "@/shared/sync";
import { recordRequests, renderRoute, type RecordedRequest } from "@/test/render";
import { server } from "@/test/setup";
import { specHandler, specProblem } from "@/test/spec";
import {
  MORNING_DHIKR_ID,
  UPLOADED_ASSET_ID,
  UPLOADED_DHIKR,
  UPLOADED_DHIKR_ID,
  signedInWithEntities,
  withUploadedDhikr,
} from "@/test/sync";

/**
 * A custom dhikr's uploaded recording on its page (slice 3c): the player bar plays it from a
 * signed link (`get_audio_download`, valid 10 minutes), asked for when playback starts and again
 * once it has (nearly) expired.
 */

afterEach(() => {
  vi.restoreAllMocks();
});

/** get_audio_download's example, three times: each expires 09:10:00Z, and its link ends in its number. */
function downloads(): void {
  // MSW tries the handlers added last first, so the first answer goes in last.
  for (const number of [3, 2, 1]) {
    server.use(
      specHandler("get_audio_download", 200, {
        once: true,
        from: (example: { url: string; expires_at: string }) => ({
          ...example,
          url: `${example.url}&n=${String(number)}`,
        }),
      }),
    );
  }
}

function downloadRequests(requests: RecordedRequest[]): RecordedRequest[] {
  return requests.filter((request) => request.path === `/api/v1/audio_assets/${UPLOADED_ASSET_ID}/download`);
}

/** The clock, so the link's expiry can pass. */
function at(instant: string): void {
  vi.spyOn(Date, "now").mockReturnValue(Date.parse(instant));
}

/** jsdom's media elements don't play: report playing (and paused again) as a browser would. */
function fakePlayback(): { plays: () => number; setPaused: (paused: boolean) => void } {
  let paused = true;
  const play = vi.spyOn(HTMLMediaElement.prototype, "play").mockImplementation(function (this: HTMLMediaElement) {
    paused = false;
    this.dispatchEvent(new Event("play"));
    this.dispatchEvent(new Event("playing"));
    return Promise.resolve();
  });
  vi.spyOn(HTMLMediaElement.prototype, "pause").mockImplementation(function (this: HTMLMediaElement) {
    paused = true;
    this.dispatchEvent(new Event("pause"));
  });
  vi.spyOn(HTMLMediaElement.prototype, "paused", "get").mockImplementation(() => paused);
  return {
    plays: () => play.mock.calls.length,
    setPaused: (value) => {
      paused = value;
    },
  };
}

function audioElement(): HTMLAudioElement {
  const audio = document.querySelector("audio");
  if (audio === null) throw new Error("no audio element");
  return audio;
}

describe("an uploaded recording", () => {
  test("plays from a signed link asked for at the first play, and a fresh one once it expires", async () => {
    at("2026-10-29T09:00:00Z");
    server.use(...signedInWithEntities(withUploadedDhikr));
    downloads();
    const playback = fakePlayback();
    const requests = recordRequests();
    renderRoute(`/library/dhikrs/${UPLOADED_DHIKR_ID}`);

    // Nothing is asked for until the first play.
    await userEvent.click(await screen.findByRole("button", { name: "Play audio" }));
    expect(downloadRequests(requests)).toHaveLength(1);
    await waitFor(() => {
      expect(playback.plays()).toBe(1);
    });
    expect(audioElement().src).toMatch(/&n=1$/);
    expect(audioElement()).toHaveAttribute("preload", "none");
    expect(downloadRequests(requests)[0]?.headers.get("X-Awrad-Account")).toBeTruthy();

    // Paused and played again while the link is good: no new link.
    await userEvent.click(screen.getByRole("button", { name: "Pause audio" }));
    at("2026-10-29T09:05:00Z");
    await userEvent.click(screen.getByRole("button", { name: "Play audio" }));
    await waitFor(() => {
      expect(playback.plays()).toBe(2);
    });
    expect(downloadRequests(requests)).toHaveLength(1);

    // Played again within 30 seconds of 09:10: a fresh link, from where it was.
    await userEvent.click(screen.getByRole("button", { name: "Pause audio" }));
    audioElement().currentTime = 14;
    at("2026-10-29T09:09:45Z");
    await userEvent.click(screen.getByRole("button", { name: "Play audio" }));
    await waitFor(() => {
      expect(playback.plays()).toBe(3);
    });
    expect(downloadRequests(requests)).toHaveLength(2);
    expect(audioElement().src).toMatch(/&n=2$/);
    expect(audioElement().currentTime).toBe(14);
  });

  test("a load error gets one fresh link before saying it can't play", async () => {
    at("2026-10-29T09:00:00Z");
    server.use(...signedInWithEntities(withUploadedDhikr));
    downloads();
    const playback = fakePlayback();
    const requests = recordRequests();
    renderRoute(`/library/dhikrs/${UPLOADED_DHIKR_ID}`);
    await userEvent.click(await screen.findByRole("button", { name: "Play audio" }));
    await waitFor(() => {
      expect(playback.plays()).toBe(1);
    });

    // Storage refuses the link (it expired mid-play): one fresh link, and play on.
    playback.setPaused(true);
    fireEvent.error(audioElement());
    await waitFor(() => {
      expect(playback.plays()).toBe(2);
    });
    expect(downloadRequests(requests)).toHaveLength(2);
    expect(audioElement().src).toMatch(/&n=2$/);
    expect(screen.queryByRole("alert")).not.toBeInTheDocument();

    // Refused again before it played: give up.
    fireEvent.error(audioElement());
    fireEvent.error(audioElement());
    expect(await screen.findByRole("alert")).toHaveTextContent("Couldn't play the audio.");
  });

  test("a recording that's gone (404) says it can't play", async () => {
    server.use(...signedInWithEntities(withUploadedDhikr), specProblem("get_audio_download", "not_found"));
    fakePlayback();
    renderRoute(`/library/dhikrs/${UPLOADED_DHIKR_ID}`);

    await userEvent.click(await screen.findByRole("button", { name: "Play audio" }));

    expect(await screen.findByRole("alert")).toHaveTextContent("Couldn't play the audio.");
  });

  test("a phone's recording has no player, and a note that it's on the phone", async () => {
    server.use(...signedInWithEntities());
    renderRoute(`/library/dhikrs/${MORNING_DHIKR_ID}`);

    expect(await screen.findByText("Audio is on the phone that added it.")).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Play audio" })).not.toBeInTheDocument();
  });
});

/** Audio README, "Phones": before the first play the player shows the document's `duration_ms`. */
describe("the time before the first play", () => {
  test("is the document's duration_ms as the total, until the file's own length is known", async () => {
    server.use(...signedInWithEntities(withUploadedDhikr));
    downloads();
    fakePlayback();
    const requests = recordRequests();
    renderRoute(`/library/dhikrs/${UPLOADED_DHIKR_ID}`);

    // duration_ms 31250, and nothing loaded yet.
    const position = await screen.findByRole("progressbar", { name: "Playback position" });
    expect(position).toHaveAttribute("aria-valuetext", "0:00 / 0:31");
    expect(screen.getByText("0:00 / 0:31")).toBeInTheDocument();
    expect(downloadRequests(requests)).toHaveLength(0);

    // Once loaded, the element's length takes over.
    await userEvent.click(screen.getByRole("button", { name: "Play audio" }));
    Object.defineProperties(audioElement(), { duration: { value: 33.4 } });
    fireEvent.durationChange(audioElement());
    await waitFor(() => {
      expect(position).toHaveAttribute("aria-valuetext", "0:00 / 0:33");
    });
  });

  test("is only the elapsed time when the uploader couldn't measure it (duration_ms null)", async () => {
    const dhikr: CustomDhikrDocument = {
      ...UPLOADED_DHIKR,
      audio: { asset_id: UPLOADED_ASSET_ID, byte_size: 4182733, content_type: "audio/mpeg", duration_ms: null },
    };
    const unmeasured = (changes: Change[]): Change[] =>
      withUploadedDhikr(changes).map((change) =>
        change.entity_id === UPLOADED_DHIKR_ID ? { ...change, document: dhikr as Change["document"] } : change,
      );
    server.use(...signedInWithEntities(unmeasured));
    renderRoute(`/library/dhikrs/${UPLOADED_DHIKR_ID}`);

    const position = await screen.findByRole("progressbar", { name: "Playback position" });
    expect(position).toHaveAttribute("aria-valuetext", "0:00");
  });
});
