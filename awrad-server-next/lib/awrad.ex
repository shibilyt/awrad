defmodule Awrad do
  @moduledoc """
  The domain: contexts, schemas and rules. No HTTP, no Phoenix.

  Boundary enforces that this boundary never depends on `AwradWeb`. Each
  context added later (`Awrad.Accounts`, `Awrad.Progress`, …) becomes its own
  sub-boundary that exports only its public module, so contexts can't reach
  into each other's internals either.
  """

  # Each context sub-boundary is exported with its own exports ({Context, []}).
  use Boundary, deps: [], exports: [Mailer, Repo, {Goals, []}]
end
