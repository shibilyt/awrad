defmodule AwradServer.Community do
  @moduledoc """
  Provides public, aggregate community statistics from canonical synced progress.
  """

  import Ecto.Query

  alias AwradServer.ProgressSync.{CountProjection, EntityRecord}
  alias AwradServer.Repo

  @seconds_per_count 1
  @trend_days 7

  def stats(today \\ Date.utc_today()) do
    first_date = Date.add(today, -(@trend_days - 1))

    {goal_count, total_count} =
      Repo.one(
        from entity in active_goals(),
          left_join: projection in CountProjection,
          on:
            projection.user_id == entity.user_id and
              projection.goal_id == entity.entity_id and
              projection.entity_incarnation == entity.incarnation,
          select: {count(entity.id, :distinct), coalesce(sum(projection.count), 0)}
      )

    counts_by_date =
      Repo.all(
        from projection in CountProjection,
          join: entity in subquery(active_goals()),
          on:
            projection.user_id == entity.user_id and
              projection.goal_id == entity.entity_id and
              projection.entity_incarnation == entity.incarnation,
          where: projection.local_date >= ^first_date and projection.local_date <= ^today,
          group_by: projection.local_date,
          select: {projection.local_date, sum(projection.count)}
      )
      |> Map.new()

    total_count = decimal(total_count)

    %{
      as_of: DateTime.utc_now(:second),
      count_semantics: "current_canonical_net",
      total_tracked_goals: goal_count,
      approximate_total_counts: Decimal.to_string(total_count, :normal),
      approximate_dhikr_hours:
        total_count
        |> Decimal.mult(@seconds_per_count)
        |> Decimal.div(3600)
        |> Decimal.round(1)
        |> Decimal.to_float(),
      seconds_per_count: @seconds_per_count,
      daily_counts:
        Enum.map(Date.range(first_date, today), fn date ->
          %{
            date: Date.to_iso8601(date),
            approximate_count:
              counts_by_date |> Map.get(date, 0) |> decimal() |> Decimal.to_string(:normal)
          }
        end)
    }
  end

  defp active_goals do
    from entity in EntityRecord,
      where: entity.entity_type == "goal" and entity.state == "active"
  end

  defp decimal(%Decimal{} = value), do: value
  defp decimal(value) when is_integer(value), do: Decimal.new(value)
end
