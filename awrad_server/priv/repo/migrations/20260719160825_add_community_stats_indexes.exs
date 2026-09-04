defmodule AwradServer.Repo.Migrations.AddCommunityStatsIndexes do
  use Ecto.Migration

  def change do
    create index(
             :progress_sync_entities,
             [:user_id, :entity_id, :incarnation],
             where: "entity_type = 'goal' AND state = 'active'",
             name: :progress_sync_entities_active_goal_stats_index
           )

    create index(
             :progress_sync_count_projections,
             [:user_id, :goal_id, :entity_incarnation, :local_date],
             name: :progress_sync_count_projections_community_stats_index
           )
  end
end
