import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { renderHook, waitFor } from "@testing-library/react";
import type { ReactNode } from "react";
import { describe, expect, test } from "vitest";
import { ApiProblem } from "@/shared/api/problem";
import { currentAccountQuery, type Account } from "@/shared/session";
import { recordRequests } from "@/test/render";
import { server } from "@/test/setup";
import { specHandler, specProblem } from "@/test/spec";
import { fetchSyncState, syncQuery, useSendEdit, type Change, type Edit, type Receipt, type SyncState } from ".";

const ACCOUNT = "0b6f6a1e-6c1f-4b8e-9a51-2f3d7c1e8a90"; // get_current_account's example
const CSRF = "SXlPVEZ3Zm9MUw4JHQ0rNTI8KyorFxUZ"; // get_browser_csrf_token's example
const DHIKR = "0192f0d0-0000-7000-8000-000000000002"; // the custom dhikr in the spec's examples
const TAHLEEL = "6f04f77e-dcb6-4a29-9dc5-fcd3649c2961";
const UUID_V7 = /^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;

interface ChangesPage {
  changes: Change[];
  next_after: number;
  has_more: boolean;
  head_revision: number;
}
interface ReceiptBatch {
  receipts: Receipt[];
  head_revision: number;
}

/** The spec's changes example as one page, or split into pages (`has_more`) of the given changes. */
function changesPage(pick: (changes: Change[]) => Change[], hasMore: boolean, nextAfter: number) {
  return specHandler("list_sync_changes", 200, {
    once: true,
    from: (example: ChangesPage) => ({
      ...example,
      changes: pick(example.changes),
      has_more: hasMore,
      next_after: nextAfter,
    }),
  });
}

/** `post_sync_commands` answering with the receipt the spec's example has at `index`. */
function receiptAt(index: number) {
  return specHandler("post_sync_commands", 200, {
    once: true,
    from: (example: ReceiptBatch) => ({ ...example, receipts: [example.receipts[index]] }),
  });
}

function setup(initial: SyncState | null = null) {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false }, mutations: { retry: false } } });
  // As a page reading the feed would have left it: the data, and how to read it again.
  const { queryKey } = syncQuery(ACCOUNT);
  queryClient.setQueryDefaults(queryKey, { queryFn: () => fetchSyncState(ACCOUNT) });
  if (initial !== null) queryClient.setQueryData(queryKey, initial);
  const account: Account = { id: ACCOUNT, email: "amina@example.com", created_at: "2026-10-26T08:00:00Z" };
  queryClient.setQueryData(currentAccountQuery.queryKey, account);
  const wrapper = ({ children }: { children: ReactNode }) => (
    <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
  );
  const { result } = renderHook(() => useSendEdit(ACCOUNT), { wrapper });
  return { queryClient, send: (edit: Edit) => result.current.mutateAsync(edit) };
}

const STATE: SyncState = {
  custom_dhikr: {},
  user_tag: {
    "0192f0a0-0000-7000-8000-000000000001": {
      id: "0192f0a0-0000-7000-8000-000000000001",
      version: 1,
      document: { name: "Morning", normalized_name: "morning" },
    },
  },
  dhikr_personal: {
    [TAHLEEL]: { id: TAHLEEL, version: 1, document: { tag_ids: ["0192f0a0-0000-7000-8000-000000000001"] } },
  },
  headRevision: 10,
};

const RENAME: Edit = {
  entity_type: "user_tag",
  entity_id: "0192f0a0-0000-7000-8000-000000000001",
  op: "put",
  base_version: 1,
  document: { name: "Mornings", normalized_name: "mornings" },
};

describe("reading the changes feed", () => {
  test("reads every page from after=0 with X-Awrad-Account, keeping each entity's latest state", async () => {
    const requests = recordRequests();
    server.use(
      changesPage((changes) => changes.slice(0, 2), true, 12),
      changesPage((changes) => changes.slice(2), false, 13),
    );

    const state = await fetchSyncState(ACCOUNT);

    const reads = requests.filter((request) => request.path === "/api/v1/sync/changes");
    expect(reads).toHaveLength(2);
    expect(reads.map((request) => request.headers.get("X-Awrad-Account"))).toEqual([ACCOUNT, ACCOUNT]);
    expect(Object.keys(state.custom_dhikr)).toEqual([DHIKR]);
    expect(state.custom_dhikr[DHIKR]?.version).toBe(1);
    expect(state.dhikr_personal[TAHLEEL]?.document.tag_ids).toHaveLength(2);
    // The deleted tag on the second page isn't kept.
    expect(state.user_tag).toEqual({});
    expect(state.headRevision).toBe(13);
  });

  test("the page queries carry after and limit", async () => {
    const urls: string[] = [];
    server.events.on("request:start", ({ request }) => urls.push(request.url));
    server.use(
      changesPage((changes) => changes, true, 13),
      changesPage(() => [], false, 13),
    );

    await fetchSyncState(ACCOUNT);

    expect(urls.map((url) => new URL(url).search)).toEqual(["?after=0&limit=200", "?after=13&limit=200"]);
  });

  test("a problem rejects with its code", async () => {
    server.use(specProblem("list_sync_changes", "account_mismatch"));
    await expect(fetchSyncState(ACCOUNT)).rejects.toMatchObject({ code: "account_mismatch" });
  });
});

describe("sending an edit", () => {
  test("one command with a UUIDv7 command_id, X-Awrad-Account and CSRF; applied updates the cache and rereads", async () => {
    const requests = recordRequests();
    server.use(
      specHandler("get_browser_csrf_token", 200),
      receiptAt(0),
      changesPage((c) => c, false, 13),
    );
    const { queryClient, send } = setup(STATE);

    expect(await send(RENAME)).toEqual({ status: "applied", version: 1 });

    const post = requests.find((request) => request.method === "POST");
    expect(post?.path).toBe("/api/v1/sync/commands");
    expect(post?.headers.get("X-Awrad-Account")).toBe(ACCOUNT);
    expect(post?.headers.get("X-CSRF-Token")).toBe(CSRF);
    await waitFor(() => {
      expect(post?.body).toBeDefined();
    });
    const body = post?.body as { commands: Record<string, unknown>[] };
    expect(body.commands).toHaveLength(1);
    expect(body.commands[0]).toMatchObject({ ...RENAME });
    expect(body.commands[0]?.["command_id"]).toMatch(UUID_V7);
    // The feed is read again after the edit.
    await waitFor(() => {
      expect(requests.some((request) => request.path === "/api/v1/sync/changes")).toBe(true);
    });
    expect(queryClient.getQueryData<SyncState>(syncQuery(ACCOUNT).queryKey)?.custom_dhikr[DHIKR]).toBeDefined();
  });

  test("applied: the cache holds the new document at the receipt's version before the reread", async () => {
    server.use(
      specHandler("get_browser_csrf_token", 200),
      receiptAt(0),
      changesPage(() => [], false, 13),
    );
    const { queryClient, send } = setup(STATE);
    const seen: (SyncState | undefined)[] = [];
    queryClient.getQueryCache().subscribe(() => {
      seen.push(queryClient.getQueryData<SyncState>(syncQuery(ACCOUNT).queryKey));
    });

    await send(RENAME);

    const first = seen.find((state) => state?.headRevision === 11);
    expect(first?.user_tag[RENAME.entity_id]).toEqual({ id: RENAME.entity_id, version: 1, document: RENAME.document });
  });
});

describe("every receipt status", () => {
  test("duplicate: treated as its original receipt", async () => {
    server.use(
      specHandler("get_browser_csrf_token", 200),
      receiptAt(6),
      changesPage(() => [], false, 13),
    );
    const { send } = setup(STATE);
    expect(await send(RENAME)).toEqual({ status: "applied", version: 1 });
  });

  test("conflict: the server's copy, and the edit to keep", async () => {
    server.use(
      specHandler("get_browser_csrf_token", 200),
      receiptAt(3),
      changesPage(() => [], false, 13),
    );
    const { send } = setup(STATE);
    const edit: Edit = { entity_type: "custom_dhikr", entity_id: DHIKR, op: "delete", base_version: 2 };

    const result = await send(edit);

    expect(result).toMatchObject({ status: "conflict", edit, current: { version: 3, state: "active" } });
  });

  test("merged: the surviving tag's ID, and that tag in the cache", async () => {
    server.use(
      specHandler("get_browser_csrf_token", 200),
      receiptAt(1),
      changesPage(() => [], false, 13),
    );
    const { queryClient, send } = setup({ ...STATE, user_tag: {} });
    const create: Edit = { ...RENAME, entity_id: "0192f0a0-0000-7000-8000-000000000003", base_version: 0 };

    expect(await send(create)).toEqual({ status: "merged", mergedInto: "0192f0a0-0000-7000-8000-000000000001" });
    const state = queryClient.getQueryData<SyncState>(syncQuery(ACCOUNT).queryKey);
    expect(state?.user_tag["0192f0a0-0000-7000-8000-000000000001"]?.document.name).toBe("Morning");
  });

  test("gone: removed from the cache, with its cascade", async () => {
    server.use(
      specHandler("get_browser_csrf_token", 200),
      receiptAt(4),
      changesPage(() => [], false, 13),
    );
    const { queryClient, send } = setup(STATE);

    expect(await send({ ...RENAME, op: "delete" })).toEqual({ status: "gone" });
    const state = queryClient.getQueryData<SyncState>(syncQuery(ACCOUNT).queryKey);
    expect(state?.user_tag).toEqual({});
    expect(state?.dhikr_personal[TAHLEEL]?.document.tag_ids).toEqual([]);
  });

  test("rejected: the code and the fields relative to the document", async () => {
    server.use(
      specHandler("get_browser_csrf_token", 200),
      receiptAt(5),
      changesPage(() => [], false, 13),
    );
    const { send } = setup(STATE);
    expect(await send(RENAME)).toEqual({
      status: "rejected",
      code: "document_invalid",
      fields: [{ field: "/normalized_name", code: "mismatch" }],
    });
  });
});

describe("a session that no longer matches", () => {
  test("a 409 account_mismatch drops the account's entities and asks who is signed in", async () => {
    server.use(specHandler("get_browser_csrf_token", 200), specProblem("post_sync_commands", "account_mismatch"));
    server.use(specHandler("get_current_account", 200));
    const { queryClient, send } = setup(STATE);

    await expect(send(RENAME)).rejects.toBeInstanceOf(ApiProblem);
    expect(queryClient.getQueryData(syncQuery(ACCOUNT).queryKey)).toBeUndefined();
  });

  test("a 401 signs this page out", async () => {
    server.use(specHandler("get_browser_csrf_token", 200), specProblem("post_sync_commands", "unauthenticated"));
    const { queryClient, send } = setup(STATE);

    await expect(send(RENAME)).rejects.toMatchObject({ code: "unauthenticated" });
    expect(queryClient.getQueryData(currentAccountQuery.queryKey)).toBeNull();
    expect(queryClient.getQueryData(syncQuery(ACCOUNT).queryKey)).toBeUndefined();
  });
});
