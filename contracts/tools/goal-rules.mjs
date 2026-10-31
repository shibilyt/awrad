// Reference implementation of the goal-model v1 rules (contracts/goal-model/v1/README.md), used only by
// tools/check-goal-model.mjs to check that every fixture case agrees with one implementation of the README.
// Platforms implement the rules themselves and run the fixtures; this file is not shared code.
//
// Days are integers (days since 1970-01-01, UTC); inputs and outputs use YYYY-MM-DD strings.
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("..", import.meta.url));
const table = JSON.parse(readFileSync(join(root, "hijri-calendar/v1/umm-al-qura.json"), "utf8"));

// ---------------------------------------------------------------- days

const MS = 86_400_000;
export const day = (s) => Date.UTC(+s.slice(0, 4), +s.slice(5, 7) - 1, +s.slice(8, 10)) / MS;
export const iso = (n) => new Date(n * MS).toISOString().slice(0, 10);
const WEEKDAYS = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"];
const weekdayOf = (n) => WEEKDAYS[new Date(n * MS).getUTCDay()];
const ymd = (n) => {
  const d = new Date(n * MS);
  return { year: d.getUTCFullYear(), month: d.getUTCMonth() + 1, day: d.getUTCDate() };
};
const daysInMonth = (year, month) => new Date(Date.UTC(year, month, 0)).getUTCDate();
const min = (a, b) => (a === null ? b : b === null ? a : Math.min(a, b));
const sameJson = (a, b) => canonical(a) === canonical(b);
function canonical(value) {
  if (Array.isArray(value)) return `[${value.map(canonical).join(",")}]`;
  if (value && typeof value === "object") {
    return `{${Object.keys(value).sort().map((k) => `${JSON.stringify(k)}:${canonical(value[k])}`).join(",")}}`;
  }
  return JSON.stringify(value);
}

// ---------------------------------------------------------------- Hijri (hijri-calendar/v1)

const monthCache = new Map();
function hijriMonths(corrections = []) {
  const key = canonical(corrections);
  if (monthCache.has(key)) return monthCache.get(key);
  const sorted = [...corrections].sort((a, b) => a.year - b.year || a.month - b.month);
  const months = [];
  let offset = 0;
  for (let year = table.first_year; year <= table.last_year; year += 1) {
    table.month_starts[String(year)].forEach((start, i) => {
      const c = sorted.find((x) => x.year === year && x.month === i + 1);
      if (c) offset = c.offset_days;
      months.push({ year, month: i + 1, start: day(start) + offset });
    });
  }
  const result = { months, end: day(table.end_exclusive) + offset };
  monthCache.set(key, result);
  return result;
}

function hijriMonthAt(n, corrections) {
  const { months, end } = hijriMonths(corrections);
  if (n < months[0].start || n >= end) return null;
  let lo = 0;
  let hi = months.length - 1;
  while (lo < hi) {
    const mid = (lo + hi + 1) >> 1;
    if (months[mid].start <= n) lo = mid;
    else hi = mid - 1;
  }
  const next = lo + 1 < months.length ? months[lo + 1].start : end;
  return { ...months[lo], last: next - 1, length: next - months[lo].start };
}

export function hijriDate(n, corrections) {
  const m = hijriMonthAt(n, corrections);
  return m && { year: m.year, month: m.month, day: n - m.start + 1, length: m.length };
}

const hijriLastDay = (corrections) => hijriMonths(corrections).end - 1;

// ---------------------------------------------------------------- schedules and due days

export function lastDay(ap) {
  const end = ap.end_date === null ? null : day(ap.end_date);
  const duration = ap.duration_days === null ? null : day(ap.start_date) + ap.duration_days - 1;
  return min(end, duration);
}
const inActive = (ap, n) => n >= day(ap.start_date) && (lastDay(ap) === null || n <= lastDay(ap));
const isPaused = (goal, n) => goal.paused.some((p) => n >= day(p.from) && (p.to === null || n <= day(p.to)));
const isExcused = (goal, n) => goal.excused.includes(iso(n));

const monthDay = (days, d, length) => days.includes(d) || (d === length && days.some((x) => x > d));
const tuple = (md) => md.month * 100 + md.day;
function clamp(boundary, md, length) {
  return boundary.month === md.month ? boundary.month * 100 + Math.min(boundary.day, length) : tuple(boundary);
}
function inRange(range, md, length) {
  const from = clamp(range.start, md, length) <= tuple(md);
  const to = tuple(md) <= clamp(range.end, md, length);
  return tuple(range.end) < tuple(range.start) ? from || to : from && to;
}
function yearlyMatch(schedule, n, corrections) {
  if (schedule.calendar === "gregorian") {
    const d = ymd(n);
    const md = { month: d.month, day: d.day };
    const range = schedule.ranges.find((r) => inRange(r, md, daysInMonth(d.year, d.month)));
    return range && { range, md, year: d.year, length: daysInMonth(d.year, d.month) };
  }
  const h = hijriDate(n, corrections);
  if (!h) return undefined;
  const md = { month: h.month, day: h.day };
  const range = schedule.ranges.find((r) => inRange(r, md, h.length));
  return range && { range, md, year: h.year, length: h.length };
}

function scheduled(schedule, start, n, corrections) {
  switch (schedule.kind) {
    case "every_day":
    case "one_time":
      return true;
    case "weekdays":
      return schedule.weekdays.includes(weekdayOf(n));
    case "every_n_days": {
      const diff = n - day(schedule.anchor_date ?? start);
      return diff >= 0 && diff % schedule.every === 0;
    }
    case "month_days": {
      const d = ymd(n);
      return monthDay(schedule.days, d.day, daysInMonth(d.year, d.month));
    }
    case "specific_dates":
      return schedule.dates.includes(iso(n));
    case "hijri_month_days": {
      const h = hijriDate(n, corrections);
      return Boolean(h) && monthDay(schedule.days, h.day, h.length);
    }
    case "yearly":
      return Boolean(yearlyMatch(schedule, n, corrections));
    default:
      throw new Error(`unknown schedule ${schedule.kind}`);
  }
}

const inSchedule = (goal, n, c) => inActive(goal.active_period, n) && scheduled(goal.schedule, goal.active_period.start_date, n, c);
export const isDue = (goal, n, c) => inSchedule(goal, n, c) && !isPaused(goal, n) && !isExcused(goal, n);

// ---------------------------------------------------------------- dated versions

const isTimeline = (input) => Array.isArray(input.versions);
const SETTINGS = ["schedule", "active_period", "count_policy", "sessions", "requirement", "completion", "make_up"];
const settingsOf = (version) => Object.fromEntries(SETTINGS.map((k) => [k, version[k]]));

/** The version index in force on day n: the last one starting on or before n, or the first. */
export function versionIndex(timeline, n) {
  let found = 0;
  timeline.versions.forEach((v, i) => {
    if (day(v.from) <= n) found = i;
  });
  return found;
}

/** The goal a rule evaluates on day n (README.md, Dated versions). capEnded: false keeps the version's own end. */
export function resolve(input, n, { capEnded = true } = {}) {
  if (!isTimeline(input)) return input;
  const v = input.versions[versionIndex(input, n)];
  const goal = { ...settingsOf(v), paused: input.paused, excused: input.excused };
  if (capEnded && input.ended) {
    const on = day(input.ended.on);
    const last = lastDay(v.active_period);
    if (last === null || last > on) goal.active_period = { ...v.active_period, end_date: input.ended.on, duration_days: null };
  }
  return orderGoal(goal);
}
const GOAL_KEYS = ["schedule", "active_period", "paused", "excused", "count_policy", "sessions", "requirement", "completion", "make_up"];
const orderGoal = (g) => Object.fromEntries(GOAL_KEYS.map((k) => [k, g[k]]));
const endedOf = (input) => (isTimeline(input) ? input.ended : null);
const createdOn = (input) => (isTimeline(input) ? input.created_on : input.active_period.start_date);

// ---------------------------------------------------------------- counts

export function index(counts) {
  const idx = new Map();
  for (const c of counts) {
    const n = day(c.date);
    if (!idx.has(n)) idx.set(n, new Map());
    const m = idx.get(n);
    m.set(c.session, (m.get(c.session) ?? 0) + c.count);
  }
  return idx;
}
const dayMap = (idx, n) => idx.get(n) ?? new Map();
function goalTotal(goal, dm) {
  if (goal.sessions.length === 0) return [...dm.values()].reduce((a, b) => a + b, 0);
  return goal.sessions.reduce((a, s) => a + (dm.get(s.id) ?? 0), 0);
}
const units = (goal) =>
  goal.sessions.length === 0 ? [{ id: null, policy: goal.count_policy }] : goal.sessions.map((s) => ({ id: s.id, policy: s.count_policy }));
const unitCount = (goal, dm, id) => (id === null ? goalTotal(goal, dm) : dm.get(id) ?? 0);
const dailyTarget = (goal, policy) => (["per_due_date", "days_per_period"].includes(goal.requirement.type) ? policy.target : null);

/** The number a day needs for the streak (README.md, Streak amount). */
function streakAmount(input, idx, policy, n, c) {
  const t = policy.streak_threshold;
  if (typeof t === "object") return t.amount;
  if (t === "any_count") return 1;
  if (t === "daily_pace") return Math.max(1, dailyPace(input, idx, n, c).pace ?? 1);
  return policy[t];
}

// ---------------------------------------------------------------- day status and make-up (make_up.json)

const KEPT = new Set(["met", "minimum_only", "made_up"]);
const WINDOW_DAYS = { off: 0, next_day: 1, within_3_days: 3 };

/** Status of every due day from the start date up to D (or the goal's last day). */
export function dayStatuses(input, idx, D, c) {
  const g0 = resolve(input, D);
  const start = day(g0.active_period.start_date);
  const last = min(D, lastDay(g0.active_period));
  const days = [];
  for (let n = start; n <= last; n += 1) {
    const g = resolve(input, n);
    if (!isDue(g, n, c)) continue;
    const dm = dayMap(idx, n);
    const fill = g.make_up.fill;
    days.push({
      n,
      window: WINDOW_DAYS[g.make_up.window],
      units: units(g).map(({ id, policy }) => {
        const T = dailyTarget(g, policy);
        const S = streakAmount(input, idx, policy, n, c);
        const count = unitCount(g, dm, id);
        const fillAmount = fill === "streak" ? S : Math.max(T ?? 0, S);
        return { id, T, S, count, fillAmount, filled: 0 };
      }),
    });
  }
  // Surplus: counts past what a later day needs for itself fill missed days in their window, oldest first.
  for (let e = start; e <= last; e += 1) {
    const g = resolve(input, e);
    if (!inActive(g.active_period, e) || isPaused(g, e) || isExcused(g, e)) continue;
    const dm = dayMap(idx, e);
    const due = days.find((x) => x.n === e);
    const surplus = new Map();
    const surplusOf = (id) => {
      if (!surplus.has(id)) {
        if (due) {
          const u = due.units.find((x) => x.id === id);
          surplus.set(id, u ? Math.max(0, u.count - Math.max(u.T ?? 0, u.S)) : 0);
        } else {
          surplus.set(id, id === null ? [...dm.values()].reduce((a, b) => a + b, 0) : dm.get(id) ?? 0);
        }
      }
      return surplus.get(id);
    };
    for (const missed of days) {
      if (missed.n >= e || e - missed.n > missed.window) continue;
      for (const u of missed.units) {
        const deficit = u.fillAmount - u.count - u.filled;
        if (deficit <= 0) continue;
        const give = Math.min(deficit, surplusOf(u.id));
        u.filled += give;
        surplus.set(u.id, surplusOf(u.id) - give);
      }
    }
  }
  const result = new Map();
  for (const x of days) {
    const statuses = x.units.map((u) => {
      if (u.count >= u.S && (u.T === null || u.count >= u.T)) return "met";
      if (u.filled > 0 && u.count + u.filled >= u.fillAmount) return "made_up";
      if (u.count >= u.S) return "minimum_only";
      return x.n === D ? "in_progress" : "missed";
    });
    const worst = ["in_progress", "missed", "made_up", "minimum_only", "met"].find((s) => statuses.includes(s));
    result.set(x.n, {
      status: worst,
      count: x.units.reduce((a, u) => a + u.count, 0),
      filled: x.units.reduce((a, u) => a + u.filled, 0),
    });
  }
  return result;
}

export function makeUp(given) {
  const c = given.hijri_corrections ?? [];
  const idx = index(given.counts);
  const D = day(given.date);
  const statuses = dayStatuses(given.goal, idx, D, c);
  return {
    days: [...statuses.entries()]
      .filter(([n]) => n >= day(given.from))
      .map(([n, s]) => ({ date: iso(n), count: s.count, filled: s.filled, status: s.status })),
  };
}

// ---------------------------------------------------------------- periods

const WEEK_INDEX = { sunday: 0, monday: 1, tuesday: 2, wednesday: 3, thursday: 4, friday: 5, saturday: 6 };
function periodOf(n, unit, weekStart, c) {
  if (unit === "week") {
    const first = n - ((new Date(n * MS).getUTCDay() - WEEK_INDEX[weekStart] + 7) % 7);
    return { first, last: first + 6 };
  }
  if (unit === "month") {
    const d = ymd(n);
    const first = day(`${String(d.year).padStart(4, "0")}-${String(d.month).padStart(2, "0")}-01`);
    return { first, last: first + daysInMonth(d.year, d.month) - 1 };
  }
  const m = hijriMonthAt(n, c);
  return m && { first: m.start, last: m.last };
}
function clip(period, ap) {
  const first = Math.max(period.first, day(ap.start_date));
  const last = min(period.last, lastDay(ap));
  return first > last ? null : { first, last };
}
const range = (w) => Array.from({ length: w.last - w.first + 1 }, (_, i) => w.first + i);

function periodProgress(goal, idx, days) {
  if (goal.sessions.length === 0) {
    const progress = days.reduce((a, n) => a + goalTotal(goal, dayMap(idx, n)), 0);
    return { progress, sessions: [] };
  }
  const sessions = goal.sessions.map((s) => {
    const p = days.reduce((a, n) => a + (dayMap(idx, n).get(s.id) ?? 0), 0);
    return { id: s.id, progress: p, target: s.count_policy.target, status: meetsTarget(p, s.count_policy) ? "met" : "not_met" };
  });
  return { progress: days.reduce((a, n) => a + goalTotal(goal, dayMap(idx, n)), 0), sessions };
}
const meetsTarget = (count, policy) => (policy.target === null ? count > 0 : count >= policy.target);
function progressMet(goal, p) {
  return goal.sessions.length === 0 ? meetsTarget(p.progress, trackerless(goal).count_policy) : p.sessions.every((s) => s.status === "met");
}
const trackerless = (goal) =>
  goal.requirement.type === "tracker" ? { ...goal, count_policy: { ...goal.count_policy, target: null } } : goal;
function dayMetTarget(goal, dm) {
  return units(goal).every(({ id, policy }) => meetsTarget(unitCount(goal, dm, id), goal.requirement.type === "tracker" ? { ...policy, target: null } : policy));
}

/** Days per period over a window: qualifying due days up to D against the required days. */
function tally(input, idx, window, D, c) {
  const gw = resolve(input, Math.min(window.last, D));
  const due = range(window).filter((n) => isDue(resolve(input, n), n, c));
  const qualifying = due.filter((n) => n <= D && dayMetTarget(resolve(input, n), dayMap(idx, n))).length;
  const excused = range(window).filter((n) => resolve(input, n).excused.includes(iso(n))).length;
  const required = Math.max(0, Math.min(gw.requirement.days - excused, due.length));
  return { qualifying, required, dueDays: due.length };
}

function windowMet(input, idx, window, D, c) {
  const gw = resolve(input, Math.min(window.last, D));
  if (gw.requirement.type === "days_per_period") {
    const t = tally(input, idx, window, D, c);
    return t.qualifying >= t.required;
  }
  const days = range(window).filter((n) => n <= D && inActive(gw.active_period, n));
  return progressMet(gw, periodProgress(trackerless(gw), idx, days));
}

/** Walks back over the goal's periods, newest first: [{window, inProgress, met, skip}]. */
function* periodsBack(input, idx, D, c, weekStart) {
  const g0 = resolve(input, D);
  const unit = g0.requirement.period;
  let last = min(D, lastDay(g0.active_period));
  if (last < day(g0.active_period.start_date)) return;
  if (unit === "hijri_month") last = Math.min(last, hijriLastDay(c));
  let period = periodOf(last, unit, weekStart, c);
  while (period) {
    const window = clip(period, g0.active_period);
    if (!window) return;
    const hasDue = range(window).some((n) => isDue(resolve(input, n), n, c));
    const required = g0.requirement.type === "days_per_period" && hasDue ? tally(input, idx, window, D, c).required : 1;
    if (hasDue && required > 0) {
      yield { window, inProgress: window.last >= D, met: windowMet(input, idx, window, D, c) };
    }
    period = periodOf(period.first - 1, unit, weekStart, c);
  }
}

// ---------------------------------------------------------------- streaks (goal_streak.json)

/** The streak unit (README.md, Streak units). */
export function streakUnit(goal) {
  if (["period_total", "days_per_period"].includes(goal.requirement.type)) {
    return { unit: goal.requirement.period === "week" ? "week" : "month", weekday: null };
  }
  if (goal.schedule.kind === "yearly") return { unit: "occasion", weekday: null };
  if (goal.schedule.kind === "weekdays" && goal.schedule.weekdays.length === 1) return { unit: "weekday", weekday: goal.schedule.weekdays[0] };
  return { unit: "day", weekday: null };
}

function occasionKey(goal, n, c) {
  const m = yearlyMatch(goal.schedule, n, c);
  const wraps = tuple(m.range.end) < tuple(m.range.start);
  return wraps && tuple(m.md) <= clamp(m.range.end, m.md, m.length) ? m.year - 1 : m.year;
}

/** Occurrences of an occasion goal, newest first: [{days: [n], inProgress}]. */
function occurrencesBack(input, idx, D, c) {
  const g0 = resolve(input, D);
  const statuses = dayStatuses(input, idx, D, c);
  const groups = [];
  for (const n of [...statuses.keys()].sort((a, b) => b - a)) {
    const key = occasionKey(resolve(input, n), n, c);
    if (groups.length === 0 || groups.at(-1).key !== key) groups.push({ key, days: [] });
    groups.at(-1).days.push(n);
  }
  const running = lastDay(g0.active_period) === null || D <= lastDay(g0.active_period);
  return groups.map((group, i) => {
    let inProgress = false;
    if (i === 0 && running) {
      inProgress = group.days.some((n) => statuses.get(n).status === "in_progress");
      for (let n = D + 1; !inProgress && n <= D + 400; n += 1) {
        const g = resolve(input, n);
        if (lastDay(g.active_period) !== null && n > lastDay(g.active_period)) break;
        if (inSchedule(g, n, c) && !isPaused(g, n)) {
          if (occasionKey(g, n, c) === group.key) inProgress = true;
          break;
        }
      }
    }
    return { days: group.days, inProgress, kept: group.days.every((n) => KEPT.has(statuses.get(n).status)) };
  });
}

export function streakCurrent(input, idx, D, c, weekStart) {
  const g0 = resolve(input, D);
  const { unit } = streakUnit(g0);
  let current = 0;
  if (unit === "week" || unit === "month") {
    for (const p of periodsBack(input, idx, D, c, weekStart)) {
      if (p.met) current += 1;
      else if (!p.inProgress) break;
    }
  } else if (unit === "occasion") {
    for (const o of occurrencesBack(input, idx, D, c)) {
      if (o.kept && !o.inProgress) current += 1;
      else if (!o.inProgress) break;
    }
  } else {
    const statuses = dayStatuses(input, idx, D, c);
    for (const n of [...statuses.keys()].sort((a, b) => b - a)) {
      const s = statuses.get(n).status;
      if (KEPT.has(s)) current += 1;
      else if (s !== "in_progress") break;
    }
  }
  return current;
}

export function goalStreak(given) {
  const c = given.hijri_corrections ?? [];
  const D = day(given.date);
  const idx = index(given.counts);
  return { current: streakCurrent(given.goal, idx, D, c, given.week_start), ...streakUnit(resolve(given.goal, D)) };
}

// ---------------------------------------------------------------- consistency (consistency.json)

export function consistency(given) {
  const c = given.hijri_corrections ?? [];
  const D = day(given.date);
  const idx = index(given.counts);
  const g0 = resolve(given.goal, D);
  const { unit } = streakUnit(g0);
  let met = 0;
  let outOf = 0;
  let basis;
  if (unit === "week" || unit === "month") {
    basis = "periods";
    for (const p of periodsBack(given.goal, idx, D, c, given.week_start)) {
      if (outOf === 12) break;
      if (p.inProgress && !p.met) continue;
      outOf += 1;
      if (p.met) met += 1;
    }
  } else {
    basis = "due_days";
    const statuses = dayStatuses(given.goal, idx, D, c);
    for (const n of [...statuses.keys()].sort((a, b) => b - a)) {
      if (outOf === 30) break;
      const s = statuses.get(n).status;
      if (s === "in_progress") continue;
      outOf += 1;
      if (KEPT.has(s)) met += 1;
    }
  }
  const enough = outOf >= (basis === "periods" ? 4 : 7);
  const tag = !enough ? null : met * 10 >= outOf * 9 ? "devoted" : met * 10 >= outOf * 8 ? "steady" : null;
  const streak = streakCurrent(given.goal, idx, D, c, given.week_start);
  const show = streak >= 3 ? "streak" : tag ? "consistency" : streak >= 1 ? "streak" : "none";
  return { basis, met, out_of: outOf, tag, show };
}

// ---------------------------------------------------------------- daily pace (daily_pace.json)

export function dailyPace(input, idx, n, c) {
  const g = resolve(input, n, { capEnded: false });
  if (g.requirement.type !== "cumulative_total" || g.sessions.length > 0) return { pace: null, remaining: null, due_days_left: null };
  const start = day(g.active_period.start_date);
  let before = 0;
  for (let m = start; m < n; m += 1) if (inActive(g.active_period, m)) before += goalTotal(g, dayMap(idx, m));
  const remaining = Math.max(0, g.count_policy.target - before);
  const last = lastDay(g.active_period);
  if (last === null) return { pace: null, remaining, due_days_left: null };
  let left = 0;
  for (let m = Math.max(n, start); m <= last; m += 1) if (isDue(resolve(input, m, { capEnded: false }), m, c)) left += 1;
  const pace = isDue(g, n, c) && left > 0 ? Math.ceil(remaining / left) : null;
  return { pace, remaining, due_days_left: left };
}

// ---------------------------------------------------------------- today's ring (today_ring.json)

export function todayRing(given) {
  const c = given.hijri_corrections ?? [];
  const D = day(given.date);
  const idx = index(given.counts);
  const g = resolve(given.goal, D);
  const dm = dayMap(idx, D);
  const total = goalTotal(g, dm);
  const none = { ring: "none", progress: total, goal: null };
  const type = g.requirement.type;
  if (type === "period_total") {
    const period = periodOf(D, g.requirement.period, given.week_start, c);
    const window = period && inActive(g.active_period, D) ? clip(period, g.active_period) : null;
    if (!window || !range(window).some((n) => isDue(resolve(given.goal, n), n, c))) return none;
    const days = range(window).filter((n) => n <= D);
    const p = periodProgress(g, idx, days);
    if (g.sessions.length === 0) return { ring: "period_target", progress: p.progress, goal: g.count_policy.target };
    return {
      ring: "period_target",
      progress: p.sessions.reduce((a, s) => a + Math.min(s.progress, s.target), 0),
      goal: p.sessions.reduce((a, s) => a + s.target, 0),
    };
  }
  if (!isDue(g, D, c)) return none;
  if (type === "per_due_date" || type === "days_per_period") {
    if (g.sessions.length === 0) return { ring: "target", progress: total, goal: g.count_policy.target };
    return {
      ring: "target",
      progress: g.sessions.reduce((a, s) => a + Math.min(dm.get(s.id) ?? 0, s.count_policy.target), 0),
      goal: g.sessions.reduce((a, s) => a + s.count_policy.target, 0),
    };
  }
  const threshold = g.count_policy.streak_threshold;
  if (type === "cumulative_total") {
    if (threshold === "daily_pace") return { ring: "pace", progress: total, goal: Math.max(1, dailyPace(given.goal, idx, D, c).pace ?? 1) };
    return { ring: "streak_amount", progress: total, goal: streakAmount(given.goal, idx, g.count_policy, D, c) };
  }
  if (threshold === "any_count") return none;
  const S = streakAmount(given.goal, idx, g.count_policy, D, c);
  return total < S ? { ring: "streak_amount", progress: total, goal: S } : none;
}

// ---------------------------------------------------------------- completion (goal_completion.json)

export function completed(goal, idx, D) {
  if (goal.completion === "never") return false;
  if (goal.completion === "when_duration_ended") return lastDay(goal.active_period) !== null && D > lastDay(goal.active_period);
  if (goal.requirement.type !== "cumulative_total") return false;
  const start = day(goal.active_period.start_date);
  if (D < start) return false;
  const days = [];
  for (let n = start; n <= D; n += 1) if (inActive(goal.active_period, n)) days.push(n);
  return progressMet(goal, periodProgress(goal, idx, days));
}

// ---------------------------------------------------------------- list placement (goal_list_placement.json)

const HORIZON = 400;
function finishedState(input, idx, D, c) {
  const ended = endedOf(input);
  if (ended) return { finished: ended.reason === "completed" ? "completed" : "ended", on: ended.on };
  const g = resolve(input, D);
  const last = lastDay(g.active_period);
  if (completed(g, idx, D)) {
    if (g.completion === "when_duration_ended") return { finished: "completed", on: iso(last) };
    for (let n = day(g.active_period.start_date); n <= D; n += 1) if (completed(g, idx, n)) return { finished: "completed", on: iso(n) };
  }
  if (last !== null && D > last) return { finished: "ended", on: iso(last) };
  const horizon = last === null ? D + HORIZON : Math.min(last, D + HORIZON);
  for (let n = D; n <= horizon; n += 1) if (inSchedule(resolve(input, n), n, c)) return null;
  const start = day(g.active_period.start_date);
  for (let n = D - 1; n >= start; n -= 1) if (inSchedule(resolve(input, n), n, c)) return { finished: "ended", on: iso(n) };
  return { finished: "ended", on: g.active_period.start_date };
}

export function listPlacement(given) {
  const c = given.hijri_corrections ?? [];
  const D = day(given.date);
  const position = (id) => (given.order.includes(id) ? given.order.indexOf(id) : Infinity);
  const byOrder = (a, b) =>
    position(a.id) - position(b.id) || (a.created < b.created ? -1 : a.created > b.created ? 1 : 0) || (a.id < b.id ? -1 : a.id > b.id ? 1 : 0);
  const out = { today: [], upcoming: [], tracking: [], paused: [], history: [] };
  for (const item of given.goals) {
    const idx = index(item.counts);
    const g = resolve(item.goal, D);
    const entry = { id: item.id, created: createdOn(item.goal) };
    const finished = finishedState(item.goal, idx, D, c);
    if (finished) out.history.push({ ...entry, ...finished });
    else if (isPaused(g, D)) out.paused.push(entry);
    else if (g.requirement.type === "tracker") out.tracking.push(entry);
    else if (isDue(g, D, c)) out.today.push(entry);
    else {
      let next = null;
      const last = lastDay(g.active_period);
      for (let n = D + 1; n <= (last === null ? D + HORIZON : Math.min(last, D + HORIZON)); n += 1) {
        if (isDue(resolve(item.goal, n), n, c)) {
          next = iso(n);
          break;
        }
      }
      out.upcoming.push({ ...entry, next_due: next });
    }
  }
  out.today.sort(byOrder);
  out.tracking.sort(byOrder);
  out.paused.sort(byOrder);
  out.upcoming.sort((a, b) => (a.next_due === b.next_due ? 0 : a.next_due === null ? 1 : b.next_due === null ? -1 : a.next_due < b.next_due ? -1 : 1) || byOrder(a, b));
  out.history.sort((a, b) => (a.on > b.on ? -1 : a.on < b.on ? 1 : 0) || byOrder(a, b));
  return {
    today: out.today.map((x) => x.id),
    upcoming: out.upcoming.map((x) => ({ id: x.id, next_due: x.next_due })),
    tracking: out.tracking.map((x) => x.id),
    paused: out.paused.map((x) => x.id),
    history: out.history.map((x) => ({ id: x.id, finished: x.finished, on: x.on })),
  };
}

// ---------------------------------------------------------------- excused days (excused_days.json)

export function excuse(given) {
  const c = given.hijri_corrections ?? [];
  const D = day(given.date);
  const X = day(given.day);
  const input = given.goal;
  const idx = index(given.counts);
  const g0 = resolve(input, D);
  const no = (reason) => ({ allowed: false, reason });
  if (endedOf(input) || (lastDay(g0.active_period) !== null && D > lastDay(g0.active_period))) return no("goal_finished");
  const excused = g0.excused;
  if (given.action === "unexcuse") return excused.includes(given.day) ? { allowed: true, reason: null } : no("not_excused");
  if (X >= D) return no("not_past");
  if (excused.includes(given.day)) return no("already_excused");
  if (g0.requirement.type === "period_total") return no("not_available");
  const gx = resolve(input, X);
  if (!isDue(gx, X, c)) return no("not_due");
  const kept =
    gx.requirement.type === "days_per_period" ? dayMetTarget(gx, dayMap(idx, X)) : KEPT.has(dayStatuses(input, idx, D, c).get(X).status);
  if (kept) return no("not_missed");
  if (excused.filter((x) => x.slice(0, 7) === given.day.slice(0, 7)).length >= 2) return no("limit_reached");
  return { allowed: true, reason: null };
}

// ---------------------------------------------------------------- count attribution (count_attribution.json)

export function countAttribution(given) {
  return {
    goals: given.goals.map((goal) => {
      const buckets = new Map();
      for (const e of given.log) {
        if (e.dhikr_id !== goal.dhikr_id) continue;
        const mine = goal.counts === "dedicated" ? e.goal_id === goal.id : e.goal_id === null;
        if (!mine) continue;
        const g = resolve(goal.goal, day(e.practice_day), { capEnded: false });
        let session = null;
        if (g.sessions.length > 0) {
          if (!g.sessions.some((s) => s.id === e.session_id)) continue;
          session = e.session_id;
        }
        const key = `${e.practice_day}|${session ?? ""}`;
        buckets.set(key, { date: e.practice_day, session, count: (buckets.get(key)?.count ?? 0) + e.amount });
      }
      const counts = [...buckets.values()]
        .filter((b) => b.count > 0)
        .sort((a, b) => (a.date < b.date ? -1 : a.date > b.date ? 1 : (a.session ?? "") < (b.session ?? "") ? -1 : 1));
      return { id: goal.id, counts };
    }),
  };
}

// ---------------------------------------------------------------- versions (goal_version_on_day.json, goal_version_add.json)

export function versionOnDay(given) {
  const n = day(given.date);
  return { version: versionIndex(given.document, n), goal: resolve(given.document, n) };
}

export function versionAdd(given) {
  const versions = given.versions.map((v) => ({ ...v }));
  const last = versions.at(-1);
  if (sameJson(settingsOf(last), given.settings)) return { versions };
  if (day(last.from) >= day(given.today)) {
    versions[versions.length - 1] = { from: last.from, ...given.settings };
    if (versions.length >= 2 && sameJson(settingsOf(versions.at(-2)), given.settings)) versions.pop();
  } else {
    versions.push({ from: given.today, ...given.settings });
  }
  if (versions.length > 100) {
    const first = versions.shift();
    versions[0] = { ...versions[0], from: first.from };
  }
  return { versions };
}

// ---------------------------------------------------------------- goal order merge (goal_order_merge.json)

export function goalOrderMerge({ base, mine, theirs }) {
  if (sameJson(mine, base)) return { document: theirs, requeue: false };
  const removedThere = new Set(base.goal_ids.filter((id) => !theirs.goal_ids.includes(id)));
  const ids = mine.goal_ids.filter((id) => !removedThere.has(id));
  for (const id of theirs.goal_ids) if (!ids.includes(id) && !base.goal_ids.includes(id)) ids.push(id);
  const document = { goal_ids: ids };
  return { document, requeue: !sameJson(document, theirs) };
}

// ---------------------------------------------------------------- validity (goal_validity.json)

export function sessionId(s) {
  switch (s.kind) {
    case "anytime":
      return "anytime";
    case "before_prayer":
      return `before_${s.prayer}`;
    case "after_prayer":
      return `after_${s.prayer}`;
    case "at_time":
      return `at_${s.time.replace(":", "")}`;
    case "between":
      return `between_${s.from.replace(":", "")}_${s.to.replace(":", "")}`;
    default:
      throw new Error(`unknown session kind ${s.kind}`);
  }
}

const thresholdUnset = (p) => ["minimum", "target", "maximum"].includes(p.streak_threshold) && p[p.streak_threshold] === null;

export function goalErrors(goal) {
  const errors = new Set();
  const tracker = goal.requirement.type === "tracker";
  const p = goal.count_policy;
  if (goal.sessions.length === 0) {
    if (thresholdUnset(p)) errors.add("streak_threshold_value_required");
    if (!tracker && p.target === null) errors.add("target_required");
  } else {
    for (const s of goal.sessions) {
      if (thresholdUnset(s.count_policy)) errors.add("streak_threshold_value_required");
      if (!tracker && s.count_policy.target === null) errors.add("session_target_required");
      if (s.count_policy.minimum !== null || s.count_policy.maximum !== null) errors.add("sessions_with_minimum_or_cap");
      if (s.count_policy.streak_threshold === "daily_pace") errors.add("streak_pace_not_allowed");
      if (s.id !== sessionId(s)) errors.add("session_id_mismatch");
      if (s.kind === "between" && s.from === s.to) errors.add("session_window_empty");
    }
    if (p.minimum !== null || p.maximum !== null) errors.add("sessions_with_minimum_or_cap");
    const ids = goal.sessions.map((s) => s.id);
    if (new Set(ids).size !== ids.length) errors.add("session_duplicate");
  }
  const ap = goal.active_period;
  if (ap.end_date !== null && ap.duration_days !== null) errors.add("end_date_and_duration");
  if (goal.make_up.window !== "off" && goal.requirement.type !== "per_due_date") errors.add("make_up_not_daily");
  if (p.streak_threshold === "daily_pace" && !(goal.requirement.type === "cumulative_total" && (ap.end_date !== null || ap.duration_days !== null))) {
    errors.add("streak_pace_not_allowed");
  }
  return errors;
}

const structure = (v) => ({
  schedule: v.schedule.kind,
  calendar: v.schedule.calendar ?? null,
  requirement: v.requirement.type,
  period: v.requirement.period ?? null,
  start: v.active_period.start_date,
});

export function documentErrors(document) {
  const errors = new Set();
  for (const v of document.versions) {
    for (const e of goalErrors({ ...settingsOf(v), paused: document.paused, excused: document.excused })) errors.add(e);
  }
  const froms = document.versions.map((v) => day(v.from));
  if (froms.some((f, i) => i > 0 && f <= froms[i - 1])) errors.add("versions_out_of_order");
  if (document.versions[0].from !== document.created_on) errors.add("first_version_not_created_on");
  if (document.versions.some((v) => !sameJson(structure(v), structure(document.versions[0])))) errors.add("structural_change");
  return errors;
}

export function validity(given) {
  const errors = [...(given.goal ? goalErrors(given.goal) : documentErrors(given.document))].sort();
  return { valid: errors.length === 0, errors };
}

// ---------------------------------------------------------------- slice 1 rules

export function goalIsDue(given) {
  return { due: isDue(given.goal, day(given.date), given.hijri_corrections ?? []) };
}

export function requirementStanding(given) {
  const c = given.hijri_corrections ?? [];
  const D = day(given.date);
  const idx = index(given.counts);
  const goal = trackerless(given.goal);
  const ap = goal.active_period;
  const type = goal.requirement.type;
  let window = null;
  if (inActive(ap, D)) {
    if (type === "cumulative_total") window = { first: day(ap.start_date), last: D };
    else if (type === "period_total") {
      const period = periodOf(D, goal.requirement.period, given.week_start, c);
      window = period && clip(period, ap);
    } else window = { first: D, last: D };
  }
  let due = window !== null;
  if (due && type === "period_total") due = range(window).some((n) => isDue(goal, n, c));
  else if (due && type !== "cumulative_total") due = isDue(goal, D, c);
  if (!due) window = { first: D, last: D };
  const days = range(window).filter((n) => n <= D && inActive(ap, n));
  const p = periodProgress(goal, idx, days);
  return {
    status: due ? (progressMet(goal, p) ? "met" : "not_met") : "not_due",
    window: { from: iso(window.first), to: iso(window.last) },
    progress: p.progress,
    target: goal.sessions.length === 0 ? goal.count_policy.target : null,
    sessions: p.sessions,
  };
}

export function daysPerPeriod(given) {
  const c = given.hijri_corrections ?? [];
  const D = day(given.date);
  const idx = index(given.counts);
  const goal = given.goal;
  const notDue = { status: "not_due", window: { from: given.date, to: given.date }, qualifying_days: 0, required_days: 0 };
  if (!inActive(goal.active_period, D)) return notDue;
  const period = periodOf(D, goal.requirement.period, given.week_start, c);
  const window = period && clip(period, goal.active_period);
  if (!window) return notDue;
  const t = tally(goal, idx, window, D, c);
  if (t.required <= 0) return notDue;
  return {
    status: t.qualifying >= t.required ? "met" : "not_met",
    window: { from: iso(window.first), to: iso(window.last) },
    qualifying_days: t.qualifying,
    required_days: t.required,
  };
}

export function goalCompletion(given) {
  return { completed: completed(given.goal, index(given.counts), day(given.date)) };
}

export function effectivePracticeDay(given) {
  const local = new Intl.DateTimeFormat("en-CA", { timeZone: given.timezone, year: "numeric", month: "2-digit", day: "2-digit" }).format(
    new Date(given.instant),
  );
  const afterMaghrib = given.day_reset === "maghrib" && given.maghrib !== null && Date.parse(given.instant) >= Date.parse(given.maghrib);
  return { date: afterMaghrib ? iso(day(local) + 1) : local };
}

export function dailyPaceRule(given) {
  return dailyPace(given.goal, index(given.counts), day(given.date), given.hijri_corrections ?? []);
}

/** Every rule of goal-model/v1, by fixture name. */
export const RULES = {
  effective_practice_day: effectivePracticeDay,
  goal_is_due: goalIsDue,
  requirement_standing: requirementStanding,
  days_per_period: daysPerPeriod,
  goal_completion: goalCompletion,
  goal_streak: goalStreak,
  goal_validity: validity,
  goal_version_on_day: versionOnDay,
  goal_version_add: versionAdd,
  count_attribution: countAttribution,
  make_up: makeUp,
  excused_days: excuse,
  consistency,
  daily_pace: dailyPaceRule,
  today_ring: todayRing,
  goal_list_placement: listPlacement,
  goal_order_merge: goalOrderMerge,
};

export { sameJson, settingsOf };
