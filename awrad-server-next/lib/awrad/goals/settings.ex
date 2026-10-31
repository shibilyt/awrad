defmodule Awrad.Goals.Settings do
  @moduledoc """
  What one dated version of a goal sets (`goal_settings` in the schema): its
  schedule, active period, count policy, sessions, requirement, completion
  policy and make-up. A goal's pauses and excused days aren't versioned.

  The field types are `Awrad.Goals.Goal`'s.
  """

  alias Awrad.Goals.ActivePeriod
  alias Awrad.Goals.CountPolicy
  alias Awrad.Goals.Goal
  alias Awrad.Goals.MakeUp
  alias Awrad.Goals.Session

  @enforce_keys [
    :schedule,
    :active_period,
    :count_policy,
    :sessions,
    :requirement,
    :completion,
    :make_up
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          schedule: Goal.schedule(),
          active_period: ActivePeriod.t(),
          count_policy: CountPolicy.t(),
          sessions: [Session.t()],
          requirement: Goal.requirement(),
          completion: Goal.completion(),
          make_up: MakeUp.t()
        }
end
