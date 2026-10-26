defmodule Awrad.Goals do
  @moduledoc """
  Goal rules (slice 1): where a goal stands on an effective practice day.

  Pure functions over plain structs. No database, no HTTP. The public entry
  point is `Awrad.Goals.Rules`; the structs are the goal model of
  `contracts/goal-model/v1/goal-model.schema.json` (language in `CONTEXT.md`).
  The shared fixtures in `contracts/goal-model/v1/fixtures/` are the spec.

  The rule implementations (`Awrad.Goals.Rules.*`) are internal to this
  boundary.
  """

  use Boundary,
    deps: [Awrad.Hijri],
    exports: [
      ActivePeriod,
      CountEntry,
      CountPolicy,
      DaysPerPeriodStanding,
      Goal,
      PausedRange,
      Rules,
      Session,
      SessionStanding,
      Standing
    ]
end
