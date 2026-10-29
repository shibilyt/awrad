import { useEffect, useRef, useState, type ReactElement, type RefObject } from "react";
import { ProgressBar } from "react-aria-components";
import { useTranslation } from "react-i18next";
import type { SignedLink } from "@/shared/audio";
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
 * What the player plays: a public URL (a built-in's, on dhikrs.awrad.app), or a private recording
 * reached by a short-lived signed link (slice 3c), asked for when playback starts, with its
 * document's `duration_ms` (null when the uploader couldn't measure it).
 */
export type PlayerSource =
  { kind: "url"; url: string } | { kind: "signed"; link: () => Promise<SignedLink>; durationMs: number | null };

/**
 * The total time to show while the element doesn't know it (before the first play): a recording's
 * `duration_ms`, in seconds (audio README, "Before the first play"). A catalog URL has none.
 */
function declaredDuration(source: PlayerSource): number | null {
  return source.kind === "signed" && source.durationMs !== null && source.durationMs > 0
    ? source.durationMs / 1000
    : null;
}

/** A link this close to expiring is replaced before playing on: storage refuses an expired one. */
const LINK_MARGIN_MS = 30_000;

function isFresh(link: SignedLink | null): boolean {
  return link !== null && link.expiresAt - LINK_MARGIN_MS > Date.now();
}

/**
 * Starts and stops the element, and for a signed source keeps its link fresh: one is asked for at
 * the first play and again whenever play resumes after it has (nearly) expired, keeping the
 * position. A load error on a link (it expired mid-play, say) gets one fresh link before giving up.
 */
function usePlayback(
  player: RefObject<HTMLAudioElement | null>,
  source: PlayerSource,
  onFailed: () => void,
): { toggle: () => void; onError: () => boolean; onPlaying: () => void } {
  const link = useRef<SignedLink | null>(null);
  const retried = useRef(false);

  const start = (element: HTMLAudioElement): void => {
    element.play().catch(onFailed);
  };
  const playFreshLink = (element: HTMLAudioElement): void => {
    if (source.kind === "url") return;
    source
      .link()
      .then((fresh) => {
        const position = element.currentTime;
        link.current = fresh;
        element.src = fresh.url;
        if (position > 0) element.currentTime = position;
        start(element);
      })
      .catch(onFailed);
  };

  return {
    /** Pause, or play: at once on a URL or a fresh link, after asking for a new link otherwise. */
    toggle: () => {
      const element = player.current;
      if (element === null) return;
      if (!element.paused) {
        element.pause();
        return;
      }
      if (source.kind === "url" || isFresh(link.current)) start(element);
      else playFreshLink(element);
    },
    /** A load error: `true` when it's being retried on a fresh link. */
    onError: () => {
      const element = player.current;
      if (source.kind === "url" || element === null || retried.current) return false;
      retried.current = true;
      link.current = null;
      playFreshLink(element);
      return true;
    },
    onPlaying: () => {
      retried.current = false;
    },
  };
}

/**
 * The audio player bar (components.md "Audio player bar") at the bottom of the Arabic card: a
 * round `play` / `pause` button, a progress line (`ringStroke` high, `outline` track, `progress`
 * fill) and the time ("0:14 / 0:26"; before the element knows the duration, an uploaded
 * recording's `duration_ms` as the total, and otherwise only the elapsed time), driven by
 * an `<audio>` element on the source: the catalog's URL, or a signed link to the account's own
 * recording (fetched at the first play and again once it expires, after 10 minutes). Nothing loads
 * until the first play; while it loads the button shows the progress indicator. Playback stops
 * when the page is left (unmounted) or hidden. A failed play shows a message.
 */
export function AudioPlayer({ source }: { source: PlayerSource }): ReactElement {
  const { t } = useTranslation();
  const player = useRef<HTMLAudioElement>(null);
  const [playing, setPlaying] = useState(false);
  const [loading, setLoading] = useState(false);
  const [failed, setFailed] = useState(false);
  const [elapsed, setElapsed] = useState(0);
  const [duration, setDuration] = useState<number | null>(null);

  usePauseWhenLeft(player);
  const fail = (): void => {
    setLoading(false);
    setPlaying(false);
    setFailed(true);
  };
  const playback = usePlayback(player, source, fail);

  const toggle = (): void => {
    if (player.current?.paused === true) {
      setFailed(false);
      setLoading(true);
    }
    playback.toggle();
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
        <Progress elapsed={elapsed} duration={duration ?? declaredDuration(source)} />
      </div>
      {/* The dhikr's text, transliteration and translation on the page are the recording's transcript. */}
      {/* eslint-disable-next-line jsx-a11y/media-has-caption */}
      <audio
        ref={player}
        src={source.kind === "url" ? source.url : undefined}
        preload="none"
        onPlay={() => {
          setPlaying(true);
        }}
        onPlaying={() => {
          setLoading(false);
          playback.onPlaying();
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
          if (playback.onError()) setLoading(true);
          else fail();
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
