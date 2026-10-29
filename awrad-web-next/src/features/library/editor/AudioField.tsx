import type { ReactElement } from "react";
import { FileTrigger, ProgressBar } from "react-aria-components";
import { useTranslation } from "react-i18next";
import { formatMegabytes } from "@/shared/audio";
import { useLanguage } from "@/shared/i18n";
import type { CustomDhikrDocument } from "@/shared/sync";
import { Button } from "@/shared/ui/Button";
import { Card } from "@/shared/ui/Card";
import { AddIcon, DeleteIcon } from "@/shared/ui/icons.gen";
import { formatTime } from "../AudioPlayer";
import { FieldGroup } from "./TextSections";
import type { UploadState } from "./useAudioUpload";

/** What the file picker offers: MP3 and M4A, by extension and by media type (the upload rules check again). */
const ACCEPTED = [".mp3", ".m4a", "audio/mpeg", "audio/mp4", "audio/x-m4a"];

type Audio = CustomDhikrDocument["audio"];

/** A problem with the recording, wherever in `audio` it points (`audio`, `audio.asset_id`, …). */
function audioError(errors: Record<string, string>): string | undefined {
  return Object.entries(errors).find(([name]) => name === "audio" || name.startsWith("audio."))?.[1];
}

/** The recording the dhikr has now: none, a phone's, or an uploaded one with its size and length. */
function Current({ audio }: { audio: Audio }): ReactElement {
  const { t } = useTranslation();
  const language = useLanguage();
  if (audio === null) {
    return <p className="text-body text-on-surface-variant">{t("library.editor.audioUpload.none")}</p>;
  }
  if ("local_only" in audio) {
    return <p className="text-body text-on-surface-variant">{t("library.editor.audioOnPhone")}</p>;
  }
  const size = formatMegabytes(audio.byte_size, language);
  return (
    <p className="text-body text-on-surface">
      {audio.duration_ms === null
        ? t("library.editor.audioUpload.uploaded", { size })
        : t("library.editor.audioUpload.uploadedWithLength", { size, length: formatTime(audio.duration_ms / 1000) })}
    </p>
  );
}

/** "Uploading dhikr.mp3…" over a progress line, as the player bar draws its position. */
function Uploading({ fileName, progress }: { fileName: string; progress: number }): ReactElement {
  const { t } = useTranslation();
  const percent = Math.round(progress * 100);
  return (
    <ProgressBar aria-label={t("library.editor.audioUpload.progress")} value={percent} className="flex flex-col gap-sm">
      {({ valueText }) => (
        <>
          <div className="flex items-center justify-between gap-md">
            <span className="min-w-0 truncate text-body text-on-surface">
              {t("library.editor.audioUpload.uploading", { name: fileName })}
            </span>
            <span className="shrink-0 text-caption text-on-surface-variant tabular-nums">{valueText}</span>
          </div>
          <span className="flex h-ring-stroke overflow-hidden rounded-full bg-outline">
            <span className="h-full rounded-full bg-progress" style={{ width: `${String(percent)}%` }} />
          </span>
        </>
      )}
    </ProgressBar>
  );
}

/**
 * "Audio" in the custom dhikr editor (slice 3c): the recording it has, and Add audio (an MP3 or
 * M4A file, checked by the upload rules, then uploaded with its progress shown), or Replace and
 * Remove. A failed upload says why, with "Try again" where that can help. Saving the editor sends
 * the dhikr naming the uploaded recording.
 */
export function AudioField({
  audio,
  uploader: { state: upload, upload: onPick },
  errors,
  onRemove,
}: {
  audio: Audio;
  uploader: { state: UploadState; upload: (file: File) => void };
  /** The editor's field problems; any on the recording (`audio_not_found`, `audio_mismatch`) shows here. */
  errors: Record<string, string>;
  onRemove: () => void;
}): ReactElement {
  const { t } = useTranslation();
  const isUploading = upload.status === "uploading";
  const error = audioError(errors);
  return (
    <FieldGroup title={t("library.editor.audio")} hint={t("library.editor.audioHint")}>
      <Card>
        <div data-invalid={error === undefined ? undefined : true} className="flex flex-col gap-lg">
          {upload.status === "uploading" ? (
            <Uploading fileName={upload.fileName} progress={upload.progress} />
          ) : (
            <Current audio={audio} />
          )}
          {upload.status === "failed" && (
            <p role="alert" className="text-caption text-error">
              {upload.message}
            </p>
          )}
          {error !== undefined && upload.status !== "failed" && (
            <p role="alert" className="text-caption text-error">
              {error}
            </p>
          )}
          <div className="flex flex-wrap gap-sm">
            {upload.status === "failed" && upload.retry !== null && (
              <Button variant="main" width="label" onPress={upload.retry}>
                {t("library.editor.audioUpload.retry")}
              </Button>
            )}
            <FileTrigger
              acceptedFileTypes={ACCEPTED}
              onSelect={(files) => {
                const file = files?.[0];
                if (file !== undefined) onPick(file);
              }}
            >
              <Button variant="secondary" width="label" icon={AddIcon} isDisabled={isUploading}>
                {audio === null ? t("library.editor.audioUpload.add") : t("library.editor.audioUpload.replace")}
              </Button>
            </FileTrigger>
            {audio !== null && (
              <Button variant="secondary" width="label" icon={DeleteIcon} isDisabled={isUploading} onPress={onRemove}>
                {t("library.editor.audioUpload.remove")}
              </Button>
            )}
          </div>
        </div>
      </Card>
    </FieldGroup>
  );
}
