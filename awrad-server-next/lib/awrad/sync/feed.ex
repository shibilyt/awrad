defmodule Awrad.Sync.Feed do
  @moduledoc """
  The changes feed (`contracts/sync/v1/README.md`, "Changes feed"; the spec is
  `fixtures/sync_changes_feed.json`).

    * Entities whose revision is above `after`, ordered by revision, then
      `entity_type`, then `entity_id`. `after = 0` lists only active ones.
    * Whole revisions are added until the page holds at least `limit`
      changes: the page ends at the revision of its `limit`-th change, so a
      revision is never split.
    * `has_more` when changes remain after that revision; `next_after` is
      then that revision, and otherwise the head revision.

  **One snapshot.** The head, the page and `has_more` come from a single SQL
  statement, which Postgres runs against one snapshot, so a batch committing
  meanwhile is either wholly in the page or not at all.
  """

  alias Awrad.Repo

  @type page :: %{
          changes: [map()],
          next_after: non_neg_integer(),
          has_more: boolean(),
          head_revision: non_neg_integer()
        }

  # $1 user, $2 after, $3 limit. `cutoff` is the revision of the limit-th
  # matching change (NULL when fewer match); the page is every matching change
  # up to it. The LEFT JOIN keeps one row, with NULL entity columns, for an
  # empty page.
  @page_sql """
  WITH head AS (
    SELECT COALESCE((SELECT head_revision FROM sync_heads WHERE user_id = $1), 0) AS revision
  ),
  matching AS (
    SELECT entity_type, entity_id, state, version, revision, document
    FROM sync_entities
    WHERE user_id = $1 AND revision > $2 AND ($2 > 0 OR state = 'active')
  ),
  cutoff AS (
    SELECT (SELECT revision FROM matching
            ORDER BY revision, entity_type COLLATE "C", entity_id
            OFFSET $3 - 1 LIMIT 1) AS revision
  )
  SELECT head.revision,
         cutoff.revision,
         EXISTS (SELECT 1 FROM matching WHERE matching.revision > cutoff.revision),
         m.entity_type, m.entity_id, m.state, m.version, m.revision, m.document
  FROM head
  CROSS JOIN cutoff
  LEFT JOIN matching m ON cutoff.revision IS NULL OR m.revision <= cutoff.revision
  ORDER BY m.revision, m.entity_type COLLATE "C", m.entity_id
  """

  @doc "The page of `user_id`'s changes after revision `after`, with `limit` from 1 to 500."
  @spec page(Ecto.UUID.t(), non_neg_integer(), 1..500) :: page()
  def page(user_id, after_revision, limit)
      when is_integer(after_revision) and after_revision >= 0 and limit in 1..500 do
    %{rows: [[head, cutoff, has_more | _] | _] = rows} =
      Repo.query!(@page_sql, [Ecto.UUID.dump!(user_id), after_revision, limit])

    changes =
      for [_head, _cutoff, _more, type, id, state, version, revision, document] <- rows,
          type != nil do
        %{
          "entity_type" => type,
          "entity_id" => Ecto.UUID.load!(id),
          "state" => state,
          "version" => version,
          "revision" => revision,
          "document" => document
        }
      end

    %{
      changes: changes,
      next_after: if(has_more, do: cutoff, else: head),
      has_more: has_more,
      head_revision: head
    }
  end
end
