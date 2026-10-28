/**
 * The Library's search params: the search query as typed, and the tags filtering the list (their
 * IDs, AND), so a search or a filter can be shared and survives a reload. Blank means no search;
 * no tags means no filter.
 */
export interface LibrarySearch {
  q?: string;
  tags?: string[];
}

export function librarySearch(search: Record<string, unknown>): LibrarySearch {
  const { q, tags } = search;
  const tagIds = Array.isArray(tags) ? tags.filter((tag): tag is string => typeof tag === "string") : [];
  return {
    ...(typeof q === "string" && q.trim() !== "" ? { q } : {}),
    ...(tagIds.length > 0 ? { tags: tagIds } : {}),
  };
}
