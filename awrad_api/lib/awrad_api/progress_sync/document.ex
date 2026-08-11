defmodule AwradApi.ProgressSync.Document do
  @moduledoc false

  @uuid_v4 ~r/\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/
  @max_int64 9_223_372_036_854_775_807
  @min_int64 -9_223_372_036_854_775_808
  @max_document_bytes 512_000
  @max_string_bytes 65_536
  @max_benefits 128
  @max_specific_dates 3_660
  @dhikr_keys ~w(id catalog_key is_custom title arabic transliteration translation audio_url audio_file_name category categories audio_count_per_play sort_order quran_ref benefits)
  @goal_keys ~w(id dhikr_id target_policy count_policy completion_policy slot_counting_policy recurrence slots reminders start_date end_date duration_days is_active completed_at created_at updated_at)
  @slot_keys ~w(id goal_id slot_type count_policy prayer_name prayer_relation start_minute end_minute start_lead_minutes_override label sort_order is_active archived_at)
  @reminder_keys ~w(id goal_id slot_id reminder_type hour minute offset_minutes enabled sort_order)
  @policy_keys ~w(minimum_count target_count maximum_count streak_threshold reminder_threshold completion_threshold cap_behavior)
  @recurrence_keys ~w(frequency calendar interval_days anchor_date month season_code weekdays month_days specific_dates)
  @categories ~w(morning evening after_salah forgiveness praise protection general swalaths asma_ul_husna ramadan quran)
  @user_tag_keys ~w(id name normalized_name created_at updated_at)
  @dhikr_tag_assignment_keys ~w(id tag_id dhikr_id created_at)
  @max_tag_name_graphemes 40
  @max_tag_name_bytes 128

  def validate(type, document, entity_id), do: validate(type, document, entity_id, nil)

  def validate("custom_dhikr", document, entity_id, existing_document) do
    document =
      document
      |> fill_nullable(~w(catalog_key audio_url audio_file_name quran_ref))
      |> fill_dhikr_categories(existing_document)

    with :ok <- document_size(document),
         :ok <- exact_keys(document, @dhikr_keys),
         :ok <- uuid(value(document, "id"), entity_id),
         true <- value(document, "is_custom") == true,
         true <- is_nil(value(document, "catalog_key")),
         :ok <- non_empty_strings(document, ~w(title arabic transliteration translation)),
         true <- value(document, "category") in @categories,
         :ok <- dhikr_categories(value(document, "categories"), value(document, "category")),
         :ok <- positive_integer(value(document, "audio_count_per_play")),
         :ok <- non_negative_integer(value(document, "sort_order")),
         :ok <- benefits(value(document, "benefits")),
         :ok <- quran_ref(value(document, "quran_ref")),
         :ok <- optional_string(value(document, "audio_url")),
         :ok <- optional_string(value(document, "audio_file_name")) do
      {:ok, stringify_keys(document)}
    else
      _ -> {:error, :invalid_entity_document}
    end
  end

  def validate("goal", document, entity_id, _existing_document) do
    document = fill_nullable(document, ~w(end_date duration_days completed_at))

    with :ok <- document_size(document),
         :ok <- exact_keys(document, @goal_keys),
         :ok <- uuid(value(document, "id"), entity_id),
         :ok <- uuid(value(document, "dhikr_id")),
         true <-
           value(document, "target_policy") in ~w(per_due_date cumulative_total period_total none),
         {:ok, policy} <- count_policy(value(document, "count_policy")),
         true <-
           value(document, "completion_policy") in ~w(never when_target_reached duration_ended),
         true <-
           value(document, "slot_counting_policy") in ~w(warn_and_allow strict_active_only silent_flexible),
         {:ok, recurrence} <- recurrence(value(document, "recurrence")),
         {:ok, slots} <- slots(value(document, "slots"), entity_id),
         {:ok, reminders} <- reminders(value(document, "reminders"), entity_id, slots),
         :ok <- date(value(document, "start_date")),
         :ok <- optional_date(value(document, "end_date")),
         :ok <- optional_positive_integer(value(document, "duration_days")),
         true <- is_boolean(value(document, "is_active")),
         :ok <- optional_timestamp(value(document, "completed_at")),
         :ok <- timestamp(value(document, "created_at")),
         :ok <- timestamp(value(document, "updated_at")) do
      {:ok,
       document
       |> stringify_keys()
       |> Map.put("count_policy", policy)
       |> Map.put("recurrence", recurrence)
       |> Map.put("slots", slots)
       |> Map.put("reminders", reminders)}
    else
      _ -> {:error, :invalid_entity_document}
    end
  end

  def validate("user_tag", document, entity_id, _existing_document) do
    with :ok <- document_size(document),
         :ok <- exact_keys(document, @user_tag_keys),
         :ok <- uuid(value(document, "id"), entity_id),
         {:ok, display, normalized} <- normalize_tag_name(value(document, "name")),
         true <- value(document, "normalized_name") == normalized,
         :ok <- timestamp(value(document, "created_at")),
         :ok <- timestamp(value(document, "updated_at")) do
      {:ok,
       document
       |> stringify_keys()
       |> Map.put("name", display)
       |> Map.put("normalized_name", normalized)}
    else
      _ -> {:error, :invalid_entity_document}
    end
  end

  def validate("dhikr_tag_assignment", document, entity_id, _existing_document) do
    with :ok <- document_size(document),
         :ok <- exact_keys(document, @dhikr_tag_assignment_keys),
         :ok <- uuid(value(document, "id"), entity_id),
         :ok <- uuid(value(document, "tag_id")),
         :ok <- uuid(value(document, "dhikr_id")),
         :ok <- timestamp(value(document, "created_at")) do
      {:ok, stringify_keys(document)}
    else
      _ -> {:error, :invalid_entity_document}
    end
  end

  def validate(_, _, _, _), do: {:error, :invalid_entity_document}

  @doc """
  Shared user-tag normalization.

  Algorithm (locked by
  `contracts/behavior-model/v1/fixtures/tag-normalization-contract.json`):

  1. trim/collapse Unicode White_Space (`[[:space:]]`) to a single U+0020
  2. NFC-normalize for display `name`
  3. Unicode Default Case Fold (`:string.casefold/1`) then NFC for
     `normalized_name`
  """
  def normalize_tag_name(raw) when is_binary(raw) do
    display =
      raw
      |> String.trim()
      |> String.replace(~r/[[:space:]]+/u, " ")
      |> nfc()

    with true <- is_binary(display),
         true <- display != "",
         true <- String.length(display) <= @max_tag_name_graphemes,
         true <- byte_size(display) <= @max_tag_name_bytes,
         normalized when is_binary(normalized) <- nfc(case_fold(display)) do
      {:ok, display, normalized}
    else
      _ -> :error
    end
  end

  def normalize_tag_name(_), do: :error

  defp nfc(value) when is_binary(value) do
    case :unicode.characters_to_nfc_binary(value) do
      normalized when is_binary(normalized) -> normalized
      _ -> :error
    end
  end

  defp nfc(_), do: :error

  defp case_fold(value) when is_binary(value) do
    value
    |> String.to_charlist()
    |> :string.casefold()
    |> List.to_string()
  end

  defp slots(items, goal_id) when is_list(items) and length(items) <= 64 do
    reduce_unique(items, fn item ->
      item =
        fill_nullable(
          item,
          ~w(prayer_name prayer_relation start_minute end_minute start_lead_minutes_override label archived_at)
        )

      with :ok <- exact_keys(item, @slot_keys),
           :ok <- uuid(value(item, "id")),
           :ok <- uuid(value(item, "goal_id"), goal_id),
           true <- value(item, "slot_type") in ~w(anytime prayer time_window),
           {:ok, policy} <- count_policy(value(item, "count_policy")),
           :ok <- optional_string(value(item, "prayer_name")),
           true <- value(item, "prayer_relation") in [nil, "before", "after"],
           :ok <- optional_minute(value(item, "start_minute")),
           :ok <- optional_minute(value(item, "end_minute")),
           :ok <- optional_non_negative_integer(value(item, "start_lead_minutes_override")),
           :ok <- optional_string(value(item, "label")),
           :ok <- non_negative_integer(value(item, "sort_order")),
           true <- is_boolean(value(item, "is_active")),
           :ok <- optional_timestamp(value(item, "archived_at")) do
        normalized = stringify_keys(item) |> Map.put("count_policy", policy)
        {:ok, value(normalized, "id"), normalized}
      else
        _ -> {:error, :invalid_entity_document}
      end
    end)
  end

  defp slots(_, _), do: {:error, :invalid_entity_document}

  defp reminders(items, goal_id, slots) when is_list(items) and length(items) <= 128 do
    slot_ids = MapSet.new(slots, &value(&1, "id"))

    reduce_unique(items, fn item ->
      item = fill_nullable(item, ~w(slot_id hour minute offset_minutes))
      slot_id = value(item, "slot_id")

      with :ok <- exact_keys(item, @reminder_keys),
           :ok <- uuid(value(item, "id")),
           :ok <- uuid(value(item, "goal_id"), goal_id),
           true <- is_nil(slot_id) or MapSet.member?(slot_ids, slot_id),
           true <- value(item, "reminder_type") in ~w(fixed_time prayer_offset time_window_start),
           :ok <- optional_hour(value(item, "hour")),
           :ok <- optional_minute(value(item, "minute")),
           :ok <- optional_integer(value(item, "offset_minutes")),
           true <- is_boolean(value(item, "enabled")),
           :ok <- non_negative_integer(value(item, "sort_order")) do
        normalized = stringify_keys(item)
        {:ok, value(normalized, "id"), normalized}
      else
        _ -> {:error, :invalid_entity_document}
      end
    end)
  end

  defp reminders(_, _, _), do: {:error, :invalid_entity_document}

  defp reduce_unique(items, validator) do
    Enum.reduce_while(items, {:ok, MapSet.new(), []}, fn item, {:ok, ids, acc} ->
      case validator.(item) do
        {:ok, id, normalized} ->
          if MapSet.member?(ids, id) do
            {:halt, {:error, :invalid_entity_document}}
          else
            {:cont, {:ok, MapSet.put(ids, id), [normalized | acc]}}
          end

        _ ->
          {:halt, {:error, :invalid_entity_document}}
      end
    end)
    |> case do
      {:ok, _ids, normalized} -> {:ok, Enum.reverse(normalized)}
      error -> error
    end
  end

  defp count_policy(policy) do
    policy = fill_nullable(policy, ~w(minimum_count target_count maximum_count))

    with :ok <- exact_keys(policy, @policy_keys),
         :ok <- optional_positive_integer(value(policy, "minimum_count")),
         :ok <- optional_positive_integer(value(policy, "target_count")),
         :ok <- optional_positive_integer(value(policy, "maximum_count")),
         :ok <- threshold(value(policy, "streak_threshold")),
         :ok <- threshold(value(policy, "reminder_threshold")),
         :ok <- threshold(value(policy, "completion_threshold")),
         true <-
           value(policy, "cap_behavior") in ~w(allow_over_target warn_over_target block_at_target block_at_maximum) do
      {:ok, stringify_keys(policy)}
    else
      _ -> {:error, :invalid_entity_document}
    end
  end

  defp recurrence(recurrence) do
    recurrence = fill_nullable(recurrence, ~w(interval_days anchor_date month season_code))

    with :ok <- exact_keys(recurrence, @recurrence_keys),
         true <-
           value(recurrence, "frequency") in ~w(daily weekly monthly interval yearly season specific_dates),
         true <- value(recurrence, "calendar") in ~w(gregorian hijri),
         :ok <- optional_positive_integer(value(recurrence, "interval_days")),
         :ok <- optional_date(value(recurrence, "anchor_date")),
         :ok <- optional_range(value(recurrence, "month"), 1..12),
         :ok <- optional_string(value(recurrence, "season_code")),
         :ok <- unique_range_list(value(recurrence, "weekdays"), 1..7),
         :ok <- unique_range_list(value(recurrence, "month_days"), 1..31),
         :ok <- unique_dates(value(recurrence, "specific_dates")) do
      {:ok, stringify_keys(recurrence)}
    else
      _ -> {:error, :invalid_entity_document}
    end
  end

  defp threshold(value) when value in ~w(any_positive minimum target maximum), do: :ok
  defp threshold(%{"type" => "custom", "count" => count}), do: positive_integer(count)
  defp threshold(%{type: "custom", count: count}), do: positive_integer(count)
  defp threshold(_), do: :error

  defp quran_ref(nil), do: :ok

  defp quran_ref(ref) when is_map(ref) do
    ref = fill_nullable(ref, ~w(ayah_end))
    ayah_end = value(ref, "ayah_end")

    with :ok <- exact_keys(ref, ~w(surah ayah_start ayah_end)),
         :ok <- range(value(ref, "surah"), 1..114),
         :ok <- positive_integer(value(ref, "ayah_start")),
         :ok <- optional_positive_integer(ayah_end),
         true <- is_nil(ayah_end) or value(ref, "ayah_start") <= ayah_end do
      :ok
    else
      _ -> :error
    end
  end

  defp quran_ref(_), do: :error

  defp exact_keys(map, keys) when is_map(map) do
    if MapSet.new(Map.keys(map), &to_string/1) == MapSet.new(keys), do: :ok, else: :error
  end

  defp exact_keys(_, _), do: :error

  defp uuid(value, expected \\ nil)

  defp uuid(value, expected) when is_binary(value) do
    if Regex.match?(@uuid_v4, value) and (is_nil(expected) or value == expected),
      do: :ok,
      else: :error
  end

  defp uuid(_, _), do: :error

  defp date(value) when is_binary(value),
    do: if(match?({:ok, _}, Date.from_iso8601(value)), do: :ok, else: :error)

  defp date(_), do: :error
  defp optional_date(nil), do: :ok
  defp optional_date(value), do: date(value)

  defp timestamp(value) when is_binary(value) and byte_size(value) <= 128 do
    if String.ends_with?(value, "Z") and match?({:ok, _, 0}, DateTime.from_iso8601(value)),
      do: :ok,
      else: :error
  end

  defp timestamp(_), do: :error
  defp optional_timestamp(nil), do: :ok
  defp optional_timestamp(value), do: timestamp(value)

  defp positive_integer(value) when is_integer(value) and value > 0 and value <= @max_int64,
    do: :ok

  defp positive_integer(_), do: :error

  defp non_negative_integer(value)
       when is_integer(value) and value >= 0 and value <= @max_int64,
       do: :ok

  defp non_negative_integer(_), do: :error
  defp optional_positive_integer(nil), do: :ok
  defp optional_positive_integer(value), do: positive_integer(value)
  defp optional_non_negative_integer(nil), do: :ok
  defp optional_non_negative_integer(value), do: non_negative_integer(value)
  defp optional_integer(nil), do: :ok

  defp optional_integer(value)
       when is_integer(value) and value >= @min_int64 and value <= @max_int64,
       do: :ok

  defp optional_integer(_), do: :error
  defp optional_string(nil), do: :ok

  defp optional_string(value) when is_binary(value) and byte_size(value) <= @max_string_bytes,
    do: :ok

  defp optional_string(_), do: :error
  defp optional_minute(nil), do: :ok
  defp optional_minute(value), do: range(value, 0..1439)
  defp optional_hour(nil), do: :ok
  defp optional_hour(value), do: range(value, 0..23)
  defp optional_range(nil, _range), do: :ok
  defp optional_range(value, range), do: range(value, range)
  defp range(value, range) when is_integer(value), do: if(value in range, do: :ok, else: :error)
  defp range(_, _), do: :error

  defp unique_range_list(values, range) when is_list(values) do
    if Enum.uniq(values) == values and Enum.all?(values, &(is_integer(&1) and &1 in range)),
      do: :ok,
      else: :error
  end

  defp unique_range_list(_, _), do: :error

  defp unique_dates(values) when is_list(values) and length(values) <= @max_specific_dates do
    if Enum.uniq(values) == values and Enum.all?(values, &(date(&1) == :ok)),
      do: :ok,
      else: :error
  end

  defp unique_dates(_), do: :error

  defp non_empty_strings(map, keys),
    do:
      if(
        Enum.all?(keys, fn key ->
          item = value(map, key)
          is_binary(item) and item != "" and byte_size(item) <= @max_string_bytes
        end),
        do: :ok,
        else: :error
      )

  defp benefits(values) when is_list(values) and length(values) <= @max_benefits do
    if Enum.all?(values, &(is_binary(&1) and byte_size(&1) <= @max_string_bytes)),
      do: :ok,
      else: :error
  end

  defp benefits(_), do: :error

  defp dhikr_categories([primary | _] = categories, primary)
       when length(categories) <= length(@categories) do
    if Enum.uniq(categories) == categories and Enum.all?(categories, &(&1 in @categories)),
      do: :ok,
      else: :error
  end

  defp dhikr_categories(_, _), do: :error

  defp document_size(document) when is_map(document) do
    case Jason.encode(document) do
      {:ok, encoded} when byte_size(encoded) <= @max_document_bytes -> :ok
      _ -> :error
    end
  end

  defp document_size(_), do: :error

  defp stringify_keys(map), do: Map.new(map, fn {key, value} -> {to_string(key), value} end)

  defp fill_nullable(map, keys) when is_map(map) do
    Enum.reduce(keys, stringify_keys(map), &Map.put_new(&2, &1, nil))
  end

  defp fill_nullable(value, _keys), do: value

  defp fill_dhikr_categories(map, existing_document) when is_map(map) do
    if Map.has_key?(map, "categories") do
      map
    else
      Map.put(map, "categories", legacy_dhikr_categories(map, existing_document))
    end
  end

  defp fill_dhikr_categories(value, _existing_document), do: value

  defp legacy_dhikr_categories(document, existing_document) when is_map(existing_document) do
    primary = value(document, "category")
    previous_primary = value(existing_document, "category")

    existing_categories =
      case value(existing_document, "categories") do
        categories when is_list(categories) and categories != [] -> categories
        _ -> [previous_primary]
      end

    if primary == previous_primary do
      existing_categories
    else
      [primary | Enum.reject(existing_categories, &(&1 in [primary, previous_primary]))]
    end
  end

  defp legacy_dhikr_categories(document, _existing_document),
    do: [value(document, "category")]

  defp value(map, key) when is_map(map) do
    case Map.fetch(map, key) do
      {:ok, value} ->
        value

      :error ->
        Enum.find_value(map, fn {candidate, value} ->
          if to_string(candidate) == key, do: {:found, value}
        end)
        |> unwrap_found()
    end
  end

  defp value(_, _), do: nil
  defp unwrap_found({:found, value}), do: value
  defp unwrap_found(nil), do: nil
end
