defmodule Awrad.Dhikrs do
  @moduledoc """
  Dhikrs (slice 3a, `CONTEXT.md`). So far only the identity of the built-in
  catalog, `Awrad.Dhikrs.Catalog`, so that progress writes can check that a
  referenced built-in dhikr exists and know its kind. Custom dhikrs come in
  slice 3b.
  """

  use Boundary, deps: [], exports: [Catalog, Catalog.Entry]
end
