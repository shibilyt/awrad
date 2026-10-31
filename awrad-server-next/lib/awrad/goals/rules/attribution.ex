defmodule Awrad.Goals.Rules.Attribution do
  @moduledoc false
  # Rule: count attribution (fixtures/count_attribution.json, README "Counts:
  # shared and dedicated"). Turns the count log into each goal's count
  # entries:
  #
  # - a shared goal takes every entry of its dhikr without a goal ID;
  # - a dedicated goal takes only entries with its own goal ID;
  # - with sessions in that day's version, an entry goes to its session, and
  #   one without a session the goal has is dropped; without, to the day;
  # - entries sum per day and session, and a sum of 0 or less is no count.
  #
  # It doesn't filter by date: the rules ignore counts outside the active period.

  alias Awrad.Goals.CountEntry
  alias Awrad.Goals.CountLogEntry
  alias Awrad.Goals.Rules.Versions
  alias Awrad.Goals.Timeline

  @type goal :: %{
          id: String.t(),
          dhikr_id: String.t(),
          counts: :shared | :dedicated,
          goal: Versions.input()
        }

  @spec attribute([CountLogEntry.t()], [goal()]) :: [%{id: String.t(), counts: [CountEntry.t()]}]
  def attribute(log, goals) do
    for %{id: id} = goal <- goals do
      timeline = Versions.timeline(goal.goal)

      counts =
        log
        |> Enum.filter(&mine?(goal, &1))
        |> Enum.flat_map(&bucket(timeline, &1))
        |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
        |> Enum.map(fn {{date, session}, amounts} ->
          %{date: date, session: session, count: Enum.sum(amounts)}
        end)
        |> Enum.filter(&(&1.count > 0))
        |> Enum.sort_by(&{Date.to_iso8601(&1.date), &1.session || ""})
        |> Enum.map(&struct!(CountEntry, &1))

      %{id: id, counts: counts}
    end
  end

  defp mine?(%{dhikr_id: dhikr_id, counts: :shared}, %CountLogEntry{
         dhikr_id: dhikr_id,
         goal_id: nil
       }),
       do: true

  defp mine?(%{id: id, dhikr_id: dhikr_id, counts: :dedicated}, %CountLogEntry{
         dhikr_id: dhikr_id,
         goal_id: id
       }),
       do: true

  defp mine?(_goal, _entry), do: false

  defp bucket(%Timeline{} = timeline, %CountLogEntry{practice_day: day} = entry) do
    case Versions.resolve(timeline, day, false).sessions do
      [] ->
        [{{day, nil}, entry.amount}]

      sessions ->
        if Enum.any?(sessions, &(&1.id == entry.session_id)),
          do: [{{day, entry.session_id}, entry.amount}],
          else: []
    end
  end
end
