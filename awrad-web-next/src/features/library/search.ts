/**
 * The Library's search params: the search query as typed, so a search can be shared and survives
 * a reload. Blank means no search.
 */
export function librarySearch(search: Record<string, unknown>): { q?: string } {
  const { q } = search;
  return typeof q === "string" && q.trim() !== "" ? { q } : {};
}
