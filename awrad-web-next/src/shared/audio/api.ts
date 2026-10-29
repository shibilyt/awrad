import { api } from "@/shared/api/client";
import { ApiProblem, problemOf } from "@/shared/api/problem";
import type { components } from "@/shared/api/schema.gen";

/**
 * The four audio operations (contracts/api/paths/audio.yaml), as the web calls them: with its
 * cookie session (the client adds CSRF to the POSTs) and `X-Awrad-Account` naming the signed-in
 * account. Each throws an `ApiProblem` on failure.
 */
type Schemas = components["schemas"];
export type AudioUpload = Schemas["AudioUpload"];
export type AudioAsset = Schemas["AudioAsset"];

export interface UploadRequest {
  asset_id: string;
  byte_size: number;
  content_type: string;
  sha256: string;
}

export interface AudioUsage {
  used_bytes: number;
  limit_bytes: number;
}

/** A signed link to play a recording, and when it stops working (milliseconds since the epoch). */
export interface SignedLink {
  url: string;
  expiresAt: number;
}

function account(accountId: string) {
  return { "X-Awrad-Account": accountId };
}

function dataOf<T>(result: { data?: T; error?: unknown; response: Response }): T {
  const problem = problemOf(result);
  if (problem !== null) throw problem;
  if (result.data === undefined) {
    throw new ApiProblem({ code: "unexpected_response", status: result.response.status, detail: "no body" });
  }
  return result.data;
}

/**
 * `create_audio_upload`: a pending upload and its signed PUT link, or, when this `asset_id` is
 * already a ready asset (a repeat), the asset itself.
 */
export async function createAudioUpload(
  accountId: string,
  request: UploadRequest,
): Promise<{ upload: AudioUpload } | { asset: AudioAsset }> {
  const data = dataOf(
    await api.POST("/api/v1/audio_uploads", {
      params: { header: account(accountId) },
      body: request,
    }),
  );
  return "asset" in data ? { asset: data.asset } : { upload: data };
}

/** `complete_audio_upload`: the ready asset, once storage holds the right bytes. */
export async function completeAudioUpload(accountId: string, assetId: string): Promise<AudioAsset> {
  const data = dataOf(
    await api.POST("/api/v1/audio_uploads/{asset_id}/complete", {
      params: { header: account(accountId), path: { asset_id: assetId } },
    }),
  );
  return data.asset;
}

/** `get_audio_download`: a signed GET link to one of the account's ready recordings, for 10 minutes. */
export async function getAudioDownload(accountId: string, assetId: string): Promise<SignedLink> {
  const data = dataOf(
    await api.GET("/api/v1/audio_assets/{asset_id}/download", {
      params: { header: account(accountId), path: { asset_id: assetId } },
    }),
  );
  return { url: data.url, expiresAt: Date.parse(data.expires_at) };
}

/** `get_audio_usage`: the bytes the account's recordings use (ready and pending), and its limit. */
export async function getAudioUsage(accountId: string): Promise<AudioUsage> {
  return dataOf(await api.GET("/api/v1/audio_assets/usage", { params: { header: account(accountId) } }));
}
