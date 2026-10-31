// The goal rules (slice 4a, contracts/goal-model/v1): the web's TypeScript reading of the
// goal-model README, run against every goal-model fixture. Pure: no UI, no API, no clock. Every
// day is an effective practice day (`YYYY-MM-DD`, src/shared/practice).
export { attributeCounts, type AttributedGoal } from "./counts";
export { makeUpDays, type DayStatus, type MakeUpDay } from "./dayStatus";
export { goalIsDue } from "./due";
export { canExcuse, EXCUSED_PER_MONTH, type ExcuseAnswer, type ExcuseRefusal } from "./excused";
export { mergeGoalOrder } from "./order";
export { dailyPace, type DailyPace } from "./pace";
export {
  daysPerPeriod,
  requirementStanding,
  type DaysPerPeriod,
  type RequirementStanding,
  type SessionStanding,
} from "./periods";
export { placeGoals, type Finished, type GoalLists, type PlacedGoal } from "./placement";
export {
  consistency,
  goalStreak,
  streakUnit,
  type Consistency,
  type ConsistencyTag,
  type GoalStreak,
  type StreakUnit,
} from "./streak";
export { goalCompletion, todayRing, type TodayRing } from "./today";
export type * from "./types";
export { documentErrors, goalErrors, sessionId, type GoalError } from "./validity";
export { addVersion, isTimeline, MAX_VERSIONS, versionOnDay } from "./versions";
