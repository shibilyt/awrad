import { use } from "react";
import type { Catalog, Collection, Dhikr, Tag } from "./types";

/** A promise that says when it's settled, the way React's `use` reads it. */
type TrackedPromise<T> = Promise<T> & { status?: "fulfilled"; value?: T };

let pending: TrackedPromise<Catalog> | null = null;

/**
 * The bundled catalog, loaded on first use. It's a chunk of its own (only this file imports
 * catalog.gen.ts), so the first page doesn't carry it. Route loaders call this so a page has it
 * before it renders. It's read-only data with no API behind it.
 */
export function loadCatalog(): Promise<Catalog> {
  if (pending === null) {
    const promise: TrackedPromise<Catalog> = import("./catalog.gen").then(({ catalog }) => {
      // Marked fulfilled, `use` returns the catalog at once instead of suspending again.
      promise.status = "fulfilled";
      promise.value = catalog;
      return catalog;
    });
    pending = promise;
  }
  return pending;
}

/** The catalog, suspending until its chunk has loaded (at once when a route loader loaded it). */
export function useCatalog(): Catalog {
  return use(loadCatalog());
}

interface CatalogIndex {
  dhikrs: Map<string, Dhikr>;
  collections: Map<string, Collection>;
  tags: Map<string, Tag>;
}

const indexes = new WeakMap<Catalog, CatalogIndex>();

function indexFor(catalog: Catalog): CatalogIndex {
  let index = indexes.get(catalog);
  if (index === undefined) {
    index = {
      dhikrs: new Map(catalog.dhikrs.map((dhikr) => [dhikr.key, dhikr])),
      collections: new Map(catalog.collections.map((collection) => [collection.key, collection])),
      tags: new Map(catalog.tags.map((tag) => [tag.key, tag])),
    };
    indexes.set(catalog, index);
  }
  return index;
}

/** The dhikr with `key`, or `undefined` for a key the catalog doesn't have. */
export function findDhikr(catalog: Catalog, key: string): Dhikr | undefined {
  return indexFor(catalog).dhikrs.get(key);
}

/** The collection with `key`, or `undefined`. */
export function findCollection(catalog: Catalog, key: string): Collection | undefined {
  return indexFor(catalog).collections.get(key);
}

/** The catalog tag with `key`, or `undefined`. */
export function findTag(catalog: Catalog, key: string): Tag | undefined {
  return indexFor(catalog).tags.get(key);
}

/** A collection's dhikrs, in its order. */
export function collectionDhikrs(catalog: Catalog, collection: Collection): Dhikr[] {
  return collection.dhikrs.flatMap((key) => findDhikr(catalog, key) ?? []);
}
