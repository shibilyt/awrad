defmodule Awrad.Dhikrs.Catalog.Entry do
  @moduledoc """
  A built-in dhikr's identity (ADR-2026-07-13): its immutable UUIDv4 `id` and
  catalog `key`, its `kind`, and the keys of the collections that list it, in
  catalog order. The content (text, translations, audio) stays in the apps.
  """

  @enforce_keys [:id, :key, :kind, :collections]
  defstruct @enforce_keys

  @type kind :: :quran | :dhikr | :dua | :salawat | :name_of_allah

  @type t :: %__MODULE__{
          id: String.t(),
          key: String.t(),
          kind: kind(),
          collections: [String.t()]
        }
end
