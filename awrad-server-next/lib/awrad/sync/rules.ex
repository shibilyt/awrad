defmodule Awrad.Sync.Rules do
  @moduledoc """
  The entity rules of a command that passed the envelope, document and state
  checks (`contracts/sync/v1/README.md`, rules 5 and 6).

  `check/3`:

    * `user_tag` create whose `normalized_name` an active tag has: `merged`;
      the new ID becomes an alias of that tag. No entity changes and no
      revision is used.
    * `user_tag` rename onto another active tag's name: `tag_name_taken`.
    * Creating past 100 active tags or 1,000 active custom dhikrs:
      `tag_limit_reached`, `custom_dhikr_limit_reached`.
    * A `custom_dhikr` put naming an uploaded recording: a ready asset of the
      account (`audio_not_found`) with the same size and type
      (`audio_mismatch`), checked after the limit (`Awrad.Sync.AudioReferences`).
    * `dhikr_personal`: its ID must be a built-in dhikr (`Awrad.Dhikrs.Catalog`)
      or an active custom dhikr of the account (`dhikr_not_found`). Its tag
      IDs are rewritten: an alias becomes its tag, a deleted tag is dropped,
      repeats go (first occurrence kept); an ID the account never had is
      `tag_not_found`.
    * `practice_policy`: nothing more; its ID and document were checked
      before (`Awrad.Sync.Commands`).
    * `goal` and `goal_order`: `Awrad.Sync.GoalRules` (slice 4).

  `write/5` applies the command at its revision: the entity's version goes up
  by one, and the cascades share the revision (a deleted tag leaves every
  `dhikr_personal`; a deleted custom dhikr deletes its `dhikr_personal` and
  ends its goals that haven't ended) and are returned for the receipt's
  `cascaded`.
  """

  import Ecto.Query

  alias Awrad.Dhikrs.Catalog
  alias Awrad.Repo
  alias Awrad.Sync.{AudioReferences, Entity, GoalRules, Receipt, TagAlias}

  @max_tags 100
  @max_custom_dhikrs 1_000

  @doc "`{:ok, document_to_store}` (`nil` for a delete), or `{:stop, receipt}`."
  @spec check(Ecto.UUID.t(), map(), Entity.t() | nil, Date.t()) ::
          {:ok, map() | nil} | {:stop, map()}
  def check(_user_id, %{"op" => "delete"}, _entity, _today), do: {:ok, nil}

  def check(user_id, %{"entity_type" => "goal"} = command, entity, today),
    do: GoalRules.check_goal(user_id, command, entity, today)

  def check(user_id, %{"entity_type" => "goal_order"} = command, _entity, _today),
    do: GoalRules.check_goal_order(user_id, command)

  def check(user_id, command, entity, _today), do: check_entity(user_id, command, entity)

  defp check_entity(user_id, %{"entity_type" => "user_tag"} = command, entity) do
    %{"entity_id" => id, "document" => document} = command
    taken = active_tag_named(user_id, document["normalized_name"], id)

    cond do
      is_nil(entity) and taken ->
        merge(user_id, command, taken)

      taken ->
        fields = [%{"field" => "/document/name", "code" => "duplicate"}]
        {:stop, Receipt.rejected(command, "tag_name_taken", fields, entity)}

      is_nil(entity) and count_active(user_id, "user_tag") >= @max_tags ->
        {:stop, Receipt.rejected(command, "tag_limit_reached", [], nil)}

      true ->
        {:ok, document}
    end
  end

  defp check_entity(user_id, %{"entity_type" => "custom_dhikr"} = command, entity) do
    if is_nil(entity) and count_active(user_id, "custom_dhikr") >= @max_custom_dhikrs do
      {:stop, Receipt.rejected(command, "custom_dhikr_limit_reached", [], nil)}
    else
      with :ok <- AudioReferences.check(user_id, command, entity), do: {:ok, command["document"]}
    end
  end

  defp check_entity(user_id, %{"entity_type" => "dhikr_personal"} = command, entity) do
    if dhikr?(user_id, command["entity_id"]) do
      tag_ids(user_id, command, entity)
    else
      fields = [%{"field" => "/entity_id", "code" => "not_found"}]
      {:stop, Receipt.rejected(command, "dhikr_not_found", fields, entity)}
    end
  end

  # Its ID (the account's) and document are already checked.
  defp check_entity(
         _user_id,
         %{"entity_type" => "practice_policy", "document" => document},
         _entity
       ),
       do: {:ok, document}

  defp merge(user_id, command, %Entity{} = tag) do
    Repo.insert!(%TagAlias{
      user_id: user_id,
      alias_id: command["entity_id"],
      tag_id: tag.entity_id
    })

    {:stop,
     %{
       "command_id" => command["command_id"],
       "status" => "merged",
       "merged_into" => tag.entity_id,
       "current" => Entity.current(tag)
     }}
  end

  defp active_tag_named(user_id, normalized_name, except_id) do
    Repo.one(
      from e in active(user_id, "user_tag"),
        where: e.entity_id != ^except_id,
        where: fragment("?->>'normalized_name'", e.document) == ^normalized_name,
        limit: 1
    )
  end

  defp count_active(user_id, type), do: Repo.aggregate(active(user_id, type), :count)

  defp dhikr?(user_id, id),
    do:
      Catalog.builtin?(id) or
        Repo.exists?(from(e in active(user_id, "custom_dhikr"), where: e.entity_id == ^id))

  # Aliases become their tag, deleted tags are dropped, repeats removed; an
  # ID that was never one of the account's tags is an error at its position.
  defp tag_ids(user_id, command, entity) do
    ids = command["document"]["tag_ids"]

    aliases =
      from(a in TagAlias, where: a.user_id == ^user_id and a.alias_id in ^ids)
      |> Repo.all()
      |> Map.new(&{&1.alias_id, &1.tag_id})

    resolved = Enum.map(ids, &Map.get(aliases, &1, &1))

    states =
      from(e in Entity,
        where: e.user_id == ^user_id and e.entity_type == "user_tag" and e.entity_id in ^resolved,
        select: {e.entity_id, e.state}
      )
      |> Repo.all()
      |> Map.new()

    unknown =
      for {id, index} <- Enum.with_index(resolved),
          not Map.has_key?(states, id),
          do: %{"field" => "/document/tag_ids/#{index}", "code" => "not_found"}

    if unknown == [] do
      kept = resolved |> Enum.filter(&(states[&1] == "active")) |> Enum.uniq()
      {:ok, %{"tag_ids" => kept}}
    else
      {:stop, Receipt.rejected(command, "tag_not_found", unknown, entity)}
    end
  end

  @doc """
  Applies the command at `revision`, with its cascades. Returns the entity's
  new version and the receipt's `cascaded`: for a `user_tag` or
  `custom_dhikr` delete, every other entity changed at `revision`
  (`$defs/cascaded_change`), ordered by entity type, then ID, and `[]` when
  nothing cascaded; `nil` for every other command. `today` is the UTC date
  goals a custom dhikr delete ends get (`Awrad.Sync.GoalRules.ended/2`).
  """
  @spec write(
          Ecto.UUID.t(),
          map(),
          Entity.t() | nil,
          {map() | nil, pos_integer()},
          Date.t()
        ) :: {integer(), [map()] | nil}
  def write(user_id, command, nil, {document, revision}, _today) do
    Repo.insert!(%Entity{
      user_id: user_id,
      entity_type: command["entity_type"],
      entity_id: command["entity_id"],
      version: 1,
      revision: revision,
      state: "active",
      document: document
    })

    {1, nil}
  end

  def write(_user_id, %{"op" => "put"}, %Entity{} = entity, {document, revision}, _today) do
    change(entity, "active", document, revision)
    {entity.version + 1, nil}
  end

  def write(user_id, %{"op" => "delete"}, %Entity{} = entity, {nil, revision}, today) do
    change(entity, "deleted", nil, revision)
    {entity.version + 1, cascade(user_id, entity, {revision, today})}
  end

  # A deleted tag leaves every active dhikr_personal that names it.
  defp cascade(user_id, %Entity{entity_type: "user_tag", entity_id: tag_id}, {revision, _today}) do
    from(e in active(user_id, "dhikr_personal"),
      where: fragment("? @> ?", e.document, type(^%{"tag_ids" => [tag_id]}, :map))
    )
    |> Repo.all()
    |> Enum.map(fn personal ->
      tag_ids = List.delete(personal.document["tag_ids"], tag_id)
      change(personal, "active", %{personal.document | "tag_ids" => tag_ids}, revision)
    end)
    |> cascaded()
  end

  # A deleted custom dhikr deletes its dhikr_personal, and ends its goals that
  # haven't ended (active and paused ones; decision 37).
  defp cascade(user_id, %Entity{entity_type: "custom_dhikr", entity_id: id}, {revision, today}) do
    personal =
      from(e in active(user_id, "dhikr_personal"), where: e.entity_id == ^id)
      |> Repo.all()
      |> Enum.map(&change(&1, "deleted", nil, revision))

    goals =
      for goal <- GoalRules.running_goals_of(user_id, id),
          do: change(goal, "active", GoalRules.ended(goal.document, today), revision)

    cascaded(personal ++ goals)
  end

  defp cascade(_user_id, _entity, _context), do: nil

  defp cascaded(entities) do
    entities
    |> Enum.sort_by(&{&1.entity_type, &1.entity_id})
    |> Enum.map(fn %Entity{} = entity ->
      %{
        "entity_type" => entity.entity_type,
        "entity_id" => entity.entity_id,
        "state" => entity.state,
        "version" => entity.version,
        "revision" => entity.revision
      }
    end)
  end

  defp change(%Entity{} = entity, state, document, revision) do
    entity
    |> Ecto.Changeset.change(
      state: state,
      document: document,
      version: entity.version + 1,
      revision: revision
    )
    |> Repo.update!()
  end

  defp active(user_id, type) do
    from e in Entity,
      where: e.user_id == ^user_id and e.entity_type == ^type and e.state == "active"
  end
end
