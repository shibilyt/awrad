import { describe, expect, test } from "vitest";
import { contentTypeOf } from "./rules";

/** Importing (audio README, "Phones"): only `.mp3` and `.m4a`, whatever the system calls them. */
describe("contentTypeOf", () => {
  test.each([
    ["dhikr.mp3", "audio/mpeg", "audio/mpeg"],
    ["DHIKR.MP3", "", "audio/mpeg"],
    ["dhikr.m4a", "audio/mp4", "audio/mp4"],
    ["dhikr.m4a", "audio/x-m4a", "audio/mp4"],
    ["dhikr.M4A", "", "audio/mp4"],
    ["dhikr", "audio/mpeg", "audio/mpeg"],
    ["dhikr", "audio/x-m4a", "audio/mp4"],
  ])("imports %s (%s) as %s", (name, type, expected) => {
    expect(contentTypeOf({ name, type })).toBe(expected);
  });

  test.each([
    ["dhikr.aac", "audio/aac"],
    ["dhikr.aac", "audio/x-aac"],
    ["dhikr.aac", "audio/mp4"],
    ["dhikr.wav", "audio/wav"],
    ["dhikr.mp4", "audio/mp4"],
    ["dhikr.ogg", "audio/mpeg"],
    ["dhikr", "audio/aac"],
    ["dhikr", ""],
  ])("refuses %s (%s)", (name, type) => {
    expect(contentTypeOf({ name, type })).toBeNull();
  });
});
