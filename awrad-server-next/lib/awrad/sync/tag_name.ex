defmodule Awrad.Sync.TagName do
  @moduledoc """
  Tag names (`contracts/sync/v1/fixtures/tag_name_normalization.json`).

    * **Display name:** trim characters with the Unicode `White_Space` property,
      collapse each inner run of them to one U+0020, then NFC.
    * **Normalized name:** Unicode Default Case Folding (full, not lowercasing,
      not locale-specific) of the display name, then NFC. Two tags are the same
      when their normalized names are equal.
    * **Limits**, on the display name, in this order: `:empty`, more than 40
      extended grapheme clusters (`:too_many_graphemes`), more than 128 UTF-8
      bytes (`:too_many_bytes`).

  Diacritics, Arabic marks, tatweel and joiners are never stripped. Graphemes
  follow the Unicode version Elixir ships (UAX #29).
  """

  @max_graphemes 40
  @max_bytes 128

  # The Unicode White_Space property (PropList.txt).
  @white_space [
    0x09,
    0x0A,
    0x0B,
    0x0C,
    0x0D,
    0x20,
    0x85,
    0xA0,
    0x1680,
    0x2000,
    0x2001,
    0x2002,
    0x2003,
    0x2004,
    0x2005,
    0x2006,
    0x2007,
    0x2008,
    0x2009,
    0x200A,
    0x2028,
    0x2029,
    0x202F,
    0x205F,
    0x3000
  ]

  @type reason :: :empty | :too_many_graphemes | :too_many_bytes

  @doc """
  The display and normalized names of what the user typed, or why it can't be
  a tag name.

      iex> Awrad.Sync.TagName.normalize("  Before   Sleep  ")
      {:ok, "Before Sleep", "before sleep"}

      iex> Awrad.Sync.TagName.normalize("   ")
      {:error, :empty}
  """
  @spec normalize(String.t()) :: {:ok, String.t(), String.t()} | {:error, reason()}
  def normalize(input) when is_binary(input) do
    name = display(input)

    cond do
      name == "" -> {:error, :empty}
      String.length(name) > @max_graphemes -> {:error, :too_many_graphemes}
      byte_size(name) > @max_bytes -> {:error, :too_many_bytes}
      true -> {:ok, name, fold(name)}
    end
  end

  @doc "The display form: trimmed, inner `White_Space` runs collapsed to one space, NFC."
  @spec display(String.t()) :: String.t()
  def display(input) when is_binary(input) do
    input
    |> String.to_charlist()
    |> Enum.chunk_by(&(&1 in @white_space))
    |> Enum.reject(fn [first | _] -> first in @white_space end)
    |> Enum.map_join(" ", &List.to_string/1)
    |> String.normalize(:nfc)
  end

  @doc "The normalized form of a display name: full Unicode case folding, then NFC."
  @spec fold(String.t()) :: String.t()
  def fold(name) when is_binary(name) do
    name |> :string.casefold() |> IO.chardata_to_string() |> String.normalize(:nfc)
  end
end
