defmodule AwradServer.ProgressSync.CanonicalJSON do
  @moduledoc false

  @spec hash(term()) :: {:ok, binary()} | {:error, :non_canonical_json}
  def hash(value) do
    with {:ok, encoded} <- encode(value) do
      {:ok, :crypto.hash(:sha256, encoded)}
    end
  end

  defp encode(nil), do: {:ok, "null"}
  defp encode(true), do: {:ok, "true"}
  defp encode(false), do: {:ok, "false"}
  defp encode(value) when is_integer(value), do: {:ok, Integer.to_string(value)}
  defp encode(value) when is_binary(value), do: {:ok, Jason.encode!(value)}

  defp encode(values) when is_list(values) do
    with {:ok, encoded} <- encode_many(values) do
      {:ok, ["[", Enum.intersperse(encoded, ","), "]"]}
    end
  end

  defp encode(value) when is_map(value) do
    with {:ok, pairs} <- normalize_pairs(value),
         false <- duplicate_key?(pairs),
         {:ok, encoded} <- encode_pairs(pairs) do
      {:ok, ["{", Enum.intersperse(encoded, ","), "}"]}
    else
      _other -> {:error, :non_canonical_json}
    end
  end

  defp encode(_value), do: {:error, :non_canonical_json}

  defp encode_many(values) do
    values
    |> Enum.reduce_while({:ok, []}, fn value, {:ok, encoded} ->
      case encode(value) do
        {:ok, item} -> {:cont, {:ok, [item | encoded]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, encoded} -> {:ok, Enum.reverse(encoded)}
      error -> error
    end
  end

  defp normalize_pairs(value) do
    value
    |> Enum.reduce_while({:ok, []}, fn
      {key, item}, {:ok, pairs} when is_binary(key) ->
        {:cont, {:ok, [{key, item} | pairs]}}

      _pair, _acc ->
        {:halt, {:error, :non_canonical_json}}
    end)
    |> case do
      {:ok, pairs} -> {:ok, Enum.sort_by(pairs, &elem(&1, 0))}
      error -> error
    end
  end

  defp duplicate_key?(pairs) do
    keys = Enum.map(pairs, &elem(&1, 0))
    length(keys) != MapSet.size(MapSet.new(keys))
  end

  defp encode_pairs(pairs) do
    pairs
    |> Enum.reduce_while({:ok, []}, fn {key, value}, {:ok, encoded} ->
      case encode(value) do
        {:ok, item} -> {:cont, {:ok, [[Jason.encode!(key), ":", item] | encoded]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, encoded} -> {:ok, Enum.reverse(encoded)}
      error -> error
    end
  end
end
