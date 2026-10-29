import { useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { useTranslation } from "react-i18next";
import { AUDIO_USAGE_KEY, AudioUploadError, formatMegabytes, uploadAudio, type UploadFailure } from "@/shared/audio";
import { useLanguage } from "@/shared/i18n";
import { useSessionProblem, type UploadedAudio } from "@/shared/sync";
import { problemKey } from "../custom/useEdit";

/** Where an upload from the editor is: nothing going on, sending (a fraction, 0 to 1), or failed. */
export type UploadState =
  | { status: "idle" }
  | { status: "uploading"; fileName: string; progress: number }
  | { status: "failed"; message: string; retry: (() => void) | null };

/**
 * Uploads a picked recording for the editor (contracts/audio/v1 "Uploading"): the shared rules
 * first, then reserve, PUT and confirm, showing progress. Once it's confirmed `onUploaded` gets
 * the document's `audio`; the dhikr's put goes when the editor is saved. A failure becomes a clear
 * message, with "Try again" where trying again can help: a mismatch starts over with a new
 * `asset_id`, an upload that didn't arrive tries the same one again.
 */
export function useAudioUpload(
  accountId: string,
  onUploaded: (audio: UploadedAudio) => void,
): { state: UploadState; upload: (file: File) => void } {
  const { t } = useTranslation();
  const language = useLanguage();
  const queryClient = useQueryClient();
  const onSessionProblem = useSessionProblem();
  const [state, setState] = useState<UploadState>({ status: "idle" });

  const failureMessage = (failure: UploadFailure): string => {
    if (failure.code !== "storage_full") return t(`library.editor.audioUpload.errors.${failure.code}`);
    return t("library.editor.audioUpload.errors.storage_full", {
      used: formatMegabytes(failure.usedBytes, language),
      limit: formatMegabytes(failure.limitBytes, language),
    });
  };

  const upload = (file: File, assetId?: string): void => {
    setState({ status: "uploading", fileName: file.name, progress: 0 });
    const options = {
      onProgress: (progress: number) => {
        setState({ status: "uploading", fileName: file.name, progress });
      },
      ...(assetId === undefined ? {} : { assetId }),
    };
    uploadAudio(accountId, file, options)
      .then((audio) => {
        setState({ status: "idle" });
        onUploaded(audio);
      })
      .catch((error: unknown) => {
        onSessionProblem(error);
        if (error instanceof AudioUploadError) {
          const { failure } = error;
          const retry =
            failure.code === "upload_mismatch"
              ? () => {
                  upload(file);
                }
              : failure.code === "upload_failed"
                ? () => {
                    upload(file, failure.assetId);
                  }
                : null;
          setState({ status: "failed", message: failureMessage(failure), retry });
        } else {
          setState({
            status: "failed",
            message: t(problemKey(error)),
            retry: () => {
              upload(file);
            },
          });
        }
      })
      .finally(() => {
        // Reserved bytes count as used, whatever became of the upload.
        void queryClient.invalidateQueries({ queryKey: AUDIO_USAGE_KEY });
      });
  };

  return {
    state,
    upload: (file) => {
      upload(file);
    },
  };
}
