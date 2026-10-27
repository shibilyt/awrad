import { useRef, useState, type ReactElement } from "react";
import { useTranslation } from "react-i18next";
import type { Audio } from "@/shared/dhikr-catalog";
import { RoundButton } from "@/shared/ui/Button";
import { PauseIcon, PlayIcon } from "@/shared/ui/icons.gen";

/**
 * Plays and pauses a dhikr's recording: a round `play` / `pause` button driving an `<audio>`
 * element on the catalog's URL, streamed from dhikrs.awrad.app. Nothing loads until the first
 * play. The button's name says what it does next; a failed play shows a message.
 */
export function AudioButton({ audio }: { audio: Audio }): ReactElement {
  const { t } = useTranslation();
  const player = useRef<HTMLAudioElement>(null);
  const [playing, setPlaying] = useState(false);
  const [failed, setFailed] = useState(false);

  const toggle = (): void => {
    const element = player.current;
    if (element === null) return;
    if (!element.paused) {
      element.pause();
      return;
    }
    setFailed(false);
    element.play().catch(() => {
      setPlaying(false);
      setFailed(true);
    });
  };

  return (
    <div className="flex flex-col items-center gap-sm">
      <RoundButton
        icon={playing ? PauseIcon : PlayIcon}
        aria-label={playing ? t("library.detail.pause") : t("library.detail.play")}
        onPress={toggle}
      />
      {/* The dhikr's text, transliteration and translation on the page are the recording's transcript. */}
      {/* eslint-disable-next-line jsx-a11y/media-has-caption */}
      <audio
        ref={player}
        src={audio.url}
        preload="none"
        onPlay={() => {
          setPlaying(true);
        }}
        onPause={() => {
          setPlaying(false);
        }}
        onEnded={() => {
          setPlaying(false);
        }}
        onError={() => {
          setPlaying(false);
          setFailed(true);
        }}
      />
      {failed && (
        <p role="alert" className="text-caption text-error">
          {t("library.detail.audioFailed")}
        </p>
      )}
    </div>
  );
}
