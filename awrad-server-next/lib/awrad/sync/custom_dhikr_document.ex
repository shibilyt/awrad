defmodule Awrad.Sync.CustomDhikrDocument do
  @moduledoc """
  Checks a `custom_dhikr` document against `urn:awrad:sync:1#/$defs/custom_dhikr_document`
  by hand, reporting each problem as the `{field, code}` errors of
  `contracts/sync/v1/fixtures/custom_dhikr_validity.json`:

    * `required`: a member, or a language key, that's missing (or `null` where
      text is needed); `/title` when no title language has text;
    * `blank`: text that's empty or only whitespace (the schema's `\\S`);
    * `too_long`: over 120 code points for a title, 5,000 for the other texts;
    * `too_many`: more than 20 references;
    * `not_allowed`: a member the shape doesn't have (`id`, `key`, `aliases`,
      `virtues`, catalog `tags`, an unknown language);
    * `invalid`: a wrong type or value (`kind`, `audio`, a whole reference).
      `audio` is `null`, `{"local_only": true}`, or an uploaded recording
      `{asset_id, byte_size, content_type, duration_ms}` (slice 3c);
    * `range`: a valid Qur'an reference whose `ayah_end` is below its
      `ayah_start`, on `/references/N/ayah_end` (the one rule the schema
      can't express).

  Lengths count Unicode code points. Fields are JSON Pointers into the
  document; errors are sorted by field, then code.
  """

  @kinds ~w(quran dhikr dua salawat name_of_allah)
  @members ~w(kind arabic title transliteration translation audio references)
  @title_max 120
  @long_max 5_000
  @max_references 20
  @max_int53 9_007_199_254_740_991

  # ECMAScript's \s, which the schema's "\\S" pattern is written in.
  @blank ~r/\A[\x{0009}-\x{000D}\x{0020}\x{00A0}\x{1680}\x{2000}-\x{200A}\x{2028}\x{2029}\x{202F}\x{205F}\x{3000}\x{FEFF}]*\z/u
  @key ~r/\A[a-z0-9]+(-[a-z0-9]+)*\z/

  # Reference type => {required members, optional members}. Every member but
  # the ID and type (and quran's integers, and other's url) is catalog text.
  @references %{
    "quran" => {~w(surah ayah_start ayah_end), []},
    "hadith" => {~w(collection), ~w(number narrator grade)},
    "book" => {~w(title), ~w(author volume page)},
    "shaykh" => {~w(name), ~w(note)},
    "other" => {~w(text), ~w(url)}
  }

  @type error :: %{required(String.t()) => String.t()}

  @doc "The document's errors, sorted; `[]` when it's valid."
  @spec errors(term()) :: [error()]
  def errors(document) when is_map(document) do
    unknown =
      for key <- Map.keys(document), key not in @members, do: {pointer([key]), "not_allowed"}

    known =
      [
        kind(Map.fetch(document, "kind")),
        text(Map.fetch(document, "arabic"), ["arabic"], @long_max),
        languages(Map.fetch(document, "title"), "title", ~w(en ar ml), @title_max, true),
        languages(
          Map.fetch(document, "transliteration"),
          "transliteration",
          ~w(en ml),
          @long_max,
          false
        ),
        languages(
          Map.fetch(document, "translation"),
          "translation",
          ~w(en ar ml),
          @long_max,
          false
        ),
        audio(Map.fetch(document, "audio")),
        references(Map.fetch(document, "references"))
      ]

    (unknown ++ List.flatten(known))
    |> Enum.sort()
    |> Enum.map(fn {field, code} -> %{"field" => field, "code" => code} end)
  end

  def errors(_not_an_object), do: [%{"field" => "", "code" => "invalid"}]

  defp kind(:error), do: [{"/kind", "required"}]
  defp kind({:ok, nil}), do: [{"/kind", "required"}]
  defp kind({:ok, kind}) when kind in @kinds, do: []
  defp kind({:ok, _other}), do: [{"/kind", "invalid"}]

  # A required text member.
  defp text(:error, path, _max), do: [{pointer(path), "required"}]
  defp text({:ok, nil}, path, _max), do: [{pointer(path), "required"}]
  defp text({:ok, value}, path, max), do: text_value(value, path, max)

  defp text_value(value, path, max) when is_binary(value) do
    cond do
      Regex.match?(@blank, value) -> [{pointer(path), "blank"}]
      code_points(value) > max -> [{pointer(path), "too_long"}]
      true -> []
    end
  end

  defp text_value(_value, path, _max), do: [{pointer(path), "invalid"}]

  # {lang: text or null} with every language key present.
  defp languages(:error, member, _langs, _max, _one_needed), do: [{pointer([member]), "required"}]

  defp languages({:ok, nil}, member, _langs, _max, _one_needed),
    do: [{pointer([member]), "required"}]

  defp languages({:ok, object}, member, langs, max, one_needed) when is_map(object) do
    unknown =
      for key <- Map.keys(object), key not in langs, do: {pointer([member, key]), "not_allowed"}

    per_language =
      for lang <- langs do
        case Map.fetch(object, lang) do
          :error -> [{pointer([member, lang]), "required"}]
          {:ok, nil} -> []
          {:ok, value} -> text_value(value, [member, lang], max)
        end
      end

    has_text? = Enum.any?(langs, &is_binary(Map.get(object, &1)))
    missing = if one_needed and not has_text?, do: [{pointer([member]), "required"}], else: []

    unknown ++ List.flatten(per_language) ++ missing
  end

  defp languages({:ok, _other}, member, _langs, _max, _one_needed),
    do: [{pointer([member]), "invalid"}]

  defp audio(:error), do: [{"/audio", "required"}]
  defp audio({:ok, nil}), do: []
  defp audio({:ok, %{"local_only" => true} = audio}) when map_size(audio) == 1, do: []

  defp audio({:ok, audio}) do
    if uploaded_audio?(audio), do: [], else: [{"/audio", "invalid"}]
  end

  # `$defs/uploaded_audio`: every member present, nothing else. Whether the
  # asset exists and agrees is the entity rules' (`audio_not_found`,
  # `audio_mismatch`), not the document's.
  defp uploaded_audio?(
         %{
           "asset_id" => asset_id,
           "byte_size" => byte_size,
           "content_type" => content_type,
           "duration_ms" => duration_ms
         } = audio
       )
       when map_size(audio) == 4 and is_binary(asset_id) and is_integer(byte_size) and
              is_binary(content_type) do
    Awrad.ID.valid?(asset_id) and Awrad.Audio.recording?(byte_size, content_type) and
      (is_nil(duration_ms) or (is_integer(duration_ms) and duration_ms in 1..@max_int53))
  end

  defp uploaded_audio?(_other), do: false

  defp references(:error), do: [{"/references", "required"}]
  defp references({:ok, nil}), do: [{"/references", "required"}]

  defp references({:ok, list}) when is_list(list) do
    too_many = if length(list) > @max_references, do: [{"/references", "too_many"}], else: []

    per_reference =
      for {reference, index} <- Enum.with_index(list) do
        cond do
          not reference?(reference) ->
            [{pointer(["references", Integer.to_string(index)]), "invalid"}]

          reversed?(reference) ->
            [{pointer(["references", Integer.to_string(index), "ayah_end"]), "range"}]

          true ->
            []
        end
      end

    too_many ++ List.flatten(per_reference)
  end

  defp references({:ok, _other}), do: [{"/references", "invalid"}]

  # urn:awrad:dhikr-catalog:1#/$defs/reference
  defp reference?(%{"type" => type, "id" => id} = reference) when is_binary(id) do
    case Map.fetch(@references, type) do
      {:ok, {required, optional}} ->
        allowed = ["id", "type" | required ++ optional]

        Regex.match?(@key, id) and Enum.all?(Map.keys(reference), &(&1 in allowed)) and
          Enum.all?(required, &Map.has_key?(reference, &1)) and
          Enum.all?(required ++ optional, &member?(type, &1, Map.get(reference, &1, :absent)))

      :error ->
        false
    end
  end

  defp reference?(_other), do: false

  # A valid Qur'an reference that ends before it starts.
  defp reversed?(%{"type" => "quran", "ayah_start" => start, "ayah_end" => stop}),
    do: stop < start

  defp reversed?(_reference), do: false

  defp member?(_type, _name, :absent), do: true
  defp member?("quran", "surah", value), do: is_integer(value) and value in 1..114
  defp member?("quran", _ayah, value), do: is_integer(value) and value >= 1
  defp member?("other", "url", value), do: is_binary(value)
  defp member?(_type, _text, value), do: is_binary(value) and not Regex.match?(@blank, value)

  defp code_points(text), do: text |> String.codepoints() |> length()

  # A JSON Pointer (RFC 6901) to the member at `path`.
  defp pointer(path) do
    Enum.map_join(path, fn segment ->
      "/" <> (segment |> String.replace("~", "~0") |> String.replace("/", "~1"))
    end)
  end
end
