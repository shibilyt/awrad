defmodule Awrad.Sync.Shape do
  @moduledoc """
  Small parsers for checking a JSON document against its schema by hand and
  turning it into domain values at once (the goal and goal order documents,
  slice 4). A parser takes a value and its path, and returns `{:ok, value}`
  or `{:error, errors}`, each error a `{pointer, code}` into the document:

    * `required`: a member that's missing, or `null` where it can't be;
    * `not_allowed`: a member the object doesn't have;
    * `invalid`: a wrong type or value (out of range or not in the enum);
    * `blank`, `too_long`: text that's empty or whitespace, or over its
      length in code points;
    * `required`, `too_many`: a list under its minimum or over its maximum;
    * `duplicate`: a list whose items must be unique, on the list.
  """

  @type path :: [String.t() | non_neg_integer()]
  @type error :: {String.t(), String.t()}
  @type result :: {:ok, term()} | {:error, [error(), ...]}
  @type parser :: (term(), path() -> result())

  # ECMAScript's \s, which the schemas' "\\S" pattern is written in.
  @blank ~r/\A[\x{0009}-\x{000D}\x{0020}\x{00A0}\x{1680}\x{2000}-\x{200A}\x{2028}\x{2029}\x{202F}\x{205F}\x{3000}\x{FEFF}]*\z/u
  @date ~r/\A\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])\z/
  @time ~r/\A([01]\d|2[0-3]):[0-5]\d\z/

  @doc "Runs `parser` on a whole document: `{:ok, value}` or its errors, sorted by field, then code."
  @spec run(parser(), term()) :: {:ok, term()} | {:error, [%{String.t() => String.t()}, ...]}
  def run(parser, value) do
    case parser.(value, []) do
      {:ok, parsed} -> {:ok, parsed}
      {:error, errors} -> {:error, errors |> Enum.uniq() |> Enum.sort() |> Enum.map(&field/1)}
    end
  end

  defp field({pointer, code}), do: %{"field" => pointer, "code" => code}

  @doc """
  An object with exactly `members`, `{name, parser}` each, all required. The
  value is a map from each name to its parsed value.
  """
  @spec object([{String.t(), parser()}]) :: parser()
  def object(members) do
    fn
      value, path when is_map(value) ->
        names = Enum.map(members, &elem(&1, 0))

        unknown =
          for key <- Map.keys(value),
              key not in names,
              do: {pointer(path ++ [key]), "not_allowed"}

        parsed = for {name, parser} <- members, do: {name, member(value, name, parser, path)}
        collect(parsed, unknown)

      nil, path ->
        required(path)

      _other, path ->
        invalid(path)
    end
  end

  defp member(object, name, parser, path) do
    case Map.fetch(object, name) do
      {:ok, value} -> parser.(value, path ++ [name])
      :error -> required(path ++ [name])
    end
  end

  defp collect(parsed, unknown) do
    errors = Enum.flat_map(parsed, fn {_name, result} -> errors_of(result) end) ++ unknown

    if errors == [],
      do: {:ok, Map.new(parsed, fn {name, {:ok, value}} -> {name, value} end)},
      else: {:error, errors}
  end

  @doc """
  An object chosen by its `tag` member's value: `variants` maps each value to
  the object's other members. The parsed map keeps the tag's value.
  """
  @spec tagged(String.t(), %{String.t() => [{String.t(), parser()}]}) :: parser()
  def tagged(tag, variants) do
    fn
      %{^tag => kind} = value, path when is_map_key(variants, kind) ->
        object([{tag, fn kind, _path -> {:ok, kind} end} | Map.fetch!(variants, kind)]).(
          value,
          path
        )

      %{^tag => _other}, path ->
        invalid(path ++ [tag])

      value, path when is_map(value) ->
        required(path ++ [tag])

      nil, path ->
        required(path)

      _other, path ->
        invalid(path)
    end
  end

  @doc "`parser`, or `null`."
  @spec nullable(parser()) :: parser()
  def nullable(parser) do
    fn
      nil, _path -> {:ok, nil}
      value, path -> parser.(value, path)
    end
  end

  @doc "A value of `values` (strings to what they parse to)."
  @spec enum(%{String.t() => term()}) :: parser()
  def enum(values) do
    fn
      nil, path -> required(path)
      value, _path when is_map_key(values, value) -> {:ok, Map.fetch!(values, value)}
      _other, path -> invalid(path)
    end
  end

  @spec integer(integer(), integer()) :: parser()
  def integer(min, max) do
    fn
      nil, path -> required(path)
      value, _path when is_integer(value) and value >= min and value <= max -> {:ok, value}
      _other, path -> invalid(path)
    end
  end

  @doc "A calendar day, `YYYY-MM-DD`, that exists."
  @spec date() :: parser()
  def date do
    fn
      nil, path ->
        required(path)

      value, path when is_binary(value) ->
        with true <- Regex.match?(@date, value), {:ok, date} <- Date.from_iso8601(value) do
          {:ok, date}
        else
          _not_a_day -> invalid(path)
        end

      _other, path ->
        invalid(path)
    end
  end

  @doc "A local time of day, `HH:MM`."
  @spec time() :: parser()
  def time do
    fn
      nil, path ->
        required(path)

      value, path when is_binary(value) ->
        if Regex.match?(@time, value),
          do: {:ok, Time.from_iso8601!(value <> ":00")},
          else: invalid(path)

      _other, path ->
        invalid(path)
    end
  end

  @spec uuid() :: parser()
  def uuid, do: string(&Awrad.ID.valid?/1)

  @doc "A string matching `valid?`."
  @spec string((String.t() -> boolean())) :: parser()
  def string(valid?) do
    fn
      nil, path ->
        required(path)

      value, path when is_binary(value) ->
        if valid?.(value), do: {:ok, value}, else: invalid(path)

      _other, path ->
        invalid(path)
    end
  end

  @doc "Text with something besides whitespace, at most `max` code points."
  @spec text(pos_integer()) :: parser()
  def text(max) do
    fn
      nil, path ->
        required(path)

      value, path when is_binary(value) ->
        cond do
          Regex.match?(@blank, value) ->
            {:error, [{pointer(path), "blank"}]}

          value |> String.codepoints() |> length() > max ->
            {:error, [{pointer(path), "too_long"}]}

          true ->
            {:ok, value}
        end

      _other, path ->
        invalid(path)
    end
  end

  @doc "A list of `parser` items, `min` to `max` of them, unique when `unique?`."
  @spec list(parser(), keyword()) :: parser()
  def list(parser, opts \\ []) do
    min = Keyword.get(opts, :min, 0)
    max = Keyword.get(opts, :max)
    unique? = Keyword.get(opts, :unique?, false)

    fn
      value, path when is_list(value) ->
        size =
          cond do
            length(value) < min -> [{pointer(path), "required"}]
            max && length(value) > max -> [{pointer(path), "too_many"}]
            true -> []
          end

        duplicate =
          if unique? and Enum.uniq(value) != value, do: [{pointer(path), "duplicate"}], else: []

        items =
          value |> Enum.with_index() |> Enum.map(fn {item, i} -> parser.(item, path ++ [i]) end)

        errors = size ++ duplicate ++ Enum.flat_map(items, &errors_of/1)

        if errors == [], do: {:ok, Enum.map(items, &elem(&1, 1))}, else: {:error, errors}

      nil, path ->
        required(path)

      _other, path ->
        invalid(path)
    end
  end

  @doc "`parser`, with `fun` applied to its value."
  @spec map(parser(), (term() -> term())) :: parser()
  def map(parser, fun) do
    fn value, path ->
      case parser.(value, path) do
        {:ok, parsed} -> {:ok, fun.(parsed)}
        error -> error
      end
    end
  end

  @doc "A JSON Pointer (RFC 6901) to `path`."
  @spec pointer(path()) :: String.t()
  def pointer(path) do
    Enum.map_join(path, fn
      index when is_integer(index) -> "/#{index}"
      key -> "/" <> (key |> String.replace("~", "~0") |> String.replace("/", "~1"))
    end)
  end

  defp errors_of({:ok, _value}), do: []
  defp errors_of({:error, errors}), do: errors

  defp required(path), do: {:error, [{pointer(path), "required"}]}
  defp invalid(path), do: {:error, [{pointer(path), "invalid"}]}
end
