defmodule AwradServer.PracticeDayTest do
  use ExUnit.Case, async: true

  alias AwradServer.PracticeDay

  @civil_date ~D[2026-09-09]
  @before_maghrib ~U[2026-09-09 12:00:00Z]
  @maghrib ~U[2026-09-09 18:00:00Z]
  @after_maghrib ~U[2026-09-09 18:00:01Z]

  test "midnight reset always uses the civil date" do
    assert {:ok, result} =
             PracticeDay.resolve(%{
               now: @after_maghrib,
               civil_date: @civil_date,
               day_reset: "midnight",
               maghrib_at: @maghrib
             })

    assert result.effective_date == @civil_date
    assert result.status == :midnight
  end

  test "Maghrib reset keeps the civil date before Maghrib" do
    assert {:ok, result} =
             PracticeDay.resolve(%{
               now: @before_maghrib,
               civil_date: @civil_date,
               day_reset: "maghrib",
               maghrib_at: @maghrib
             })

    assert result.effective_date == @civil_date
    assert result.status == :maghrib
  end

  test "Maghrib reset advances at the boundary" do
    assert {:ok, result} =
             PracticeDay.resolve(%{
               now: @maghrib,
               civil_date: @civil_date,
               day_reset: "maghrib",
               maghrib_at: @maghrib
             })

    assert result.effective_date == Date.add(@civil_date, 1)
    assert result.status == :maghrib
  end

  test "missing Maghrib falls back to the civil date and explains why" do
    assert {:ok, result} =
             PracticeDay.resolve(%{
               now: @after_maghrib,
               civil_date: @civil_date,
               day_reset: "maghrib",
               maghrib_at: nil
             })

    assert result.effective_date == @civil_date
    assert result.status == :location_required
    assert result.maghrib_at == nil
  end

  test "an invalid browser boundary uses a safe midnight fallback" do
    assert {:ok, result} =
             PracticeDay.resolve(%{
               now: @after_maghrib,
               civil_date: @civil_date,
               day_reset: "maghrib",
               maghrib_at: "not-a-timestamp"
             })

    assert result.effective_date == @civil_date
    assert result.status == :calculation_unavailable
    assert result.maghrib_at == nil
  end
end
