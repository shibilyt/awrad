import { useEffect, useRef, useState, type ReactElement, type RefObject } from "react";
import { ProgressBar } from "react-aria-components";
import { useTranslation } from "react-i18next";
import type { Audio } from "@/shared/dhikr-catalog";
import { RoundButton } from "@/shared/ui/Button";
import { PauseIcon, PlayIcon } from "@/shared/ui/icons.gen";

/** Seconds as "m:ss" ("0:14"). */
export function formatTime(seconds: number): string {
  const whole = Math.max(0, Math.floor(seconds));
  return `${String(Math.floor(whole / 60))}:${String(whole % 60).padStart(2, "0")}`;
}

/** A media element's duration, or null while it isn't known (NaN) or is a live stream (Infinity). */
function knownDuration(element: HTMLAudioElement): number | null {
  return Number.isFinite(element.duration) && element.duration > 0 ? element.duration : null;
}

/** Pauses the element when the page is hidden (`visibilitychange`) and when it unmounts (the page is left). */
function usePauseWhenLeft(player: RefObject<HTMLAudioElement | null>): void {
  useEffect(() => {
    const element = player.current;
    if (element === null) return undefined;
    const pauseWhenHidden = (): void => {
      if (document.hidden && !element.paused) element.pause();
    };
    document.addEventListener("visibilitychange", pauseWhenHidden);
    return () => {
      document.removeEventListener("visibilitychange", pauseWhenHidden);
      if (!element.paused) element.pause();
    };
  }, [player]);
}

/**
 * The progress line (`ringStroke` high, fully rounded, `outline` track, `progress` fill from the
 * start) and the time in `caption`: "0:14 / 0:26", or only the elapsed time until the duration is
 * known. Announced as one progress bar whose value is that time.
 */
function Progress({ elapsed, duration }: { elapsed: number; duration: number | null }): ReactElement {
  const { t } = useTranslation();
  const time =
    duration === null
      ? formatTime(elapsed)
      : t("library.detail.time", { elapsed: formatTime(elapsed), duration: formatTime(duration) });
  const percent = duration === null ? 0 : Math.min(100, (elapsed / duration) * 100);
  return (
    <>
      <ProgressBar
        aria-label={t("library.detail.position")}
        value={percent}
        valueLabel={time}
        className="flex h-ring-stroke min-w-0 flex-1 overflow-hidden rounded-full bg-outline"
      >
        <span className="h-full rounded-full bg-progress" style={{ width: `${String(percent)}%` }} />
      </ProgressBar>
      <span aria-hidden className="shrink-0 text-caption text-on-surface-variant tabular-nums">
        {time}
      </span>
    </>
  );
}

/**
 * The audio player bar (components.md "Audio player bar") at the bottom of the Arabic card: a
 * round `play` / `pause` button, a progress line (`ringStroke` high, `outline` track, `progress`
 * fill) and the time ("0:14 / 0:26", only the elapsed time until the duration is known), driven by
 * an `<audio>` element on the catalog's URL (dhikrs.awrad.app). Nothing loads until the first play;
 * while it loads the button shows the progress indicator. Playback stops when the page is left
 * (unmounted) or hidden. A failed play shows a message.
 */
export function AudioPlayer({ audio }: { audio: Audio }): ReactElement {
  const { t } = useTranslation();
  const player = useRef<HTMLAudioElement>(null);
  const [playing, setPlaying] = useState(false);
  const [loading, setLoading] = useState(false);
  const [failed, setFailed] = useState(false);
  const [elapsed, setElapsed] = useState(0);
  const [duration, setDuration] = useState<number | null>(null);

  usePauseWhenLeft(player);

  const toggle = (): void => {
    const element = player.current;
    if (element === null) return;
    if (!element.paused) {
      element.pause();
      return;
    }
    setFailed(false);
    setLoading(true);
    element.play().catch(() => {
      setLoading(false);
      setPlaying(false);
      setFailed(true);
    });
  };

  return (
    <div className="flex flex-col gap-sm self-stretch">
      <div className="flex items-center gap-md">
        <RoundButton
          icon={playing ? PauseIcon : PlayIcon}
          aria-label={playing ? t("library.detail.pause") : t("library.detail.play")}
          isPending={loading}
          onPress={toggle}
        />
        <Progress elapsed={elapsed} duration={duration} />
      </div>
      {/* The dhikr's text, transliteration and translation on the page are the recording's transcript. */}
      {/* eslint-disable-next-line jsx-a11y/media-has-caption */}
      <audio
        ref={player}
        src={audio.url}
        preload="none"
        onPlay={() => {
          setPlaying(true);
        }}
        onPlaying={() => {
          setLoading(false);
        }}
        onWaiting={() => {
          setLoading(true);
        }}
        onPause={() => {
          setPlaying(false);
          setLoading(false);
        }}
        onEnded={() => {
          setPlaying(false);
          setLoading(false);
        }}
        onTimeUpdate={(event) => {
          setElapsed(event.currentTarget.currentTime);
        }}
        onDurationChange={(event) => {
          setDuration(knownDuration(event.currentTarget));
        }}
        onError={() => {
          setPlaying(false);
          setLoading(false);
          setFailed(true);
        }}
      />
      {failed && (
        <p role="alert" className="text-center text-caption text-error">
          {t("library.detail.audioFailed")}
        </p>
      )}
    </div>
  );
}
