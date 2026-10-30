/*
 * Awrad goals prototype. No build step, no framework.
 *
 * Layout of this file:
 *   1. VARIANTS        ideas to A/B in the Lab (add a switch = add an entry here, read it with v('key'))
 *   2. Tokens in JS    motion.json values the animations need
 *   3. Strings         en + ar (a stand-in for the platforms' localization resources)
 *   4. Dates + Hijri   Intl islamic-umalqura (the apps use contracts/hijri-calendar/v1 + corrections)
 *   5. Goal rules      a simplified, readable take on contracts/goal-model/v1 (not the fixture-tested one)
 *   6. Seed data       goals that reproduce the approved designs
 *   7. State           one object, persisted to localStorage
 *   8. Components      ring, goal card, home row, chips
 *   9. Screens         home, goals, counting, create, placeholders
 *  10. Create flow     CREATE_STEPS: each step is a small module; reorder or replace freely
 *  11. Overlays        menu sheet, dialog, toast
 *  12. Motion          page transitions, press, count pop, number roll, ring fill
 *  13. Lab             controls, data editor, variants, notes
 *  14. Events + boot   and window.proto for scripting (screenshots)
 */
"use strict";

/* ============================================================== 1. VARIANTS
 * Each entry: label, note (what the question is), options {value: label}, value (default).
 * Read with v('ringStyle'). The Lab renders every entry automatically.
 */
const VARIANTS = {
  createFlow: {
    label: "Create flow",
    note: "Three ways to create the same goal. A: one question per screen. B: an editable sentence in one sheet. C: templates, then a short form. The Controls tab has Try A / B / C buttons.",
    options: { wizard: "A. Wizard", sentence: "B. Sentence", templates: "C. Templates" },
    value: "wizard",
  },
  ringStyle: {
    label: "Counter ring colour",
    note: "Design: amber/gold arc (not a token). Green uses the `progress` token. Threshold switches gold → green once the minimum is reached.",
    options: { gold: "Gold (design)", green: "Green (progress token)", threshold: "Gold → green at minimum" },
    value: "gold",
  },
  overflowDisplay: {
    label: "Past the target",
    note: "Design: a grey full lap plus a gold overflow arc. Alternative: the ring stays full and the number says how far over.",
    options: { lap: "Grey lap + overflow arc (design)", full: "Ring stays full" },
    value: "lap",
  },
  minimumMarker: {
    label: "Minimum marker on the ring",
    note: "Not in the design. A small dot on the track where the minimum sits.",
    options: { off: "Off (design)", dot: "Dot" },
    value: "off",
  },
  counterChip: {
    label: "Chip under the counter",
    note: "Design shows \"minimum 70\". Dynamic: shows the next threshold to reach, then how far over.",
    options: { dynamic: "Next threshold", minimum: "Always the minimum (design)" },
    value: "dynamic",
  },
  circleSubLabel: {
    label: "Inside the circle",
    note: "Design shows only the number.",
    options: { none: "Number only (design)", target: "Number + \"of 100\"" },
    value: "none",
  },
  tapArea: {
    label: "Counter tap area",
    note: "The design says \"Tap the circle to count\". Whole screen = the lower half of the page counts.",
    options: { circle: "Circle (design)", screen: "Whole lower area" },
    value: "circle",
  },
  goalRowLayout: {
    label: "My Goals card layout",
    note: "My Goals design: ring on the left. Home design: ring on the right.",
    options: { left: "Ring left (design)", right: "Ring right" },
    value: "left",
  },
  streakGlyph: {
    label: "Streak glyph",
    note: "Design uses the 🔥 emoji; icons.json has `streak` (local_fire_department). Rules say icons only from the set.",
    options: { emoji: "🔥 emoji (design)", icon: "Token icon `streak`" },
    value: "emoji",
  },
  upcomingMeta: {
    label: "Upcoming goal second line",
    note: "Design shows \"1 ramadan\" / \"5 thurdays\". Read here as how many occurrences remain. Alternative: when it's next due.",
    options: { remaining: "Occurrences left (design reading)", next: "Next due date" },
    value: "remaining",
  },
  numberFormat: {
    label: "Big numbers",
    note: "Design chips show \"70000 times\" without grouping.",
    options: { plain: "70000 (design)", grouped: "70,000" },
    value: "plain",
  },
  homeDateStyle: {
    label: "Home Hijri date style",
    note: "Design: a large title. typography.json says `title` (22) is \"the Hijri date on Home\".",
    options: { largeTitle: "largeTitle 34 (design)", title: "title 22 (token note)" },
    value: "largeTitle",
  },
  createOrder: {
    label: "Wizard order (A only)",
    note: "Draft v0 asks how many before when. \"Once with a total\" changes what the number means, so when-first may read better.",
    options: { countFirst: "Dhikr → How many → When", whenFirst: "Dhikr → When → How many" },
    value: "countFirst",
  },
};
const v = (key) => (state.variants[key] ?? VARIANTS[key].value);

/* ============================================================== 2. Tokens in JS (motion.json) */
const MOTION = {
  easing: { emphasized: "cubic-bezier(0.2, 0, 0, 1)", decelerate: "cubic-bezier(0.05, 0.7, 0.1, 1)", accelerate: "cubic-bezier(0.3, 0, 0.8, 0.15)", linear: "linear" },
  duration: { fade: 100, color: 150, short: 250, medium: 300, page: 350, long: 450 },
  spring: {
    spatial: [0.8, 380], spatialFast: [0.6, 800], spatialSlow: [0.8, 200],
    effects: [1.0, 1600], bouncy: [0.5, 1500], bouncySoft: [0.5, 200],
  },
  press: { cardScale: 0.985, buttonScale: 0.98 },
  countTap: { popScale: 1.04 },
  pagePush: { enterScaleFrom: 0.96, enterFadeFrom: 0.35, exitScaleTo: 0.985, depthDim: 0.34 },
  pagePop: { enterScaleFrom: 0.985, enterFadeFrom: 0.6, exitScaleTo: 0.96 },
  tabSwitch: { enterScaleFrom: 0.985, enterFadeFrom: 0.4, exitScaleTo: 1.01 },
  listAppear: { offset: 8, stagger: 40, maxStaggered: 6 },
};

/* A spring (dampingRatio, stiffness, mass 1) sampled into a CSS linear() easing, so the
   web can play the same springs as the apps. Cached per spring. */
const springCache = {};
function spring(name) {
  if (springCache[name]) return springCache[name];
  const [zeta, k] = MOTION.spring[name];
  const w0 = Math.sqrt(k);
  const x = (t) => {
    if (zeta < 1) {
      const wd = w0 * Math.sqrt(1 - zeta * zeta);
      return 1 - Math.exp(-zeta * w0 * t) * (Math.cos(wd * t) + (zeta * w0 / wd) * Math.sin(wd * t));
    }
    return 1 - Math.exp(-w0 * t) * (1 + w0 * t);
  };
  let T = 0.05;
  for (let t = 0; t < 4; t += 1 / 500) if (Math.abs(1 - x(t)) > 0.002) T = t;
  const N = 48, pts = [];
  for (let i = 0; i <= N; i++) pts.push(i === N ? 1 : +x((T * i) / N).toFixed(4));
  return (springCache[name] = { easing: `linear(${pts.join(", ")})`, duration: Math.round(T * 1000) });
}

/* ============================================================== 3. Strings */
const STRINGS = {
  en: {
    nav_home: "Home", nav_goals: "Goals", nav_library: "Library", nav_community: "Community",
    todays_goals: "Today's goals", view_all: "View All", next_prayer: "Next prayer",
    featured: "Featured dhikr collections", dhikrs_count: (n) => `${n} dhikrs`,
    nothing_today: "Nothing due today.", add_goal: "Add a goal",
    my_goals: "My Goals", active: "Active", history: "History",
    upcoming: "Upcoming Goals", paused: "Paused", completed: "Completed", ended: "Ended",
    no_active: "No goals yet. Tap + to add one.", no_history: "Completed and ended goals appear here.",
    streak_unit: { day: (n) => (n === 1 ? "1 day" : `${n} days`), week: (n) => (n === 1 ? "1 week" : `${n} weeks`), month: (n) => (n === 1 ? "1 month" : `${n} months`) },
    no_streak: "No streak yet", paused_since: (d) => `Paused since ${d}`,
    completed_on: (d) => `Completed ${d}`, ended_on: (d) => `Ended ${d}`, counted: (n) => `${n} counted`,
    starts: (d) => `Starts ${d}`, next_due: (d) => `Next ${d}`,
    remaining_season: (n, season) => `${n} ${season.toLowerCase()}`,
    remaining_weekday: (n, day) => `${n} ${day.toLowerCase()}s`, remaining_days: (n) => `${n} days`,
    tap_circle: "Tap the circle to count", tap_anywhere: "Tap anywhere below to count",
    start_audio: "Start audio count", stop_audio: "Stop audio count",
    text_size: "Text size", more_label: "More", back: "Back", close: "Close", add_label: "Add goal",
    timer: "Timer", count_list: "Count history",
    minimum_n: (n) => `minimum ${n}`, target_n: (n) => `target ${n}`, over_n: (n) => `+${n} over target`,
    target_reached: "target reached", cap_n: (n) => `cap ${n} reached`, to_go: (n) => `${n} to go`,
    any_count: "any count", not_due: "Not due today", of_n: (n) => `of ${n}`,
    session_names: { after_fajr: "After Fajr", morning: "Morning", after_maghrib: "After Maghrib", evening: "Evening", before_sleep: "Before sleep" },
    // Goal chip text, derived from the schedule + requirement + count policy
    chip_daily: (t) => `Daily ${t}`,
    chip_min_target_daily: (m, t) => `minimum ${m}, target ${t} daily`,
    chip_times: (t) => `${t} times`,
    chip_weekdays: (t, days) => (t > 1 ? `${t} every ${days}` : `every ${days}`),
    chip_season: (season, t) => (t > 1 ? `Every ${season}, ${t} daily` : `Every ${season} daily`),
    chip_white: (t) => (t > 1 ? `White days, ${t} daily` : "Every white day"),
    chip_generic: (t) => `${t} daily`,
    chip_period_total: (t, p) => `${t} a ${p}`,
    chip_days_per_period: (d, p) => `${d} days a ${p}`,
    chip_tracker: "Any count",
    chip_min_prefix: (m) => `minimum ${m}, `,
    chip_cap: (x) => `, cap ${x}`,
    chip_by: (d) => ` by ${d}`,
    chip_sessions: (n) => ` · ${n} sessions`,
    period: { week: "week", month: "month", hijri_month: "Hijri month" },
    // Menu, dialogs, toasts
    edit: "Edit goal", pause: "Pause goal", resume: "Resume goal", delete: "Delete goal",
    undo: "Undo last count", reset_today: "Reset today's count",
    delete_title: "Delete this goal?", delete_body: "Its counts and streak go with it. This can't be undone.",
    cancel: "Cancel", delete_btn: "Delete",
    t_saved: "Goal saved", t_updated: "Goal updated", t_paused: "Goal paused", t_resumed: "Goal resumed", t_deleted: "Goal deleted",
    t_cap: (n) => `Cap reached: counting stops at ${n}`, t_timer: "Timer isn't designed yet", t_list: "Count history isn't designed yet",
    t_min: "Minimum reached", t_target: "Target reached", t_undo: "Last count undone", t_reset: "Today's count reset",
    // Create flow
    step_dhikr: "Pick a dhikr", step_dhikr_lede: "Search the library, or pick from a collection.",
    search_ph: "Search dhikrs", no_results: "No dhikr matches.",
    step_count: "How many?", step_count_daily: "Each day it's due.", step_count_total: "In total, until it's done.",
    step_when: "When?", step_when_lede: "Pick a pattern. More options holds the rest.",
    when_every_day: "Every day", when_weekdays: "Selected weekdays", when_ramadan: "Ramadan",
    when_white: "White days", when_white_sub: "13, 14 and 15 of every Hijri month",
    when_once: "Once, with a total", when_once_sub: "One total across the whole goal",
    when_custom: "Custom schedule", when_custom_sub: "Kept from the goal; edit in the Lab",
    ramadan_whole: "Whole month", ramadan_first10: "First 10", ramadan_last10: "Last 10", ramadan_odd: "Odd nights",
    more_options: "More options",
    f_minimum: "Minimum", f_minimum_help: "Optional. Reaching it keeps the streak.",
    f_cap: "Cap", f_cap_help: "Optional. Counting stops here.",
    f_start: "Start date", f_end: "End date", f_end_help: "Optional. Leave empty to keep going.",
    f_sessions: "Sessions", f_sessions_help: "Optional. Each session must reach its own target.",
    f_streak: "Streak counts when I reach",
    streak_opt: { auto: "Automatic", any_count: "Any count", minimum: "Minimum", target: "Target", maximum: "Cap" },
    step_review: "Review", step_review_lede: "This is how the goal will look.",
    preview_goals: "On My Goals", preview_home: "On Home",
    s_dhikr: "Dhikr", s_chip: "Chip", s_when: "Schedule", s_active: "Active", s_req: "Requirement", s_policy: "Count policy",
    s_sessions: "Sessions", s_streak: "Streak counts at", s_completion: "Completes", from_to: (a, b) => (b ? `${a} → ${b}` : `From ${a}`),
    req: { per_due_date: "Each due day", cumulative_total: "One total", period_total: "Per period", days_per_period: "Days per period", tracker: "Tracker" },
    completion: { never: "Never", when_target_reached: "When the total is reached", when_duration_ended: "When the end date passes" },
    show_json: "Show goal JSON", new_goal: "New",
    continue: "Continue", save: "Save goal", save_changes: "Save changes",
    err_count: "Enter a whole number above 0", err_min: "Must be below the target", err_cap: "Must be at least the target",
    err_weekdays: "Pick at least one day", err_end: "Must be on or after the start date",
    placeholder: "Not part of this prototype.",
    // Create flows A, B, C
    ramadan_middle10: "Middle 10", ramadan_sub: "The whole month, or a third of it",
    new_goal_title: "New goal", set_goal: "Set a goal", skip: "Skip", add_goal_btn: "Add goal",
    step_more: "More options", step_more_lede: "Optional. Skip if you don't need these.",
    sentence: (dh, n, s, by) => `Say ${dh} ${n} times ${s}${by ? " " + by : ""}`,
    tok_pick_dhikr: "pick a dhikr", tok_every_day: "every day", tok_weekdays: (days) => `every ${days}`, tok_pick_days: "on some days",
    tok_ramadan: { whole: "every day of Ramadan", first10: "in Ramadan's first 10 days", middle10: "in Ramadan's middle 10 days", last10: "in Ramadan's last 10 nights", odd: "on Ramadan's odd nights" },
    tok_white: "on the white days", tok_total: "in total", tok_custom: "on a custom schedule",
    by_date: (d) => `by ${d}`, no_deadline: "no deadline", no_deadline_btn: "No deadline", no_end_btn: "No end date",
    sg_every_day: "Every day", sg_ramadan: "During Ramadan", sg_total: "10,000 in total", sg_friday: "Every Friday",
    more_short: "More", row_min: "At least", row_cap: "Stop at", row_from: "From", row_until: "until", row_sessions: "Sessions:", row_streak: "Streak counts at",
    none: "none", no_end: "no end", today_word: "today", pad_done: "Done", clear: "Clear",
    some_weekdays: "Some weekdays", every_friday: "Every Friday", in_total: "In total", in_total_sub: "One total, with an optional deadline",
    shared_q: (name) => `Count ${name} from your other goal too?`,
    shared_yes: "Yes, share counts", shared_yes_sub: "Each count adds to both goals",
    shared_no: "No, count separately", shared_no_sub: "This goal keeps its own count",
    templates_lede: "Start from a template.", for_dhikr: (n) => `For ${n}`,
    tpl_daily: "Daily habit", tpl_daily_ex: "100 every day",
    tpl_ramadan: "Ramadan", tpl_ramadan_ex: "Every day of Ramadan · Last 10 nights", tpl_ramadan_avatar: "R",
    tpl_white: "White days", tpl_white_ex: "13–15 of every Hijri month", tpl_white_avatar: "13",
    tpl_weekly: "Weekly", tpl_weekly_ex: "Every Friday",
    tpl_total: "One-time total", tpl_total_ex: "70,000 in total",
    tpl_custom: "Custom", tpl_custom_ex: "Choose every detail",
    f_dhikr: "Dhikr", f_count: "How many", f_count_total: "How many in total", f_when: "When", f_by: "Finish by",
    library_stub: "A stub: just enough to start a goal from a dhikr.",
    prayer_name: "Asr", prayer_in: "in 1 h 12 min", prayer_place: "Kozhikode",
  },
  ar: {
    nav_home: "الرئيسية", nav_goals: "الأهداف", nav_library: "المكتبة", nav_community: "المجتمع",
    todays_goals: "أهداف اليوم", view_all: "عرض الكل", next_prayer: "الصلاة القادمة",
    featured: "مجموعات أذكار مختارة", dhikrs_count: (n) => `${n} أذكار`,
    nothing_today: "لا شيء مستحق اليوم.", add_goal: "أضف هدفًا",
    my_goals: "أهدافي", active: "النشطة", history: "السجل",
    upcoming: "الأهداف القادمة", paused: "متوقفة مؤقتًا", completed: "مكتملة", ended: "منتهية",
    no_active: "لا أهداف بعد. اضغط + لإضافة هدف.", no_history: "تظهر هنا الأهداف المكتملة والمنتهية.",
    streak_unit: { day: (n) => (n === 1 ? "يوم واحد" : `${n} أيام`), week: (n) => `${n} أسابيع`, month: (n) => `${n} أشهر` },
    no_streak: "لا سلسلة بعد", paused_since: (d) => `متوقف منذ ${d}`,
    completed_on: (d) => `اكتمل ${d}`, ended_on: (d) => `انتهى ${d}`, counted: (n) => `${n} مرة`,
    starts: (d) => `يبدأ ${d}`, next_due: (d) => `التالي ${d}`,
    remaining_season: (n, season) => `${n} ${season}`, remaining_weekday: (n, day) => `${n} × ${day}`, remaining_days: (n) => `${n} أيام`,
    tap_circle: "اضغط على الدائرة للعدّ", tap_anywhere: "اضغط في أي مكان بالأسفل للعدّ",
    start_audio: "ابدأ العدّ الصوتي", stop_audio: "أوقف العدّ الصوتي",
    text_size: "حجم النص", more_label: "المزيد", back: "رجوع", close: "إغلاق", add_label: "إضافة هدف",
    timer: "المؤقت", count_list: "سجل العدّ",
    minimum_n: (n) => `الحد الأدنى ${n}`, target_n: (n) => `الهدف ${n}`, over_n: (n) => `+${n} فوق الهدف`,
    target_reached: "تم بلوغ الهدف", cap_n: (n) => `بلغ الحد الأقصى ${n}`, to_go: (n) => `بقي ${n}`,
    any_count: "أي عدد", not_due: "غير مستحق اليوم", of_n: (n) => `من ${n}`,
    session_names: { after_fajr: "بعد الفجر", morning: "الصباح", after_maghrib: "بعد المغرب", evening: "المساء", before_sleep: "قبل النوم" },
    chip_daily: (t) => `${t} يوميًا`,
    chip_min_target_daily: (m, t) => `الحد الأدنى ${m}، الهدف ${t} يوميًا`,
    chip_times: (t) => `${t} مرة`,
    chip_weekdays: (t, days) => (t > 1 ? `${t} كل ${days}` : `كل ${days}`),
    chip_season: (season, t) => (t > 1 ? `كل ${season}، ${t} يوميًا` : `كل ${season} يوميًا`),
    chip_white: (t) => (t > 1 ? `الأيام البيض، ${t} يوميًا` : "كل يوم من الأيام البيض"),
    chip_generic: (t) => `${t} يوميًا`,
    chip_period_total: (t, p) => `${t} في ${p}`,
    chip_days_per_period: (d, p) => `${d} أيام في ${p}`,
    chip_tracker: "أي عدد",
    chip_min_prefix: (m) => `الحد الأدنى ${m}، `,
    chip_cap: (x) => `، الحد الأقصى ${x}`,
    chip_by: (d) => ` قبل ${d}`,
    chip_sessions: (n) => ` · ${n} جلسات`,
    period: { week: "الأسبوع", month: "الشهر", hijri_month: "الشهر الهجري" },
    edit: "تعديل الهدف", pause: "إيقاف مؤقت", resume: "استئناف", delete: "حذف الهدف",
    undo: "تراجع عن آخر عدّة", reset_today: "تصفير عدّ اليوم",
    delete_title: "حذف هذا الهدف؟", delete_body: "ستُحذف أعداده وسلسلته معه. لا يمكن التراجع.",
    cancel: "إلغاء", delete_btn: "حذف",
    t_saved: "تم حفظ الهدف", t_updated: "تم تحديث الهدف", t_paused: "تم إيقاف الهدف مؤقتًا", t_resumed: "تم استئناف الهدف", t_deleted: "تم حذف الهدف",
    t_cap: (n) => `بلغت الحد الأقصى: يتوقف العدّ عند ${n}`, t_timer: "المؤقت لم يُصمَّم بعد", t_list: "سجل العدّ لم يُصمَّم بعد",
    t_min: "بلغت الحد الأدنى", t_target: "بلغت الهدف", t_undo: "تم التراجع عن آخر عدّة", t_reset: "تم تصفير عدّ اليوم",
    step_dhikr: "اختر ذكرًا", step_dhikr_lede: "ابحث في المكتبة أو اختر من مجموعة.",
    search_ph: "ابحث في الأذكار", no_results: "لا ذكر مطابق.",
    step_count: "كم مرة؟", step_count_daily: "في كل يوم مستحق.", step_count_total: "إجمالًا حتى يكتمل.",
    step_when: "متى؟", step_when_lede: "اختر نمطًا. باقي الخيارات تحت «خيارات أخرى».",
    when_every_day: "كل يوم", when_weekdays: "أيام محددة من الأسبوع", when_ramadan: "رمضان",
    when_white: "الأيام البيض", when_white_sub: "١٣ و١٤ و١٥ من كل شهر هجري",
    when_once: "مرة واحدة بإجمالي", when_once_sub: "إجمالي واحد طوال الهدف",
    when_custom: "جدول مخصص", when_custom_sub: "محفوظ من الهدف؛ عدّله في المختبر",
    ramadan_whole: "الشهر كله", ramadan_first10: "العشر الأوائل", ramadan_last10: "العشر الأواخر", ramadan_odd: "الليالي الوترية",
    more_options: "خيارات أخرى",
    f_minimum: "الحد الأدنى", f_minimum_help: "اختياري. بلوغه يحفظ السلسلة.",
    f_cap: "الحد الأقصى", f_cap_help: "اختياري. يتوقف العدّ عنده.",
    f_start: "تاريخ البدء", f_end: "تاريخ الانتهاء", f_end_help: "اختياري. اتركه فارغًا للاستمرار.",
    f_sessions: "الجلسات", f_sessions_help: "اختياري. يجب أن تبلغ كل جلسة هدفها.",
    f_streak: "تُحسب السلسلة عند بلوغ",
    streak_opt: { auto: "تلقائي", any_count: "أي عدد", minimum: "الحد الأدنى", target: "الهدف", maximum: "الحد الأقصى" },
    step_review: "مراجعة", step_review_lede: "هكذا سيظهر الهدف.",
    preview_goals: "في «أهدافي»", preview_home: "في الرئيسية",
    s_dhikr: "الذكر", s_chip: "الوسم", s_when: "الجدول", s_active: "النشاط", s_req: "المتطلب", s_policy: "سياسة العدّ",
    s_sessions: "الجلسات", s_streak: "تُحسب السلسلة عند", s_completion: "يكتمل", from_to: (a, b) => (b ? `${a} ← ${b}` : `من ${a}`),
    req: { per_due_date: "كل يوم مستحق", cumulative_total: "إجمالي واحد", period_total: "لكل فترة", days_per_period: "أيام في الفترة", tracker: "تتبّع" },
    completion: { never: "أبدًا", when_target_reached: "عند بلوغ الإجمالي", when_duration_ended: "عند انتهاء المدة" },
    show_json: "عرض JSON للهدف", new_goal: "جديد",
    continue: "متابعة", save: "حفظ الهدف", save_changes: "حفظ التغييرات",
    err_count: "أدخل عددًا صحيحًا أكبر من ٠", err_min: "يجب أن يكون أقل من الهدف", err_cap: "يجب ألا يقل عن الهدف",
    err_weekdays: "اختر يومًا واحدًا على الأقل", err_end: "يجب أن يكون في تاريخ البدء أو بعده",
    placeholder: "ليس جزءًا من هذا النموذج.",
    ramadan_middle10: "العشر الأواسط", ramadan_sub: "الشهر كله أو ثلث منه",
    new_goal_title: "هدف جديد", set_goal: "ضع هدفًا", skip: "تخطَّ", add_goal_btn: "أضف الهدف",
    step_more: "خيارات أخرى", step_more_lede: "اختياري. تخطَّه إن لم تحتجه.",
    sentence: (dh, n, s, by) => `قل ${dh} ${n} مرة ${s}${by ? " " + by : ""}`,
    tok_pick_dhikr: "اختر ذكرًا", tok_every_day: "كل يوم", tok_weekdays: (days) => `كل ${days}`, tok_pick_days: "في بعض الأيام",
    tok_ramadan: { whole: "كل يوم من رمضان", first10: "في العشر الأوائل من رمضان", middle10: "في العشر الأواسط من رمضان", last10: "في العشر الأواخر من رمضان", odd: "في ليالي الوتر من رمضان" },
    tok_white: "في الأيام البيض", tok_total: "إجمالًا", tok_custom: "وفق جدول مخصص",
    by_date: (d) => `قبل ${d}`, no_deadline: "بلا موعد نهائي", no_deadline_btn: "بلا موعد نهائي", no_end_btn: "بلا تاريخ انتهاء",
    sg_every_day: "كل يوم", sg_ramadan: "في رمضان", sg_total: "10,000 إجمالًا", sg_friday: "كل جمعة",
    more_short: "المزيد", row_min: "على الأقل", row_cap: "توقف عند", row_from: "من", row_until: "حتى", row_sessions: "الجلسات:", row_streak: "تُحسب السلسلة عند",
    none: "لا شيء", no_end: "بلا نهاية", today_word: "اليوم", pad_done: "تم", clear: "مسح",
    some_weekdays: "بعض أيام الأسبوع", every_friday: "كل جمعة", in_total: "إجمالًا", in_total_sub: "إجمالي واحد مع موعد نهائي اختياري",
    shared_q: (name) => `احتساب ${name} من هدفك الآخر أيضًا؟`,
    shared_yes: "نعم، شارك العدّ", shared_yes_sub: "كل عدّة تُضاف إلى الهدفين",
    shared_no: "لا، احسب كلًّا على حدة", shared_no_sub: "لهذا الهدف عدّه الخاص",
    templates_lede: "ابدأ من قالب.", for_dhikr: (n) => `لـ ${n}`,
    tpl_daily: "عادة يومية", tpl_daily_ex: "100 كل يوم",
    tpl_ramadan: "رمضان", tpl_ramadan_ex: "كل يوم من رمضان · العشر الأواخر", tpl_ramadan_avatar: "ر",
    tpl_white: "الأيام البيض", tpl_white_ex: "١٣–١٥ من كل شهر هجري", tpl_white_avatar: "13",
    tpl_weekly: "أسبوعي", tpl_weekly_ex: "كل جمعة",
    tpl_total: "إجمالي لمرة واحدة", tpl_total_ex: "70,000 إجمالًا",
    tpl_custom: "مخصص", tpl_custom_ex: "اختر كل التفاصيل",
    f_dhikr: "الذكر", f_count: "كم مرة", f_count_total: "كم مرة إجمالًا", f_when: "متى", f_by: "أنهِ قبل",
    library_stub: "نموذج مبسّط: يكفي لبدء هدف من ذكر.",
    prayer_name: "العصر", prayer_in: "بعد ١ س ١٢ د", prayer_place: "كوزيكود",
  },
};
const lang = () => state.settings.lang || (state.settings.dir === "rtl" ? "ar" : "en");
const LOCALE = () => ({ en: "en-GB", ar: "ar-u-nu-latn", ml: "ml-u-nu-latn" }[lang()] || "en-GB");
function t(key, ...args) {
  const s = STRINGS[lang()]?.[key] ?? STRINGS.en[key];
  return typeof s === "function" ? s(...args) : s;
}
const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
const fmtN = (n) => (v("numberFormat") === "grouped" ? new Intl.NumberFormat("en-US").format(n) : String(n));
const abbr = (n) => (n >= 100000 ? `${Math.round(n / 1000)}k` : n >= 10000 ? `${(n / 1000).toFixed(1).replace(/\.0$/, "")}k` : String(n));

/* ============================================================== 4. Dates + Hijri */
const WEEKDAYS = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"];
const HIJRI_MONTHS = {
  en: ["Muharram", "Safar", "Rabi al-Awwal", "Rabi al-Thani", "Jumada al-Awwal", "Jumada al-Thani", "Rajab", "Sha'ban", "Ramadan", "Shawwal", "Dhu al-Qadah", "Dhu al-Hijjah"],
  ar: ["محرم", "صفر", "ربيع الأول", "ربيع الآخر", "جمادى الأولى", "جمادى الآخرة", "رجب", "شعبان", "رمضان", "شوال", "ذو القعدة", "ذو الحجة"],
};
HIJRI_MONTHS.ml = ["മുഹർറം", "സഫർ", "റബീഉൽ അവ്വൽ", "റബീഉൽ ആഖിർ", "ജുമാദൽ ഊലാ", "ജുമാദൽ ആഖിറ", "റജബ്", "ശഅ്ബാൻ", "റമദാൻ", "ശവ്വാൽ", "ദുൽഖഅ്ദ", "ദുൽഹിജ്ജ"];
const hMonths = () => HIJRI_MONTHS[lang()] || HIJRI_MONTHS.en;
const toDate = (ds) => new Date(ds + "T00:00:00Z");
const toDS = (d) => d.toISOString().slice(0, 10);
const addDays = (ds, n) => { const d = toDate(ds); d.setUTCDate(d.getUTCDate() + n); return toDS(d); };
const diffDays = (a, b) => Math.round((toDate(b) - toDate(a)) / 86400000);
const weekday = (ds) => WEEKDAYS[(toDate(ds).getUTCDay() + 6) % 7];
const localToday = () => { const d = new Date(); return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`; };
const monthLen = (y, m) => new Date(Date.UTC(y, m, 0)).getUTCDate();

const HIJRI_FMT = new Intl.DateTimeFormat("en-u-ca-islamic-umalqura-nu-latn", { timeZone: "UTC", year: "numeric", month: "numeric", day: "numeric" });
const hijriCache = new Map();
function hijri(ds) {
  let h = hijriCache.get(ds);
  if (h) return h;
  const o = {};
  for (const p of HIJRI_FMT.formatToParts(toDate(ds))) if (["year", "month", "day", "relatedYear"].includes(p.type)) o[p.type] = parseInt(p.value, 10);
  h = { y: o.year ?? o.relatedYear, m: o.month, d: o.day };
  hijriCache.set(ds, h);
  return h;
}
const isLastHijriDay = (ds) => hijri(addDays(ds, 1)).d === 1;
function findDate(pred, from, limit = 800, step = 1) {
  let d = from;
  for (let i = 0; i < limit; i++, d = addDays(d, step)) if (pred(d)) return d;
  return null;
}
const gregorianOfHijri = (y, m, d, from) => findDate((ds) => { const h = hijri(ds); return h.y === y && h.m === m && h.d === d; }, from, 1200) ;
function fmtDate(ds, opts = { day: "numeric", month: "short" }) {
  return new Intl.DateTimeFormat(LOCALE(), { timeZone: "UTC", ...opts }).format(toDate(ds));
}
const fmtHijri = (ds, withYear = false) => { const h = hijri(ds); return `${h.d} ${hMonths()[h.m - 1]}${withYear ? " " + h.y : ""}`; };
const weekdayName = (wd, style = "long") => new Intl.DateTimeFormat(LOCALE(), { weekday: style, timeZone: "UTC" }).format(toDate(addDays("2024-01-01", WEEKDAYS.indexOf(wd))));

/* ============================================================== 5. Goal rules (simplified)
 * Shapes follow contracts/goal-model/v1/goal-model.schema.json (goal_shape), plus prototype-only
 * fields: id, dhikr, name (optional override), preset, count_entries [{date, session, count}]
 * (the fixtures' `counts`), and counts: "shared" | "dedicated" (whether counts are shared with
 * other goals on the same dhikr).
 */
const activeEnd = (g) => {
  const ap = g.active_period;
  const byDuration = ap.duration_days ? addDays(ap.start_date, ap.duration_days - 1) : null;
  if (ap.end_date && byDuration) return ap.end_date < byDuration ? ap.end_date : byDuration;
  return ap.end_date || byDuration;
};
const inActive = (g, ds) => ds >= g.active_period.start_date && (!activeEnd(g) || ds <= activeEnd(g));
const pausedOn = (g, ds) => (g.paused || []).some((p) => ds >= p.from && (p.to == null || ds <= p.to));
function mdIn(m, d, s, e) {
  const k = m * 100 + d, a = s.month * 100 + s.day, b = e.month * 100 + e.day;
  return a <= b ? k >= a && k <= b : k >= a || k <= b;
}
function onSchedule(g, ds) {
  const s = g.schedule;
  switch (s.kind) {
    case "every_day": case "one_time": return true;
    case "weekdays": return s.weekdays.includes(weekday(ds));
    case "every_n_days": { const n = diffDays(s.anchor_date || g.active_period.start_date, ds); return n >= 0 && n % s.every === 0; }
    case "month_days": { const [y, m, d] = ds.split("-").map(Number); const L = monthLen(y, m); return s.days.some((x) => x === d || (x > L && d === L)); }
    case "specific_dates": return s.dates.includes(ds);
    case "hijri_month_days": { const h = hijri(ds); return s.days.some((x) => x === h.d || (x === 30 && h.d === 29 && isLastHijriDay(ds))); }
    case "yearly": {
      if (s.calendar === "hijri") {
        const h = hijri(ds);
        return s.ranges.some((r) => mdIn(h.m, h.d, r.start, r.end) || (h.d === 29 && isLastHijriDay(ds) && mdIn(h.m, 30, r.start, r.end)));
      }
      const [y, m, d] = ds.split("-").map(Number);
      const leapFix = m === 2 && d === 28 && monthLen(y, 2) === 28;
      return s.ranges.some((r) => mdIn(m, d, r.start, r.end) || (leapFix && mdIn(2, 29, r.start, r.end)));
    }
    default: return false;
  }
}
const isDue = (g, ds) => inActive(g, ds) && !pausedOn(g, ds) && onSchedule(g, ds);

/* Count policy: the goal's, or each session's when it has sessions. */
const policyOf = (g, session = null) => (session ? g.sessions.find((s) => s.id === session)?.count_policy : null) || (g.sessions.length ? g.sessions[0].count_policy : g.count_policy);
function displayPolicy(g) {
  if (!g.sessions.length) return g.count_policy;
  const sum = (k) => (g.sessions.every((s) => s.count_policy[k] != null) ? g.sessions.reduce((a, s) => a + s.count_policy[k], 0) : null);
  return { minimum: sum("minimum"), target: sum("target"), maximum: sum("maximum"), streak_threshold: g.sessions[0].count_policy.streak_threshold };
}
const thresholdValue = (p) => ({ any_count: 1, minimum: p.minimum, target: p.target, maximum: p.maximum }[p.streak_threshold] ?? 1);
function countIn(g, from, to, session) {
  let n = 0;
  for (const c of g.count_entries) if (c.date >= from && c.date <= to && (session === undefined || c.session === session)) n += c.count;
  return n;
}
const countOn = (g, ds, session) => countIn(g, ds, ds, session);

function periodWindow(period, ds) {
  if (period === "week") { const i = WEEKDAYS.indexOf(weekday(ds)); const from = addDays(ds, -i); return [from, addDays(from, 6)]; } // week start: monday (account setting)
  if (period === "month") { const [y, m] = ds.split("-").map(Number); return [`${y}-${String(m).padStart(2, "0")}-01`, `${y}-${String(m).padStart(2, "0")}-${monthLen(y, m)}`]; }
  const h = hijri(ds); const from = addDays(ds, -(h.d - 1)); let to = from; while (!isLastHijriDay(to)) to = addDays(to, 1); return [from, to];
}
/* The window the requirement is measured in, as of a day. */
function windowOf(g, ds) {
  const r = g.requirement;
  if (r.type === "cumulative_total") return [g.active_period.start_date, ds];
  if (r.type === "period_total") return periodWindow(r.period, ds);
  return [ds, ds];
}
/* Progress for display (rings, counter): counts in the window up to and including the day. */
function progressOf(g, ds, session) {
  const [from] = windowOf(g, ds);
  const s = session === undefined ? (g.sessions.length ? undefined : null) : session;
  return countIn(g, from, ds, s);
}
function dayMet(g, ds) {
  if (g.sessions.length) return g.sessions.every((s) => countOn(g, ds, s.id) >= thresholdValue(s.count_policy));
  return countOn(g, ds, null) >= thresholdValue(g.count_policy);
}
function streakOf(g, today) {
  const r = g.requirement;
  const running = !activeEnd(g) || today <= activeEnd(g);
  if (r.type === "period_total" || r.type === "days_per_period") {
    let n = 0, ds = today;
    for (let i = 0; i < 120; i++) {
      const [from, to] = periodWindow(r.period, ds);
      if (to < g.active_period.start_date) break;
      const due = []; for (let d = from; d <= to; d = addDays(d, 1)) if (isDue(g, d)) due.push(d);
      if (due.length) {
        const met = r.type === "period_total"
          ? countIn(g, from, to, g.sessions.length ? undefined : null) >= policyOf(g).target
          : due.filter((d) => d <= today && dayMet(g, d)).length >= Math.min(r.days, due.length);
        const current = from <= today && today <= to;
        if (met) n++; else if (!(current && running)) break;
      }
      ds = addDays(from, -1);
    }
    return { n, unit: r.period === "week" ? "week" : "month" };
  }
  let n = 0;
  for (let i = 0, ds = today; i < 1500 && ds >= g.active_period.start_date; i++, ds = addDays(ds, -1)) {
    if (!isDue(g, ds)) continue;
    if (dayMet(g, ds)) n++;
    else if (ds === today && running) continue;
    else break;
  }
  return { n, unit: "day" };
}
function completedOn(g, today) {
  if (g.completion === "when_target_reached" && g.requirement.type === "cumulative_total") {
    const target = policyOf(g).target; let sum = 0;
    const sorted = [...g.count_entries].filter((c) => c.date <= today && inActive(g, c.date)).sort((a, b) => (a.date < b.date ? -1 : 1));
    for (const c of sorted) { sum += c.count; if (sum >= target) return c.date; }
    return null;
  }
  if (g.completion === "when_duration_ended") { const e = activeEnd(g); return e && today > e ? e : null; }
  return null;
}
function nextDue(g, from) {
  const end = activeEnd(g);
  const d = findDate((x) => isDue(g, x) || (end && x > end), from, 800);
  return d && (!end || d <= end) && isDue(g, d) ? d : null;
}
/* Where a goal shows: today | upcoming | paused (Active tab) or completed | ended (History). */
function classify(g, today) {
  if (completedOn(g, today)) return "completed";
  const end = activeEnd(g);
  if (end && today > end) return "ended";
  if (pausedOn(g, today)) return "paused";
  if (isDue(g, today)) return "today";
  return nextDue(g, today) ? "upcoming" : "ended";
}

/* --- Derived text --- */
const SEASON_PRESETS = { ramadan: [9, 1, 9, 30], ramadan_last_ten: [9, 21, 9, 30], dhul_hijjah_first_ten: [12, 1, 12, 10], ashura: [1, 9, 1, 10] };
function seasonLabel(g) {
  const s = g.schedule;
  if (s.kind !== "yearly" || s.calendar !== "hijri") return null;
  const months = hMonths();
  if (s.ranges.length > 1 && s.ranges.every((r) => r.start.month === 9 && r.start.day === r.end.day)) return `${months[8]} ${lang() === "ar" ? "الليالي الوترية" : "odd nights"}`;
  const r = s.ranges[0];
  if (s.ranges.length === 1 && r.start.month === r.end.month) {
    if (r.start.day === 1 && r.end.day >= 29) return months[r.start.month - 1];
    return r.start.day === r.end.day ? `${months[r.start.month - 1]} ${r.start.day}` : `${months[r.start.month - 1]} ${r.start.day}-${r.end.day}`;
  }
  return lang() === "ar" ? "مواسم هجرية" : "Hijri seasons";
}
function chipText(g) {
  const p = displayPolicy(g), r = g.requirement, s = g.schedule;
  const T = p.target != null ? fmtN(p.target) : null, M = p.minimum != null ? fmtN(p.minimum) : null;
  let text;
  const rhythmOf = () => rhythmText({ rhythmReq: "per_due_date", schedule: s, occasion: occasionOf(s), period: "week" });
  if (g.sessions.length && r.type !== "tracker") {
    text = g.sessions.map((x) => `${fmtN(x.count_policy.target)} ${sessionLabel(x.id)}`).join(" · ");
    return s.kind === "every_day" ? text : `${text}, ${rhythmOf()}`;
  }
  if (r.type === "tracker") text = t("chip_tracker") + (s.kind === "every_day" ? "" : `, ${rhythmOf()}`);
  else if (r.type === "cumulative_total") { text = t("chip_times", T); if (activeEnd(g)) text += t("chip_by", fmtDate(activeEnd(g))); }
  else if (r.type === "period_total") text = t("chip_period_total", T, t("period")[r.period]);
  else if (r.type === "days_per_period") text = t("chip_dpp", T, r.days, t("period")[r.period]);
  else if (s.kind === "every_day") text = M ? t("chip_min_target_daily", M, T) : t("chip_daily", T);
  else {
    if (s.kind === "weekdays") {
      const days = s.weekdays.map((w) => weekdayName(w, s.weekdays.length > 2 ? "short" : "long")).join(", ");
      text = t("chip_weekdays", p.target, lang() === "en" ? days.toLowerCase() : days).replace(String(p.target), T);
    } else if (s.kind === "yearly" && s.calendar === "hijri") text = t("chip_season", seasonLabel(g), p.target).replace(String(p.target), T);
    else if (s.kind === "hijri_month_days" && String(s.days) === "13,14,15") text = t("chip_white", p.target).replace(String(p.target), T);
    else text = `${T} ${rhythmOf()}`;
    if (M) text = t("chip_min_prefix", M) + text;
  }
  if (r.type !== "tracker" && p.maximum != null) text += t("chip_cap", fmtN(p.maximum));
  return text;
}
function streakHTML(g, today) {
  const { n, unit } = streakOf(g, today);
  const glyph = v("streakGlyph") === "emoji" ? `<span aria-hidden="true">🔥</span>` : `<span class="icon i-streak" aria-hidden="true"></span>`;
  if (!n) return `<span class="streak none">${t("no_streak")}</span>`;
  return `<span class="streak">${glyph} ${esc(t("streak_unit")[unit](n))}</span>`;
}
function upcomingMeta(g, today) {
  const next = nextDue(g, today);
  if (!next) return "";
  const s = g.schedule, end = activeEnd(g);
  const nextText = s.kind === "yearly" || s.kind === "hijri_month_days" ? fmtHijri(next) : `${weekdayName(weekday(next), "short")} ${fmtDate(next)}`;
  if (v("upcomingMeta") === "next" || !end) return next > g.active_period.start_date || g.active_period.start_date <= today ? t("next_due", nextText) : t("starts", nextText);
  // Occurrences left: seasons for yearly schedules, due days for weekday schedules
  if (s.kind === "yearly") {
    const years = new Set(); for (let d = next; d <= end; d = addDays(d, 1)) if (isDue(g, d)) years.add(s.calendar === "hijri" ? hijri(d).y : d.slice(0, 4));
    return t("remaining_season", years.size, seasonLabel(g)?.split(" ")[0] || "");
  }
  let n = 0; for (let d = next; d <= end; d = addDays(d, 1)) if (isDue(g, d)) n++;
  if (s.kind === "weekdays" && s.weekdays.length === 1) return t("remaining_weekday", n, weekdayName(s.weekdays[0]));
  return t("remaining_days", n);
}
const dhikrOf = (g) => catalog.byKey[g.dhikr] || null;
function goalTitle(g) {
  if (g.name) return g.name[lang()] || g.name.en;
  const d = dhikrOf(g);
  return d ? d.title[lang()] || d.title.en : g.dhikr;
}
function goalArabic(g) { return g.custom_arabic || dhikrOf(g)?.arabic || ""; }

/* ============================================================== 6. Seed data */
const FALLBACK_DHIKRS = /* subset of contracts/dhikr-catalog/v1/catalog.json, used only if the fetch fails */ [{"key": "surah-ikhlas", "kind": "quran", "arabic": "بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ\nقُلۡ هُوَ ٱللَّهُ أَحَدٌ\nٱللَّهُ ٱلصَّمَدُ\nلَمۡ يَلِدۡ وَلَمۡ يُولَدۡ\nوَلَمۡ يَكُن لَّهُۥ كُفُوًا أَحَدُۢ", "title": {"en": "Surah Ikhlas", "ar": "سورة الإخلاص", "ml": "സൂറത് അൽ ഇഖ്ലാസ്"}, "aliases": {"en": ["Al-Ikhlas", "Qul Huwallahu Ahad", "Surah 112", "ikhlas"], "ar": ["الإخلاص", "قل هو الله أحد"], "ml": ["ഇഖ്ലാസ്"]}}, {"key": "tahleel", "kind": "dhikr", "arabic": "لَا إِلٰهَ إِلَّا ٱللَّٰهُ", "title": {"en": "Tahleel", "ar": "التهليل", "ml": "തഹ്‌ലീൽ"}, "aliases": {"en": ["Tahlil", "Lailahaillallah"], "ar": ["لا إله إلا الله"], "ml": ["ലാ ഇലാഹ ഇല്ലല്ലാഹ്"]}}, {"key": "ya-wahhabu", "kind": "dhikr", "arabic": "يَا وَهَّابُ", "title": {"en": "Ya Wahhabu", "ar": "يا وهاب", "ml": "യാ വഹ്ഹാബ്"}, "aliases": {"en": ["Ya Wahhab", "Wahhab"], "ar": ["الوهاب"], "ml": ["അൽ വഹ്ഹാബ്"]}}, {"key": "isthighfar", "kind": "dhikr", "arabic": "أَسْتَغْفِرُ ٱللَّٰهَ ٱلْعَظِيمَ", "title": {"en": "Isthighfar", "ar": "الاستغفار", "ml": "ഇസ്തിഗ്ഫാർ"}, "aliases": {"en": ["Istighfar", "Astaghfirullah", "Astaghfirullahal Azim"], "ar": ["أستغفر الله"], "ml": ["അസ്തഗ്ഫിറുല്ലാഹ്"]}}, {"key": "swalath-al-fathimiyya", "kind": "salawat", "arabic": "اللَّهُمَّ صَلِّ عَلَى النُّورِ وَأَهْلِهِ", "title": {"en": "Swalath Al Fathimiyya", "ar": "الصلاة الفاطمية", "ml": "സ്വലാത്ത് അൽ ഫാത്വിമിയ്യ"}, "aliases": {"en": ["Salawat al-Fatimiyya", "Swalath Fatimiya"]}}, {"key": "swalath", "kind": "salawat", "arabic": "صَلَّى ٱللَّٰهُ عَلَىٰ مُحَمَّدٍ، صَلَّى ٱللَّٰهُ عَلَيْهِ وَسَلَّمَ", "title": {"en": "Swalath", "ar": "الصلاة على النبي", "ml": "സ്വലാത്ത്"}, "aliases": {"en": ["Salawat", "Durood", "Sallallahu alayhi wa sallam"], "ar": ["صلى الله عليه وسلم"]}}, {"key": "swalath-al-nariyya", "kind": "salawat", "arabic": "اللَّهُمَّ صَلِّ صَلَاةً كَامِلَةً وَسَلِّمْ سَلَامًا تَامًّا عَلَىٰ سَيِّدِنَا مُحَمَّدٍ الَّذِي تَنْحَلُّ بِهِ الْعُقَدُ وَتَنْفَرِجُ بِهِ الْكُرَبُ وَتُقْضَىٰ بِهِ الْحَوَائِجُ وَتُنَالُ بِهِ الرَّغَائِبُ وَحُسْنُ الْخَوَاتِمِ وَيُسْتَسْقَى الْغَمَامُ بِوَجْهِهِ الْكَرِيمِ وَعَلَىٰ آلِهِ وَصَحْبِهِ فِي كُلِّ لَمْحَةٍ وَنَفَسٍ بِعَدَدِ كُلِّ مَعْلُومٍ لَكَ", "title": {"en": "Swalath al Nariyya", "ar": "الصلاة النارية", "ml": "സ്വലാത്തുന്നാരിയ്യ"}, "aliases": {"en": ["Salat an-Nariyya", "Salawat Nariyya", "Swalathunnariyya", "Salat Tafrijiyya"], "ar": ["الصلاة التفريجية"]}}, {"key": "ramadan-dhikr", "kind": "dua", "arabic": "أَشْهَدُ أَنْ لَا إِلٰهَ إِلَّا ٱللَّٰهُ، أَسْتَغْفِرُ ٱللَّٰهَ، أَسْأَلُكَ ٱلْجَنَّةَ وَأَعُوذُ بِكَ مِنَ ٱلنَّارِ", "title": {"en": "Ramadan Dhikr", "ar": "ذكر رمضان", "ml": "റമദാൻ ദിക്ർ"}, "aliases": {"en": ["Ramzan Dhikr"]}}, {"key": "ramadan-first-ten-nights", "kind": "dua", "arabic": "اللَّهُمَّ ٱرْحَمْنِي يَا أَرْحَمَ ٱلرَّاحِمِينَ", "title": {"en": "First 10 Nights", "ar": "العشر الأوائل من رمضان", "ml": "ആദ്യ പത്ത് രാത്രികൾ"}, "aliases": {"en": ["First Ashra", "Allahummarhamni"]}}];
/* Stand-in custom dhikrs (the user's own). Dua Kumayl isn't in the built-in catalog. */
const CUSTOM_DHIKRS = [{ key: "custom:dua-kumayl", kind: "dua", custom: true, title: { en: "Dua Kumayl", ar: "دعاء كميل", ml: "ദുആ കുമൈൽ" }, aliases: { en: ["kumail", "kumayl"] },
  arabic: "اللَّهُمَّ إِنِّي أَسْأَلُكَ بِرَحْمَتِكَ الَّتِي وَسِعَتْ كُلَّ شَيْءٍ، وَبِقُوَّتِكَ الَّتِي قَهَرْتَ بِهَا كُلَّ شَيْءٍ" }];
const catalog = { dhikrs: [...FALLBACK_DHIKRS, ...CUSTOM_DHIKRS], collections: [], byKey: {} };
function indexCatalog() { catalog.byKey = Object.fromEntries(catalog.dhikrs.map((d) => [d.key, d])); }
indexCatalog();

function uuidv7() {
  const ms = BigInt(Date.now()), r = crypto.getRandomValues(new Uint8Array(10));
  const hex = ms.toString(16).padStart(12, "0") + "7" + [...r].map((b) => b.toString(16).padStart(2, "0")).join("").slice(0, 19);
  const v = ((parseInt(hex[16], 16) & 0x3) | 0x8).toString(16);
  const h = hex.slice(0, 16) + v + hex.slice(17, 32);
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20, 32)}`;
}
const policy = (target, minimum = null, maximum = null, streak_threshold = minimum ? "minimum" : "target") => ({ minimum, target, maximum, streak_threshold });
function makeGoal(o) {
  return {
    id: uuidv7(), dhikr: o.dhikr, name: o.name || null, custom_arabic: o.custom_arabic || null, preset: o.preset || null,
    schedule: o.schedule || { kind: "every_day" },
    active_period: { start_date: o.start, end_date: o.end || null, duration_days: null },
    paused: [], count_policy: o.policy, sessions: o.sessions || [],
    requirement: o.requirement || { type: "per_due_date" }, completion: o.completion || "never",
    count_entries: [], counts: "shared", created: o.start,
  };
}
/* Fill counts so the goal has `streak` met due days before today, then a miss, then older history. */
function seedCounts(g, today, { streak, perDay, todayCount = 0, older = 0, olderDays = 0, until = today }) {
  let d = addDays(until, -1), placed = 0;
  if (until === today && todayCount) g.count_entries.push({ date: today, session: null, count: todayCount });
  while (placed < streak && d >= g.active_period.start_date) {
    if (isDue(g, d)) { g.count_entries.push({ date: d, session: null, count: typeof perDay === "function" ? perDay(placed) : perDay }); placed++; }
    d = addDays(d, -1);
  }
  d = addDays(d, -2);
  for (let i = 0; i < olderDays && d >= g.active_period.start_date; d = addDays(d, -1)) {
    if (isDue(g, d)) { g.count_entries.push({ date: d, session: null, count: Math.round(older / olderDays) }); i++; }
  }
  g.count_entries.sort((a, b) => (a.date < b.date ? -1 : 1));
  return g;
}
function seedGoals(today) {
  const goals = [];
  // Today's goals (match the approved My Goals design)
  goals.push(seedCounts(makeGoal({ dhikr: "swalath", start: addDays(today, -40), policy: policy(100) }), today, { streak: 12, perDay: 100, todayCount: 40, older: 900, olderDays: 10 }));
  goals.push(seedCounts(makeGoal({ dhikr: "swalath-al-fathimiyya", start: addDays(today, -60), policy: policy(100, 70) }), today, { streak: 15, perDay: (i) => [100, 84, 100, 72, 100][i % 5], older: 1200, olderDays: 14 }));
  goals.push(seedCounts(makeGoal({ dhikr: "isthighfar", start: addDays(today, -90), policy: policy(70000, null, null, "any_count"), requirement: { type: "cumulative_total" }, completion: "when_target_reached" }), today, { streak: 8, perDay: 1000, older: 15410, olderDays: 30 }));
  goals.push(seedCounts(makeGoal({ dhikr: "swalath-al-nariyya", start: addDays(today, -21), policy: policy(4444, null, null, "any_count"), requirement: { type: "cumulative_total" }, completion: "when_target_reached" }), today, { streak: 4, perDay: 111, older: 876, olderDays: 6 }));
  // Upcoming
  const r1448 = gregorianOfHijri(hijri(today).m <= 9 ? hijri(today).y : hijri(today).y + 1, 9, 10, today);
  goals.push(makeGoal({
    dhikr: "ramadan-first-ten-nights", name: { en: "Ramadan first 10 dhikr", ar: "ذكر العشر الأوائل من رمضان" }, start: addDays(today, -10), end: r1448,
    schedule: { kind: "yearly", calendar: "hijri", ranges: [{ start: { month: 9, day: 1 }, end: { month: 9, day: 10 } }] }, policy: policy(1),
  }));
  const thursdays = []; for (let d = addDays(today, 1); thursdays.length < 5; d = addDays(d, 1)) if (weekday(d) === "thursday") thursdays.push(d);
  goals.push(makeGoal({
    dhikr: "custom:dua-kumayl", name: { en: "Dua Kumayl", ar: "دعاء كميل" }, start: addDays(today, -3), end: thursdays[4],
    custom_arabic: "اللَّهُمَّ إِنِّي أَسْأَلُكَ بِرَحْمَتِكَ الَّتِي وَسِعَتْ كُلَّ شَيْءٍ، وَبِقُوَّتِكَ الَّتِي قَهَرْتَ بِهَا كُلَّ شَيْءٍ",
    schedule: { kind: "weekdays", weekdays: ["thursday"] }, policy: policy(10),
  }));
  // History: completed (cumulative reached), completed (duration ended), ended (no completion)
  const wahhab = makeGoal({ dhikr: "ya-wahhabu", start: addDays(today, -80), policy: policy(1000, null, null, "any_count"), requirement: { type: "cumulative_total" }, completion: "when_target_reached" });
  goals.push(seedCounts(wahhab, today, { streak: 20, perDay: 50, until: addDays(today, -47) }));
  const ramStart = gregorianOfHijri(1447, 9, 1, "2026-01-01"), ramEnd = gregorianOfHijri(1447, 9, 30, "2026-02-01") || gregorianOfHijri(1447, 9, 29, "2026-02-01");
  if (ramStart && ramEnd && ramEnd < today) {
    goals.push(seedCounts(makeGoal({ dhikr: "ramadan-dhikr", preset: "ramadan", start: ramStart, end: ramEnd, completion: "when_duration_ended",
      schedule: { kind: "yearly", calendar: "hijri", ranges: [{ start: { month: 9, day: 1 }, end: { month: 9, day: 30 } }] }, policy: policy(100) }), today, { streak: 27, perDay: 100, until: addDays(ramEnd, 1) }));
  }
  goals.push(seedCounts(makeGoal({ dhikr: "surah-ikhlas", start: addDays(today, -60), end: addDays(today, -15), policy: policy(3) }), today, { streak: 9, perDay: 3, until: addDays(today, -14), older: 60, olderDays: 20 }));
  return goals;
}

/* ============================================================== 7. State */
const STORE_KEY = "awrad-goals-proto-v2";
const state = {
  settings: { theme: "light", dir: "ltr", reducedMotion: matchMedia("(prefers-reduced-motion: reduce)").matches, today: localToday(), arabicSize: 0 },
  variants: {},
  goals: [],
  route: { name: "home" },
  stack: [],
  goalsTab: "active",
  session: null,
  draft: null,
  overlay: null,
  labTab: "controls",
};
function save() {
  localStorage.setItem(STORE_KEY, JSON.stringify({ settings: state.settings, variants: state.variants, goals: state.goals }));
}
function load() {
  if (new URLSearchParams(location.search).has("reset")) localStorage.removeItem(STORE_KEY);
  try {
    const s = JSON.parse(localStorage.getItem(STORE_KEY));
    if (s && Array.isArray(s.goals)) { Object.assign(state.settings, s.settings); state.variants = s.variants || {}; state.goals = s.goals; return; }
  } catch (e) { /* fall through to seed */ }
  state.goals = seedGoals(state.settings.today);
}
const today = () => state.settings.today;
const goalById = (id) => state.goals.find((g) => g.id === id);

/* ============================================================== 8. Components */
function ringGeometry(count, p) {
  const style = v("ringStyle");
  const target = p?.target;
  const color = style === "green" || (style === "threshold" && p?.minimum != null && count >= p.minimum) || (style === "threshold" && p?.minimum == null && count >= target)
    ? "var(--c-progress)" : "var(--proto-gold)";
  if (!target) return { arc: 0, lap: false, color, minFrac: null };
  if (count <= target || v("overflowDisplay") === "full") return { arc: Math.min(count / target, 1) * 100, lap: false, color, minFrac: p.minimum ? p.minimum / target : null };
  return { arc: Math.min((count - target) / target, 1) * 100, lap: true, color, minFrac: null };
}
function ringSVG(size, stroke, count, p, cls = "") {
  const r = (size - stroke) / 2, c = size / 2, g = ringGeometry(count, p);
  let marker = "";
  if (v("minimumMarker") === "dot" && g.minFrac != null) {
    const a = g.minFrac * 2 * Math.PI;
    marker = `<circle class="r-min" cx="${c + r * Math.cos(a)}" cy="${c + r * Math.sin(a)}" r="${Math.max(stroke * 0.32, 1.5)}" fill="var(--c-onSurface)" opacity=".55"/>`;
  }
  return `<svg class="mirror-rtl ${cls}" viewBox="0 0 ${size} ${size}" width="${size}" height="${size}" aria-hidden="true">
    <g transform="rotate(-90 ${c} ${c})">
      <circle class="r-track" cx="${c}" cy="${c}" r="${r}" fill="none" stroke="var(--c-outline)" stroke-width="${stroke}"/>
      <circle class="r-lap" cx="${c}" cy="${c}" r="${r}" fill="none" stroke="var(--c-outlineStrong)" stroke-width="${stroke}" opacity="${g.lap ? 1 : 0}"/>
      <circle class="r-arc" cx="${c}" cy="${c}" r="${r}" fill="none" stroke="${g.color}" stroke-width="${stroke}" stroke-linecap="round" pathLength="100" stroke-dasharray="${g.arc} 100" opacity="${g.arc > 0 ? 1 : 0}"/>
      ${marker}
    </g></svg>`;
}
function ring(size, stroke, count, p, label = abbr(count)) {
  return `<span class="ring ${size >= 44 ? "md" : ""}" style="width:${size}px;height:${size}px">${ringSVG(size, stroke, count, p)}<span class="ring-label ${String(label).length >= 4 ? "long" : ""}">${esc(label)}</span></span>`;
}
function goalCard(g, kind = "today", opts = {}) {
  const td = today();
  const count = kind === "upcoming" ? 0 : progressOf(g, kind === "today" || kind === "paused" ? td : (completedOn(g, td) || activeEnd(g) || td));
  const p = displayPolicy(g);
  let line2;
  if (kind === "upcoming") line2 = `<span class="meta">${esc(upcomingMeta(g, td))}</span>`;
  else if (kind === "completed") line2 = `<span class="meta">${esc(t("completed_on", fmtDate(completedOn(g, td))))}</span>`;
  else if (kind === "ended") line2 = `<span class="meta">${esc(t("ended_on", fmtDate(activeEnd(g) || td)))} · ${esc(t("counted", fmtN(countIn(g, "0000", "9999"))))}</span>`;
  else if (kind === "paused") line2 = `<span class="meta">${esc(t("paused_since", fmtDate(g.paused.find((x) => x.to == null || x.to >= td)?.from || td)))}</span>`;
  else if (opts.isNew) line2 = `<span class="streak none">${t("new_goal")}</span>`;
  else line2 = streakHTML(g, td);
  const histCount = kind === "ended" || kind === "completed" ? countIn(g, "0000", "9999") : count;
  const ringEl = ring(48, 4, kind === "completed" ? Math.max(histCount, p.target || 0) : histCount, p, abbr(histCount));
  const right = v("goalRowLayout") === "right";
  return `<div class="card on-sheet goal-card pressable ${right ? "ring-right" : ""} ${kind === "paused" ? "paused" : ""}" role="button" tabindex="0" data-action="open-goal" data-id="${g.id}">
    ${right ? "" : ringEl}
    <div class="body">
      <div class="title t-rowTitle">${esc(goalTitle(g))}</div>
      <span class="chip goal">${esc(chipText(g))}</span>
      <div class="line">${line2}</div>
    </div>
    ${right ? ringEl : ""}
    ${opts.preview ? "" : `<button class="icon-btn" data-action="goal-menu" data-id="${g.id}" aria-label="${esc(t("more_label"))}"><span class="icon i-more"></span></button>`}
  </div>`;
}
function homeRow(g, opts = {}) {
  const count = progressOf(g, today());
  return `<button class="home-row pressable" data-action="open-goal" data-id="${g.id}">
    <div class="body"><span class="title t-rowTitle">${esc(goalTitle(g))}</span>${opts.isNew ? `<span class="streak none">${t("new_goal")}</span>` : streakHTML(g, today())}</div>
    ${ring(36, 4, count, displayPolicy(g))}
  </button>`;
}
const icon = (name, extra = "") => `<span class="icon i-${name} ${extra}" aria-hidden="true"></span>`;

/* ============================================================== 9. Screens */
const TABS = ["home", "goals", "library", "community"];
const screens = {
  home() {
    const td = today();
    const due = state.goals.filter((g) => classify(g, td) === "today");
    const dateCls = v("homeDateStyle") === "title" ? "t-title" : "t-largeTitle";
    const rows = due.length ? `<div class="home-rows">${due.slice(0, 4).map((g) => homeRow(g)).join("")}</div>`
      : `<p class="t-bodySmall" style="margin:0;color:var(--c-onSurfaceVariant)">${t("nothing_today")}</p><button class="btn text" data-action="add-goal" style="margin-inline-start:-8px">${t("add_goal")}</button>`;
    const tiles = catalog.collections.map((c) => `<button class="tile pressable" data-action="toast-placeholder"><span class="t-rowTitle">${esc(c.title[lang()] || c.title.en)}</span><span class="meta">${esc(t("dhikrs_count", c.dhikrs.length))}</span><span class="arrow">${icon("forward", "mirror small")}</span></button>`).join("");
    return { cls: "with-nav", html: `
      <header class="home-head">
        <h1 class="${dateCls}" style="margin:0">${esc(fmtHijri(td, true))}</h1>
        <div class="greg t-bodySmall">${esc(fmtDate(td, { weekday: "long", day: "numeric", month: "long", year: "numeric" }))}</div>
      </header>
      <div class="home-body">
        <section class="card">
          <div class="card-head"><h2 class="t-cardTitle">${t("todays_goals")}</h2><button class="btn text" data-action="tab" data-tab="goals">${t("view_all")}</button></div>
          ${rows}
        </section>
        <section class="card prayer">
          <div class="body"><div class="t-bodySmall" style="color:var(--c-onSurfaceVariant)">${t("next_prayer")}</div><div class="t-cardTitle">${t("prayer_name")}</div></div>
          <div class="time"><div class="t-cardTitle">15:42</div><div class="t-bodySmall" style="color:var(--c-onSurfaceVariant)">${t("prayer_in")}</div></div>
        </section>
        <section>
          <h2 class="t-sectionTitle" style="margin:0 0 var(--rowGap)">${t("featured")}</h2>
          <div class="tiles">${tiles}</div>
        </section>
      </div>` };
  },

  goals() {
    const td = today(), groups = { today: [], upcoming: [], paused: [], completed: [], ended: [] };
    for (const g of state.goals) groups[classify(g, td)].push(g);
    groups.upcoming.sort((a, b) => (nextDue(a, td) < nextDue(b, td) ? -1 : 1));
    const section = (title, list, kind) => (list.length ? `<section class="section"><h2 class="t-sectionTitle section-title">${title}</h2><div class="list">${list.map((g) => goalCard(g, kind)).join("")}</div></section>` : "");
    const active = state.goalsTab === "active";
    const body = active
      ? section(t("todays_goals"), groups.today, "today") + section(t("upcoming"), groups.upcoming, "upcoming") + section(t("paused"), groups.paused, "paused") || `<p class="empty t-body">${t("no_active")}</p>`
      : section(t("completed"), groups.completed, "completed") + section(t("ended"), groups.ended, "ended") || `<p class="empty t-body">${t("no_history")}</p>`;
    return { cls: "with-nav sheet-screen", html: `
      <header class="lt-header"><h1 class="t-largeTitle" style="margin:0">${t("my_goals")}</h1>
        <button class="round-btn pressable" data-action="add-goal" aria-label="${esc(t("add_label"))}">${icon("add")}</button></header>
      <div class="seg" role="tablist">
        <div class="pill-wrap"><button class="pressable" role="tab" aria-selected="${active}" data-action="goals-tab" data-tab="active">${t("active")}</button><span class="bar"></span></div>
        <div class="pill-wrap"><button class="pressable" role="tab" aria-selected="${!active}" data-action="goals-tab" data-tab="history">${t("history")}</button><span class="bar"></span></div>
      </div>
      <div class="content-sheet">${body}</div>` };
  },

  counting() {
    const g = goalById(state.route.goalId);
    if (!g) return screens.home();
    const td = today();
    if (g.sessions.length && !g.sessions.some((s) => s.id === state.session)) state.session = currentSessionId(g);
    const session = g.sessions.length ? state.session : null;
    const p = policyOf(g, session), count = progressOf(g, td, session);
    const whole = v("tapArea") === "screen";
    const ar = goalArabic(g);
    const sessions = g.sessions.length ? sessionPills(g, session, td) : "";
    return { cls: "fixed no-nav screen-counting", html: `
      <header class="count-head">
        <button class="icon-btn pressable" data-action="back" aria-label="${esc(t("back"))}">${icon("back", "mirror")}</button>
        <div class="title">
          <h1 class="t-title">${esc(goalTitle(g))}</h1>
          <div class="line"><span class="chip goal">${esc(chipText(g))}</span><span data-slot="streak">${streakHTML(g, td)}</span></div>
        </div>
        <button class="icon-btn aa pressable" data-action="text-size" aria-label="${esc(t("text_size"))}">Aa</button>
        <button class="icon-btn pressable" data-action="goal-menu" data-id="${g.id}" data-context="counting" aria-label="${esc(t("more_label"))}">${icon("more")}</button>
      </header>
      ${sessions}
      <div class="count-body">
        ${ar ? `<div class="arabic-card" data-size="${state.settings.arabicSize}"><div class="t-quran" lang="ar">${esc(ar)}</div></div>` : ""}
        <div class="count-actions">
          <button class="btn main pressable" data-action="audio" data-slot="audio">${icon("play")}<span>${t("start_audio")}</span></button>
          <button class="btn square pressable" data-action="timer" aria-label="${esc(t("timer"))}"><span class="t-label">${t("timer")}</span></button>
          <button class="btn square pressable" data-action="count-list" aria-label="${esc(t("count_list"))}">${icon("goals")}</button>
        </div>
        <div class="counter-zone ${whole ? "whole" : ""}" ${whole ? 'data-counter="zone"' : ""}>
          <div class="counter-ring" data-slot="ring">
            ${ringSVG(264, 10, count, p)}
            <button class="counter-circle" data-counter="circle" aria-label="${esc(t("tap_circle"))}: ${count}">
              <span class="counter-num t-counter" data-slot="num"><span>${count}</span></span>
              ${v("circleSubLabel") === "target" && p.target ? `<span class="counter-sub" data-slot="sub">${esc(t("of_n", fmtN(p.target)))}</span>` : ""}
            </button>
          </div>
          <div class="hint t-bodySmall">${whole ? t("tap_anywhere") : t("tap_circle")}</div>
          <span class="chip goal" data-slot="cchip">${esc(counterChip(g, count, p, td))}</span>
        </div>
      </div>` };
  },

  create() { return renderCreate(); },
  library() {
    const c = catalog.collections[0] || { title: { en: "Dhikrs" }, dhikrs: catalog.dhikrs.slice(0, 6).map((x) => x.key) };
    const rows = c.dhikrs.map((k) => catalog.byKey[k]).filter(Boolean).map((x) => `<div class="dhikr-row lib-row">
        <div class="body"><div class="t-rowTitle">${esc(x.title[lang()] || x.title.en)}</div><div class="ar t-quranLine" lang="ar">${esc(x.arabic.split("\n")[0])}</div></div>
        <button class="btn text pressable" data-action="set-goal-from" data-dhikr="${x.key}">${t("set_goal")}</button></div>`).join("");
    return { cls: "with-nav", html: `<header class="lt-header"><h1 class="t-largeTitle" style="margin:0">${t("nav_library")}</h1></header>
      <p class="t-bodySmall" style="padding:var(--s-xs) var(--pageMargin) 0;margin:0;color:var(--c-onSurfaceVariant)">${t("library_stub")}</p>
      <section style="padding:var(--sectionGap) var(--pageMargin) 0"><h2 class="t-sectionTitle" style="margin:0 0 var(--rowGap)">${esc(c.title[lang()] || c.title.en)}</h2><div class="dhikr-list">${rows}</div></section>` };
  },
  community() { return placeholder("nav_community"); },
};
function placeholder(key) {
  return { cls: "with-nav", html: `<header class="lt-header"><h1 class="t-largeTitle" style="margin:0">${t(key)}</h1></header><p class="placeholder-body t-body">${t("placeholder")}</p>` };
}
function counterChip(g, count, p, td) {
  if (!isDue(g, td) && g.requirement.type !== "cumulative_total") return t("not_due");
  if (g.requirement.type === "tracker" || !p.target) return t("any_count");
  if (g.requirement.type === "cumulative_total") return count >= p.target ? t("target_reached") : t("to_go", fmtN(p.target - count));
  if (v("counterChip") === "minimum") return p.minimum != null ? t("minimum_n", fmtN(p.minimum)) : t("target_n", fmtN(p.target));
  if (p.maximum != null && count >= p.maximum) return t("cap_n", fmtN(p.maximum));
  if (p.minimum != null && count < p.minimum) return t("minimum_n", fmtN(p.minimum));
  if (count < p.target) return t("target_n", fmtN(p.target));
  if (count === p.target) return t("target_reached");
  return t("over_n", fmtN(count - p.target));
}

/* ============================================================== 10. Create flows
 * Three ways to create a goal, switched with VARIANTS.createFlow:
 *   A  wizard     one question per screen (CREATE_STEPS + STEP_DEFS)
 *   B  sentence   one bottom sheet: "Say [Tahleel] [100] times [every day]", each part a token
 *   C  templates  template cards, then a short pre-filled form (TEMPLATES)
 * All three edit the same draft (newDraft) and save through draftToGoal → saveDraft, so they
 * produce the same goal data. Shared pieces: dhikrList, whenOptions, morePanel, sharedQuestion,
 * previewHTML.
 */
const SESSION_IDS = ["after_fajr", "morning", "after_maghrib", "evening", "before_sleep"];
const RAMADAN_PARTS = {
  whole: { preset: "ramadan", ranges: [[9, 1, 9, 30]] },
  first10: { preset: null, ranges: [[9, 1, 9, 10]] },
  middle10: { preset: null, ranges: [[9, 11, 9, 20]] },
  last10: { preset: "ramadan_last_ten", ranges: [[9, 21, 9, 30]] },
  odd: { preset: "ramadan_odd_nights", ranges: [[9, 21, 9, 21], [9, 23, 9, 23], [9, 25, 9, 25], [9, 27, 9, 27], [9, 29, 9, 29]] },
};

/* --- The draft (shared by every flow) --- */
function newDraft(flow = v("createFlow"), prefill = {}) {
  const d = {
    flow, mode: "create", goalId: null, step: 0, dhikr: null, query: "", count: "100", when: "every_day", weekdays: [weekday(today())], ramadanPart: "whole",
    minimum: "", maximum: "", start: today(), end: "", sessions: [], streak: "auto", moreOpen: false, showJson: false, customSchedule: null,
    countsMode: "shared", picker: null, pickerField: null, template: null, ...prefill,
  };
  if (flow === "wizard" && d.dhikr) d.step = 1;
  return d;
}
function goalToDraft(g, flow = v("createFlow")) {
  const d = newDraft(flow);
  const p = policyOf(g);
  Object.assign(d, { mode: "edit", goalId: g.id, dhikr: g.dhikr, count: String(p.target ?? ""), minimum: p.minimum != null ? String(p.minimum) : "", maximum: p.maximum != null ? String(p.maximum) : "",
    start: g.active_period.start_date, end: g.active_period.end_date || "", sessions: g.sessions.map((s) => s.id), streak: p.streak_threshold, countsMode: g.counts === "dedicated" ? "dedicated" : "shared" });
  const s = g.schedule;
  if (g.requirement.type === "cumulative_total" && (s.kind === "one_time" || s.kind === "every_day")) d.when = "once";
  else if (g.requirement.type !== "per_due_date") { d.when = "custom"; d.customSchedule = s; }
  else if (s.kind === "every_day") d.when = "every_day";
  else if (s.kind === "weekdays") { d.when = "weekdays"; d.weekdays = [...s.weekdays]; }
  else if (s.kind === "hijri_month_days" && String(s.days) === "13,14,15") d.when = "white";
  else {
    const part = s.kind === "yearly" && s.calendar === "hijri" && Object.entries(RAMADAN_PARTS).find(([, x]) => JSON.stringify(x.ranges) === JSON.stringify(s.ranges.map((r) => [r.start.month, r.start.day, r.end.month, r.end.day])));
    if (part) { d.when = "ramadan"; d.ramadanPart = part[0]; } else { d.when = "custom"; d.customSchedule = s; }
  }
  d.moreOpen = !!(d.minimum || d.maximum || (d.end && d.when !== "once") || d.sessions.length);
  d.step = CREATE_STEPS().indexOf("review");
  d.template = "custom";
  return d;
}
const intOrNull = (s) => (String(s).trim() === "" ? null : /^\d+$/.test(String(s).trim()) ? parseInt(s, 10) : NaN);
function errorsOf(d) {
  const e = {}, c = intOrNull(d.count), m = intOrNull(d.minimum), x = intOrNull(d.maximum);
  if (!(c > 0)) e.count = t("err_count");
  if (d.when === "weekdays" && !d.weekdays.length) e.weekdays = t("err_weekdays");
  if (d.when !== "once" && (Number.isNaN(m) || (m != null && c > 0 && m >= c))) e.minimum = Number.isNaN(m) ? t("err_count") : t("err_min");
  if (Number.isNaN(x) || (x != null && c > 0 && x < c)) e.maximum = Number.isNaN(x) ? t("err_count") : t("err_cap");
  if (d.end && d.end < d.start) e.end = t("err_end");
  return e;
}
const draftValid = (d) => !!d.dhikr && !Object.keys(errorsOf(d)).length;
/* The draft → a goal in the contract's shape (plus prototype fields). */
function draftToGoal(d, base = null) {
  const target = intOrNull(d.count) || 1, once = d.when === "once";
  const minimum = once ? null : intOrNull(d.minimum) || null, maximum = intOrNull(d.maximum) || null;
  let schedule, preset = null;
  if (d.when === "every_day") schedule = { kind: "every_day" };
  else if (d.when === "weekdays") schedule = { kind: "weekdays", weekdays: WEEKDAYS.filter((w) => d.weekdays.includes(w)) };
  else if (d.when === "ramadan") { const part = RAMADAN_PARTS[d.ramadanPart]; preset = part.preset; schedule = { kind: "yearly", calendar: "hijri", ranges: part.ranges.map(([a, b, c, e]) => ({ start: { month: a, day: b }, end: { month: c, day: e } })) }; }
  else if (d.when === "white") { preset = "white_days"; schedule = { kind: "hijri_month_days", days: [13, 14, 15] }; }
  else if (once) schedule = { kind: "one_time" };
  else schedule = d.customSchedule || { kind: "every_day" };
  const threshold = d.streak !== "auto" ? d.streak : once ? "any_count" : minimum ? "minimum" : "target";
  const cp = { minimum, target, maximum, streak_threshold: threshold === "minimum" && !minimum ? "target" : threshold === "maximum" && !maximum ? "target" : threshold };
  const sessions = once ? [] : d.sessions.map((id) => ({ id, count_policy: { ...cp } }));
  return {
    id: base?.id || uuidv7(), dhikr: d.dhikr, name: base && base.dhikr === d.dhikr ? base.name : null, custom_arabic: base?.custom_arabic || null, preset,
    schedule,
    active_period: { start_date: d.start, end_date: d.end || null, duration_days: null },
    paused: base?.paused || [],
    count_policy: sessions.length ? { minimum: null, target: null, maximum: null, streak_threshold: "any_count" } : cp,
    sessions,
    requirement: base && d.when === "custom" ? base.requirement : { type: once ? "cumulative_total" : "per_due_date" },
    completion: once ? "when_target_reached" : d.end ? "when_duration_ended" : "never",
    counts: d.countsMode,
    count_entries: base?.count_entries || [], created: base?.created || today(),
  };
}
const dhikrName = (key) => { const x = catalog.byKey[key]; return x ? x.title[lang()] || x.title.en : key || ""; };
const siblingsOf = (d) => (d.dhikr ? state.goals.filter((g) => g.id !== d.goalId && g.dhikr === d.dhikr && !["completed", "ended"].includes(classify(g, today()))) : []);
const groupedN = (s) => (intOrNull(s) > 0 ? new Intl.NumberFormat("en-US").format(intOrNull(s)) : "?");

/* --- Shared pieces --- */
const normalise = (s) => s.toLowerCase().normalize("NFD").replace(/[ً-ٰٟۖ-ۭـ]/g, "").replace(/[̀-ͯ'’-]/g, "");
function dhikrList(d) {
  const q = normalise(d.query.trim());
  const rowHTML = (x) => `<button class="dhikr-row pressable ${d.dhikr === x.key ? "selected" : ""}" data-action="pick-dhikr" data-key="${x.key}">
      <div class="body"><div class="t-rowTitle">${esc(x.title[lang()] || x.title.en)}</div><div class="ar t-quranLine" lang="ar">${esc(x.arabic.split("\n")[0])}</div></div>
      ${d.dhikr === x.key ? icon("check") : icon("chevron", "mirror")}</button>`;
  if (q) {
    const hits = catalog.dhikrs.filter((x) => [x.key, ...Object.values(x.title), ...Object.values(x.aliases || {}).flat(), x.arabic].some((s) => normalise(String(s)).includes(q)));
    return hits.length ? `<div class="dhikr-list">${hits.slice(0, 40).map(rowHTML).join("")}</div>` : `<p class="t-body" style="color:var(--c-onSurfaceVariant)">${t("no_results")}</p>`;
  }
  const groups = [{ key: "custom", title: { en: t("your_dhikrs"), ar: t("your_dhikrs"), ml: t("your_dhikrs") }, dhikrs: CUSTOM_DHIKRS.map((x) => x.key) },
    ...(catalog.collections.length ? catalog.collections : [{ key: "all", title: { en: "All" }, dhikrs: catalog.dhikrs.map((x) => x.key) }])];
  return groups.map((c) => `<div class="dhikr-group-title t-sectionTitle">${esc(c.title[lang()] || c.title.en)}</div><div class="dhikr-list">${c.dhikrs.slice(0, c.key === "asma-ul-husna" ? 6 : 99).map((k) => catalog.byKey[k]).filter(Boolean).map(rowHTML).join("")}</div>`).join("");
}
const searchField = (d) => `<div class="search">${icon("search")}<input class="field t-input" data-input="query" placeholder="${esc(t("search_ph"))}" value="${esc(d.query)}" aria-label="${esc(t("search_ph"))}">
  ${d.query ? `<button class="icon-btn" data-action="clear-query" aria-label="${esc(t("close"))}">${icon("close")}</button>` : ""}</div>
  <div data-slot="dhikr-list">${dhikrList(d)}</div>`;
function optionRow(id, label, sub, on, action, extra = "") {
  return `<div><button class="option-row pressable" role="radio" aria-checked="${on}" data-action="${action}" data-val="${id}">
    <div class="body"><div class="t-rowTitle">${esc(label)}</div>${sub ? `<div class="sub">${esc(sub)}</div>` : ""}</div>
    <span class="tick">${icon("check")}</span></button>${on && extra ? `<div class="option-extra">${extra}</div>` : ""}</div>`;
}
const weekdayChips = (d) => `<div class="chip-row">${WEEKDAYS.map((w) => `<button class="filter-chip" aria-pressed="${d.weekdays.includes(w)}" data-action="toggle-weekday" data-wd="${w}">${d.weekdays.includes(w) ? icon("check", "small") : ""}${esc(weekdayName(w, "short"))}</button>`).join("")}</div>
    <div class="field-msg error" data-err="weekdays">${errorsOf(d).weekdays || ""}</div>`;
const ramadanChips = (d) => `<div class="chip-row">${Object.keys(RAMADAN_PARTS).map((k) => `<button class="filter-chip" aria-pressed="${d.ramadanPart === k}" data-action="ramadan-part" data-part="${k}">${t("ramadan_" + k)}</button>`).join("")}</div>`;
function whenOptions(d) {
  const row = (id, label, sub, extra) => optionRow(id, label, sub, d.when === id, "pick-when", extra);
  return `<div class="options" role="radiogroup">
      ${row("every_day", t("when_every_day"), "")}
      ${row("weekdays", t("when_weekdays"), "", weekdayChips(d))}
      ${row("ramadan", t("when_ramadan"), "", ramadanChips(d))}
      ${row("white", t("when_white"), t("when_white_sub"))}
      ${row("once", t("when_once"), t("when_once_sub"))}
      ${d.when === "custom" ? row("custom", t("when_custom"), t("when_custom_sub")) : ""}
    </div>`;
}
function field(d, key, label, help, type = "number") {
  const e = errorsOf(d)[key];
  return `<div class="field-group"><label class="field-label t-label" for="f-${key}">${label}</label>
      <input id="f-${key}" class="field t-input ${e ? "error" : ""}" type="${type === "number" ? "text" : type}" ${type === "number" ? 'inputmode="numeric" placeholder="–"' : ""} data-input="${key}" value="${esc(d[key])}">
      <div class="field-msg ${e ? "error" : ""}" data-err="${key}" data-help="${esc(help || "")}">${e || help || ""}</div></div>`;
}
function morePanel(d, { skipEnd = false } = {}) {
  const once = d.when === "once";
  const streakOpts = ["auto", "any_count", "minimum", "target", "maximum"].map((k) => `<button class="filter-chip" aria-pressed="${d.streak === k}" data-action="streak-opt" data-opt="${k}">${t("streak_opt")[k]}</button>`).join("");
  return `<div class="more-panel">
      <div class="field-pair">${once ? "" : field(d, "minimum", t("f_minimum"), t("f_minimum_help"))}${field(d, "maximum", t("f_cap"), t("f_cap_help"))}</div>
      <div class="field-pair">${field(d, "start", t("f_start"), "", "date")}${skipEnd ? "" : field(d, "end", t("f_end"), t("f_end_help"), "date")}</div>
      ${once ? "" : `<div class="field-group"><div class="field-label t-label">${t("f_sessions")}</div>
        <div class="chip-row">${SESSION_IDS.map((s) => `<button class="filter-chip" aria-pressed="${d.sessions.includes(s)}" data-action="toggle-session" data-session="${s}">${d.sessions.includes(s) ? icon("check", "small") : ""}${t("session_names")[s]}</button>`).join("")}</div>
        <div class="field-msg">${t("f_sessions_help")}</div></div>`}
      <div class="field-group"><div class="field-label t-label">${t("f_streak")}</div><div class="chip-row">${streakOpts}</div></div>
    </div>`;
}
/* The agreed "shared counts" question (decision C): shown when another live goal uses the same dhikr. */
function sharedQuestion(d) {
  if (!siblingsOf(d).length) return "";
  const row = (id, label, sub) => optionRow(id, label, sub, d.countsMode === id, "counts-mode");
  return `<div class="shared-q"><div class="t-rowTitle">${esc(t("shared_q", dhikrName(d.dhikr)))}</div>
    <div class="options" role="radiogroup">${row("shared", t("shared_yes"), t("shared_yes_sub"))}${row("dedicated", t("shared_no"), t("shared_no_sub"))}</div></div>`;
}
function previewHTML(d) {
  const g = draftToGoal(d, d.goalId ? goalById(d.goalId) : null);
  if (!d.dhikr) g.name = { en: t("tok_pick_dhikr"), ar: t("tok_pick_dhikr") };
  return goalCard(g, "today", { preview: true, isNew: d.mode === "create" });
}
const saveLabel = (d) => (d.mode === "edit" ? t("save_changes") : t("add_goal_btn"));

/* --- A. Wizard --- */
const STEP_DEFS = {
  dhikr: {
    title: () => t("step_dhikr"), lede: () => t("step_dhikr_lede"),
    body: (d) => searchField(d),
    valid: (d) => !!d.dhikr,
  },
  count: {
    title: () => t("step_count"), lede: (d) => (d.when === "once" ? t("step_count_total") : t("step_count_daily")),
    body: (d) => `<input class="big-number" inputmode="numeric" data-input="count" value="${esc(d.count)}" aria-label="${esc(t("step_count"))}">
      <div class="field-msg error" data-err="count"></div>
      <div class="chip-row" style="margin-top:var(--s-lg);justify-content:center">${quickCounts(d).map((n) => `<button class="filter-chip" aria-pressed="${String(n) === d.count}" data-action="quick-count" data-n="${n}">${fmtN(n)}</button>`).join("")}</div>`,
    valid: (d) => !errorsOf(d).count,
  },
  when: {
    title: () => t("step_when"), lede: () => t("step_when_lede"),
    body: (d) => whenOptions(d),
    valid: (d) => !errorsOf(d).weekdays,
  },
  more: {
    title: () => t("step_more"), lede: () => t("step_more_lede"), skippable: true,
    body: (d) => morePanel(d),
    valid: (d) => { const e = errorsOf(d); return !e.minimum && !e.maximum && !e.end; },
  },
  review: {
    title: () => t("step_review"), lede: () => t("step_review_lede"),
    body: (d) => reviewBody(d), valid: (d) => draftValid(d),
  },
};
const CREATE_STEPS = () => (v("createOrder") === "whenFirst" ? ["dhikr", "when", "count", "more", "review"] : ["dhikr", "count", "when", "more", "review"]);
const quickCounts = (d) => (d.when === "once" ? [1000, 4444, 10000, 70000] : [33, 100, 313, 1000]);
function reviewBody(d) {
  const g = draftToGoal(d, d.goalId ? goalById(d.goalId) : null);
  const p = policyOf(g);
  const scheduleText = { every_day: t("when_every_day"), weekdays: t("when_weekdays"), yearly: seasonLabel(g) || "yearly", hijri_month_days: t("when_white"), one_time: t("when_once") }[g.schedule.kind] || g.schedule.kind;
  const row = (k, val) => `<div class="row t-body"><span class="k">${k}</span><span class="v">${esc(val)}</span></div>`;
  return `<div class="review-preview">
      <div class="label t-label">${t("preview_goals")}</div>
      ${previewHTML(d)}
      <div class="label t-label">${t("preview_home")}</div>
      ${homeRow(g, { preview: true, isNew: d.mode === "create" })}
    </div>
    ${sharedQuestion(d)}
    <div class="summary" style="margin-top:var(--sectionGap)">
      ${row(t("s_dhikr"), dhikrName(g.dhikr))}
      ${row(t("s_chip"), chipText(g))}
      ${row(t("s_when"), scheduleText + (g.preset ? ` (${g.preset})` : ""))}
      ${row(t("s_req"), t("req")[g.requirement.type])}
      ${row(t("s_policy"), [p.minimum != null ? `min ${p.minimum}` : null, `target ${p.target}`, p.maximum != null ? `cap ${p.maximum}` : null].filter(Boolean).join(" · "))}
      ${row(t("s_streak"), t("streak_opt")[p.streak_threshold])}
      ${g.sessions.length ? row(t("s_sessions"), g.sessions.map((s) => t("session_names")[s.id]).join(", ")) : ""}
      ${row(t("s_active"), t("from_to", fmtDate(g.active_period.start_date), g.active_period.end_date && fmtDate(g.active_period.end_date)))}
      ${row(t("s_completion"), t("completion")[g.completion])}
    </div>
    <div class="json-peek"><button class="btn text" data-action="toggle-json" style="margin-inline-start:-8px">${t("show_json")}</button>
      ${d.showJson ? `<pre>${esc(JSON.stringify((({ count_entries, ...rest }) => rest)(g), null, 2))}</pre>` : ""}</div>`;
}
function renderWizard() {
  const d = state.draft, steps = CREATE_STEPS(), id = steps[d.step], def = STEP_DEFS[id];
  const last = d.step === steps.length - 1;
  return { cls: "fixed no-nav", html: `
    <header class="topbar">
      <button class="icon-btn pressable" data-action="create-back" aria-label="${esc(d.step === 0 ? t("close") : t("back"))}">${d.step === 0 ? icon("close") : icon("back", "mirror")}</button>
      <div class="steps" role="img" aria-label="Step ${d.step + 1} of ${steps.length}">${steps.map((_, i) => `<i class="${i <= d.step ? "on" : ""}"></i>`).join("")}</div>
      ${def.skippable ? `<button class="btn text" data-action="wizard-skip">${t("skip")}</button>` : `<span style="width:var(--touchTarget)"></span>`}
    </header>
    <div class="create-body" data-step="${id}">
      <h1 class="t-title">${esc(def.title(d))}</h1>
      <p class="lede t-bodySmall">${esc(def.lede(d))}</p>
      ${def.body(d)}
    </div>
    <footer class="create-foot"><button class="btn main pressable" data-action="create-next" data-validate ${def.valid(d) ? "" : "disabled"}>${last ? saveLabel(d) : t("continue")}</button></footer>` };
}

/* --- B. Editable sentence (a bottom sheet) ---
 * B covers the whole goal language, so it has its own richer draft (sdNew) rather than the A/C draft:
 * every schedule kind, every requirement, sessions with timings, the active period, the finish rule,
 * the streak, a name and shared counts. sdToGoal turns it into the same goal shape A and C produce.
 *
 *   main sentence   verb · [dhikr] · [amount] · [rhythm]       the amount and rhythm choose the requirement
 *   details         optional clauses under it, each removable  "at least [70]", "[100] after [Fajr] and …"
 *   read-back       the whole goal as one plain sentence
 *
 * All wording comes from SENTENCE_L10N: one template set per language with slots, so each language
 * orders its clauses itself (Malayalam puts the verb last). Pickers open as a second level inside
 * the sheet, so the sheet keeps one height.
 */
const PRAYERS = ["fajr", "dhuhr", "asr", "maghrib", "isha"];
const OCCASIONS = {
  ramadan_whole: { preset: "ramadan", ranges: [[9, 1, 9, 30]] },
  ramadan_first10: { preset: null, ranges: [[9, 1, 9, 10]] },
  ramadan_middle10: { preset: null, ranges: [[9, 11, 9, 20]] },
  ramadan_last10: { preset: "ramadan_last_ten", ranges: [[9, 21, 9, 30]] },
  ramadan_odd: { preset: "ramadan_odd_nights", ranges: [[9, 21, 9, 21], [9, 23, 9, 23], [9, 25, 9, 25], [9, 27, 9, 27], [9, 29, 9, 29]] },
  shawwal_six: { preset: "shawwal_six_days", ranges: [[10, 2, 10, 30]], req: { rhythmReq: "days_per_period", period: "hijri_month", days: "6" } },
  dhul_hijjah_first10: { preset: "dhul_hijjah_first_ten", ranges: [[12, 1, 12, 10]] },
  arafah: { preset: "day_of_arafah", ranges: [[12, 9, 12, 9]] },
  ashura: { preset: "ashura", ranges: [[1, 9, 1, 10]] },
};
const hijriRanges = (rs) => ({ kind: "yearly", calendar: "hijri", ranges: rs.map(([a, b, c, e]) => ({ start: { month: a, day: b }, end: { month: c, day: e } })) });
function occasionOf(s) {
  if (s.kind !== "yearly" || s.calendar !== "hijri") return null;
  const key = JSON.stringify(s.ranges.map((r) => [r.start.month, r.start.day, r.end.month, r.end.day]));
  return Object.keys(OCCASIONS).find((k) => JSON.stringify(OCCASIONS[k].ranges) === key) || null;
}
const gN = (n) => new Intl.NumberFormat("en-US").format(n);
const verbKind = (key) => ({ dua: "read", quran: "recite" }[catalog.byKey[key]?.kind] || "say");

/* Sessions. The goal-model session is { id, count_policy }, so the timing lives in the id. */
const sessionBaseId = (s) => (s.kind === "prayer" ? `after_${s.prayer}` : s.kind === "time" ? `at_${(s.time || "00:00").replace(":", "")}` : s.kind === "between" ? `between_${(s.from || "00:00").replace(":", "")}_${(s.to || "00:00").replace(":", "")}` : s.kind === "named" ? s.id : "anytime");
function parseSession(id) {
  let m;
  if ((m = id.match(/^after_(fajr|dhuhr|asr|maghrib|isha)(?:_\d+)?$/))) return { kind: "prayer", prayer: m[1] };
  if ((m = id.match(/^at_(\d\d)(\d\d)/))) return { kind: "time", time: `${m[1]}:${m[2]}` };
  if ((m = id.match(/^between_(\d\d)(\d\d)_(\d\d)(\d\d)/))) return { kind: "between", from: `${m[1]}:${m[2]}`, to: `${m[3]}:${m[4]}` };
  if (id.startsWith("anytime")) return { kind: "anytime" };
  return { kind: "named", id };
}
function dedupeIds(list) {
  const seen = {};
  return list.map((s) => { let id = sessionBaseId(s); seen[id] = (seen[id] || 0) + 1; if (seen[id] > 1) id += "_" + seen[id]; return { id, s }; });
}
function sessionWhenText(s, L = SL()) {
  if (s.kind === "prayer") return L.sessWhen.prayer(L.prayers[s.prayer]);
  if (s.kind === "time") return L.sessWhen.time(s.time);
  if (s.kind === "between") return L.sessWhen.between(s.from, s.to);
  if (s.kind === "anytime") return L.sessWhen.anytime;
  return t("session_names")[s.id] || s.id;
}
function sessionLabel(id, short = false) {
  const s = parseSession(id), L = SL();
  if (!short) return sessionWhenText(s, L);
  if (s.kind === "prayer") return L.prayers[s.prayer];
  if (s.kind === "time") return s.time;
  if (s.kind === "between") return `${s.from}–${s.to}`;
  if (s.kind === "anytime") return L.anytimeShort;
  return t("session_names")[id] || id;
}

/* --- Wording: one template set per language --- */
const SENTENCE_L10N = {
  en: {
    verb: { say: "Say", read: "Read", recite: "Recite" },
    amount: (n, g) => (n === 1 ? "once" : `${g} times`), anyCount: "whenever I can", pickAmount: "how many?", pickDhikr: "pick a dhikr",
    main: ({ req, verb, dhikr, amount, rhythm, days, sessions }) =>
      sessions ? `${verb} ${dhikr} ${rhythm}` : req === "days_per_period" ? `${verb} ${dhikr} ${amount} a day, on ${days} days ${rhythm}` : `${verb} ${dhikr} ${amount} ${rhythm}`,
    period: { week: "a week", month: "a month", hijri_month: "a Hijri month" },
    and: (xs) => (xs.length < 2 ? xs.join("") : `${xs.slice(0, -1).join(", ")} and ${xs.at(-1)}`),
    ord: (n) => n + (n % 10 === 1 && n % 100 !== 11 ? "st" : n % 10 === 2 && n % 100 !== 12 ? "nd" : n % 10 === 3 && n % 100 !== 13 ? "rd" : "th"),
    weekdayPlural: (name) => name + "s",
    rhythm: {
      every_day: "every day", one_time: "every day until it's done",
      weekdays1: (day) => `every ${day}`, weekdays: (days) => `on ${days}`,
      every_n: (n, from) => (n === 1 ? "every day" : `every ${n} days`) + (from ? ` from ${from}` : ""),
      month_days: (days) => `on the ${days} of every month`,
      white: "on the white days", hijri_days: (days) => `on ${days} of every Hijri month`,
      dates: (dates) => `on ${dates}`, yearly_on: (x) => `every year on ${x}`, yearly_range: (a, b) => `every year from ${a} to ${b}`,
      total: "in total", shawwal_six: "of every Shawwal",
      occasions: {
        ramadan_whole: "every day of Ramadan", ramadan_first10: "in the first 10 days of every Ramadan", ramadan_middle10: "in the middle 10 days of every Ramadan",
        ramadan_last10: "in the last 10 nights of every Ramadan", ramadan_odd: "on the odd nights of every Ramadan's last 10",
        dhul_hijjah_first10: "in the first 10 days of every Dhul Hijjah", arafah: "on every Day of Arafah", ashura: "on every Ashura (9–10 Muharram)",
      },
    },
    prayers: { fajr: "Fajr", dhuhr: "Dhuhr", asr: "Asr", maghrib: "Maghrib", isha: "Isha" }, anytimeShort: "Anytime",
    sessWhen: { anytime: "at any time", prayer: (p) => `after ${p}`, time: (x) => `at ${x}`, between: (a, b) => `between ${a} and ${b}` },
    session: (amount, when) => `${amount} ${when}`,
    min: (v) => `at least ${v}`, cap: (v) => `stop at ${v}`,
    periodClause: (start, end) => `${start} ${end}`, from: (v) => `from ${v}`, until: (v) => `until ${v}`, by: (v) => `by ${v}`, forDays: (v) => `for ${v}`, daysN: (n) => `${n} days`, open: "until I stop", today: "today",
    finishReach: "finish when I reach it", finishUntilWord: "keep going until", finishUntil: (w, dt) => `${w} ${dt}`,
    streak: (v) => `my streak counts at ${v}`, streakVals: { minimum: "the minimum", target: "the target", any_count: "any count", maximum: "the cap" },
    name: (v) => `call it ${v}`, quote: (v) => `“${v}”`,
    shared: (dh) => `count ${dh} from my other goal too`,
    readback: ({ main, sessions, clauses, streak, name, shared, dhikr }) => {
      let s = main.charAt(0).toUpperCase() + main.slice(1);
      if (sessions) s += `: ${sessions}`;
      if (clauses.length) s += `, ${clauses.join(", ")}`;
      s += `. Your streak counts at ${streak}.`;
      if (name) s += ` It's called ${name}.`;
      if (shared === true) s += ` Counts are shared with your other ${dhikr} goal.`;
      if (shared === false) s += ` It keeps its own count, apart from your other ${dhikr} goal.`;
      return s;
    },
    examples: ["100 Swalath daily, at least 70", "Istighfar after Fajr and Maghrib", "Tahleel 70,000 by 30 Dec", "Ya Latif 129 for 40 days", "Swalath 1,000 a week",
      "Swalath on 5 days a week", "Ikhlas on the white days", "Dua Kumayl every Thursday", "Istighfar, last 10 of Ramadan"],
  },
  ar: {
    verb: { say: "قل", read: "اقرأ", recite: "اتلُ" },
    amount: (n, g) => (n === 1 ? "مرة واحدة" : `${g} مرة`), anyCount: "كلما استطعت", pickAmount: "كم مرة؟", pickDhikr: "اختر ذكرًا",
    main: ({ req, verb, dhikr, amount, rhythm, days, sessions }) =>
      sessions ? `${verb} ${dhikr} ${rhythm}` : req === "days_per_period" ? `${verb} ${dhikr} ${amount} في اليوم، في ${days} أيام ${rhythm}` : `${verb} ${dhikr} ${amount} ${rhythm}`,
    period: { week: "في الأسبوع", month: "في الشهر", hijri_month: "في الشهر الهجري" },
    and: (xs) => xs.join(" و"),
    ord: (n) => String(n), weekdayPlural: (name) => name,
    rhythm: {
      every_day: "كل يوم", one_time: "كل يوم حتى يكتمل",
      weekdays1: (day) => `كل ${day}`, weekdays: (days) => `أيام ${days}`,
      every_n: (n, from) => (n === 1 ? "كل يوم" : `كل ${n} أيام`) + (from ? ` بدءًا من ${from}` : ""),
      month_days: (days) => `في اليوم ${days} من كل شهر`,
      white: "في الأيام البيض", hijri_days: (days) => `في ${days} من كل شهر هجري`,
      dates: (dates) => `في ${dates}`, yearly_on: (x) => `كل سنة في ${x}`, yearly_range: (a, b) => `كل سنة من ${a} إلى ${b}`,
      total: "إجمالًا", shawwal_six: "من كل شوال",
      occasions: {
        ramadan_whole: "كل يوم من رمضان", ramadan_first10: "في العشر الأوائل من كل رمضان", ramadan_middle10: "في العشر الأواسط من كل رمضان",
        ramadan_last10: "في العشر الأواخر من كل رمضان", ramadan_odd: "في ليالي الوتر من العشر الأواخر",
        dhul_hijjah_first10: "في العشر الأوائل من كل ذي الحجة", arafah: "في كل يوم عرفة", ashura: "في كل عاشوراء (٩–١٠ محرم)",
      },
    },
    prayers: { fajr: "الفجر", dhuhr: "الظهر", asr: "العصر", maghrib: "المغرب", isha: "العشاء" }, anytimeShort: "أي وقت",
    sessWhen: { anytime: "في أي وقت", prayer: (p) => `بعد ${p}`, time: (x) => `عند ${x}`, between: (a, b) => `بين ${a} و${b}` },
    session: (amount, when) => `${amount} ${when}`,
    min: (v) => `على الأقل ${v}`, cap: (v) => `توقف عند ${v}`,
    periodClause: (start, end) => `${start} ${end}`, from: (v) => `من ${v}`, until: (v) => `حتى ${v}`, by: (v) => `قبل ${v}`, forDays: (v) => `لمدة ${v}`, daysN: (n) => `${n} يومًا`, open: "حتى أتوقف", today: "اليوم",
    finishReach: "أنهِه عند بلوغه", finishUntilWord: "استمر حتى", finishUntil: (w, dt) => `${w} ${dt}`,
    streak: (v) => `تُحسب سلسلتي عند ${v}`, streakVals: { minimum: "الحد الأدنى", target: "الهدف", any_count: "أي عدد", maximum: "الحد الأقصى" },
    name: (v) => `سمِّه ${v}`, quote: (v) => `«${v}»`,
    shared: (dh) => `احسب ${dh} من هدفي الآخر أيضًا`,
    readback: ({ main, sessions, clauses, streak, name, shared, dhikr }) => {
      let s = main;
      if (sessions) s += `: ${sessions}`;
      if (clauses.length) s += `، ${clauses.join("، ")}`;
      s += `. تُحسب سلسلتك عند ${streak}.`;
      if (name) s += ` اسمه ${name}.`;
      if (shared === true) s += ` يُشارك العدّ مع هدفك الآخر لـ${dhikr}.`;
      if (shared === false) s += ` له عدّه الخاص بعيدًا عن هدفك الآخر لـ${dhikr}.`;
      return s;
    },
    examples: ["١٠٠ صلاة يوميًا، ٧٠ على الأقل", "استغفار بعد الفجر والمغرب", "تهليل ٧٠٬٠٠٠ قبل ٣٠ ديسمبر", "يا لطيف ١٢٩ لمدة ٤٠ يومًا", "صلاة ١٬٠٠٠ في الأسبوع",
      "صلاة في ٥ أيام أسبوعيًا", "الإخلاص في الأيام البيض", "دعاء كميل كل خميس", "استغفار في العشر الأواخر"],
  },
  ml: {
    verb: { say: "ചൊല്ലുക", read: "ചൊല്ലുക", recite: "ഓതുക" },
    amount: (n, g) => (n === 1 ? "ഒരു തവണ" : `${g} തവണ`), anyCount: "കഴിയുമ്പോഴെല്ലാം", pickAmount: "എത്ര തവണ?", pickDhikr: "ദിക്ർ തിരഞ്ഞെടുക്കുക",
    // Malayalam is verb-final: [dhikr] [rhythm] [amount] verb
    main: ({ req, verb, dhikr, amount, rhythm, days, sessions }) =>
      sessions ? `${dhikr} ${rhythm} ${verb}` : req === "days_per_period" ? `${dhikr} ${rhythm} ${days} ദിവസം, ദിവസവും ${amount} ${verb}` : `${dhikr} ${rhythm} ${amount} ${verb}`,
    period: { week: "ആഴ്ചയിൽ", month: "മാസത്തിൽ", hijri_month: "ഹിജ്റ മാസത്തിൽ" },
    and: (xs) => xs.join(", "),
    ord: (n) => String(n), weekdayPlural: (name) => name,
    rhythm: {
      every_day: "എല്ലാ ദിവസവും", one_time: "പൂർത്തിയാകും വരെ ദിവസവും",
      weekdays1: (day) => `എല്ലാ ആഴ്ചയും ${day}`, weekdays: (days) => `എല്ലാ ആഴ്ചയും ${days}`,
      every_n: (n, from) => (n === 1 ? "എല്ലാ ദിവസവും" : `${n} ദിവസം കൂടുമ്പോൾ`) + (from ? ` (${from} മുതൽ)` : ""),
      month_days: (days) => `എല്ലാ മാസവും ${days} തീയതികളിൽ`,
      white: "അയ്യാമുൽ ബീളിൽ", hijri_days: (days) => `എല്ലാ ഹിജ്റ മാസവും ${days} തീയതികളിൽ`,
      dates: (dates) => `${dates} തീയതികളിൽ`, yearly_on: (x) => `എല്ലാ വർഷവും ${x}ന്`, yearly_range: (a, b) => `എല്ലാ വർഷവും ${a} മുതൽ ${b} വരെ`,
      total: "ആകെ", shawwal_six: "എല്ലാ ശവ്വാലിലും",
      occasions: {
        ramadan_whole: "റമദാനിലെ എല്ലാ ദിവസവും", ramadan_first10: "എല്ലാ റമദാനിലെയും ആദ്യ പത്തിൽ", ramadan_middle10: "എല്ലാ റമദാനിലെയും നടുവിലെ പത്തിൽ",
        ramadan_last10: "എല്ലാ റമദാനിലെയും അവസാന പത്തിൽ", ramadan_odd: "റമദാനിലെ അവസാന പത്തിലെ ഒറ്റ രാവുകളിൽ",
        dhul_hijjah_first10: "എല്ലാ ദുൽഹിജ്ജയിലെയും ആദ്യ പത്തിൽ", arafah: "എല്ലാ അറഫാ ദിനത്തിലും", ashura: "എല്ലാ ആശൂറാഇലും (മുഹർറം 9–10)",
      },
    },
    prayers: { fajr: "സുബ്ഹ്", dhuhr: "ളുഹ്ർ", asr: "അസ്ർ", maghrib: "മഗ്‌രിബ്", isha: "ഇശാ" }, anytimeShort: "ഏത് സമയവും",
    sessWhen: { anytime: "ഏത് സമയത്തും", prayer: (p) => `${p}ന് ശേഷം`, time: (x) => `${x}ന്`, between: (a, b) => `${a}നും ${b}നും ഇടയിൽ` },
    session: (amount, when) => `${when} ${amount}`,
    min: (v) => `കുറഞ്ഞത് ${v}`, cap: (v) => `${v}ൽ നിർത്തുക`,
    periodClause: (start, end) => `${start} ${end}`, from: (v) => `${v} മുതൽ`, until: (v) => `${v} വരെ`, by: (v) => `${v}നകം`, forDays: (v) => v, daysN: (n) => `${n} ദിവസത്തേക്ക്`, open: "ഞാൻ നിർത്തുന്നത് വരെ", today: "ഇന്ന്",
    finishReach: "എത്തുമ്പോൾ പൂർത്തിയാക്കുക", finishUntilWord: "തുടരുക", finishUntil: (w, dt) => `${dt} വരെ ${w}`,
    streak: (v) => `സ്ട്രീക്ക് ${v} എത്തുമ്പോൾ എണ്ണുക`, streakVals: { minimum: "കുറഞ്ഞത്", target: "ലക്ഷ്യം", any_count: "ഏത് എണ്ണവും", maximum: "പരമാവധി" },
    name: (v) => `പേര് ${v}`, quote: (v) => `“${v}”`,
    shared: (dh) => `മറ്റേ ലക്ഷ്യത്തിലെ ${dh} എണ്ണവും കൂട്ടുക`,
    // Clauses lead and the main sentence (with its verb) closes the read-back.
    readback: ({ main, sessions, clauses, streak, name, shared, dhikr }) => {
      let s = clauses.length ? clauses.join(", ") + ", " : "";
      s += main + (sessions ? ` (${sessions})` : "") + `. സ്ട്രീക്ക്: ${streak}.`;
      if (name) s += ` പേര്: ${name}.`;
      if (shared === true) s += ` മറ്റേ ${dhikr} ലക്ഷ്യവുമായി എണ്ണം പങ്കിടുന്നു.`;
      if (shared === false) s += ` ഇതിന് സ്വന്തം എണ്ണം.`;
      return s;
    },
    examples: ["സ്വലാത്ത് ദിവസം 100, കുറഞ്ഞത് 70", "സുബ്ഹിനും മഗ്‌രിബിനും ശേഷം ഇസ്തിഗ്ഫാർ", "തഹ്‌ലീൽ 70,000, ഡിസം 30നകം", "യാ ലത്വീഫ് 129, 40 ദിവസം", "സ്വലാത്ത് ആഴ്ചയിൽ 1,000",
      "ആഴ്ചയിൽ 5 ദിവസം സ്വലാത്ത്", "അയ്യാമുൽ ബീളിൽ ഇഖ്‌ലാസ്", "എല്ലാ വ്യാഴാഴ്ചയും ദുആ കുമൈൽ", "റമദാൻ അവസാന പത്തിൽ ഇസ്തിഗ്ഫാർ"],
  },
};
const SL = () => SENTENCE_L10N[lang()] || SENTENCE_L10N.en;

/* Sheet chrome strings (en, ar, ml), merged into STRINGS. */
const SHEET_STRINGS = {
  en: {
    s_add_detail: "Add detail", s_remove: "Remove", s_examples: "Examples", s_add_session_short: "session",
    pad_delete: "Delete", p_amount: "How many?", p_days: "On how many days?", p_min: "At least", p_cap: "Stop at", p_session_amount: "How many in this session?",
    p_rhythm: "How often?", p_session: "When in the day?", p_start: "Starts", p_end: "Ends", p_finish: "Finishes", p_streak: "Streak counts at", p_name: "Name", p_shared: "Shared counts",
    s_once: "Once", s_anycount: "Whenever I can", s_anycount_sub: "No number: any count is progress",
    g_repeat: "Repeat", g_occasions: "Occasions", g_totals: "Totals",
    r_every_day: "Every day", r_weekdays: "On chosen weekdays", r_every_n: "Every few days", r_month_days: "Days of the month", r_hijri_days: "Days of every Hijri month", r_dates: "Specific dates", r_yearly: "Every year",
    o_ramadan_whole: "Ramadan, every day", o_ramadan_first10: "Ramadan, first 10", o_ramadan_middle10: "Ramadan, middle 10", o_ramadan_last10: "Ramadan, last 10 nights", o_ramadan_odd: "Ramadan, odd nights of the last 10",
    o_shawwal_six: "Six days of Shawwal", o_dhul_hijjah_first10: "First 10 of Dhul Hijjah", o_arafah: "Day of Arafah", o_ashura: "Ashura (9–10 Muharram)",
    tt_period_week: "A total each week", tt_period_month: "A total each month", tt_period_hijri_month: "A total each Hijri month",
    tt_dpp_week: "On some days each week", tt_dpp_month: "On some days each month", tt_dpp_hijri_month: "On some days each Hijri month", tt_total: "One total",
    every_lbl: "Every", days_lbl: "days", from_lbl: "starting", white_btn: "White days (13–15)", add_btn: "Add", range_lbl: "A range of days", cal_greg: "Gregorian", cal_hijri: "Hijri", from_day: "From", to_day: "To",
    k_anytime: "Anytime", k_prayer: "After a prayer", k_time: "At a time", k_between: "Between two times", remove_session: "Remove this session",
    e_until: "Until a date", e_for: "For a number of days", e_open: "Until I stop",
    fr_reach: "Finish when I reach it", fr_until: "Keep going until a date", sh_share: "Share counts", sh_separate: "Count separately",
    d_minimum: "At least…", d_cap: "Stop at…", d_sessions: "Split into sessions", d_period: "Start and end", d_finish: "When it finishes", d_streak: "What the streak counts", d_name: "Give it a name", d_shared: "Share counts with my other goal",
    d_remind: "Remind me…", coming_soon: "Coming soon",
    err_amount: "Add a number", err_days: (max) => `Pick 1 to ${max} days`, err_wd: "Pick at least one day", err_dates: "Add at least one date", err_every: "Pick 1 to 366 days", err_yearly: "Pick a real date",
    err_min: "More than the target", err_cap: "Less than the target", err_sessions: "Each session needs a number", err_sess_dup: "Two sessions at the same time",
    err_end: "Ends before it starts", err_need_end: "Pick an end date", err_for: "Add a number of days", err_streak_min: "No minimum is set", err_streak_target: "No target is set", err_streak_cap: "No cap is set", err_name: "Add a name or remove this",
    chip_dpp: (t, d, p) => `${t} a day, ${d} days a ${p}`, your_dhikrs: "Your dhikrs",
    sessions_done: (n, m) => `${n} of ${m} sessions done`, session_now: (x) => `now: ${x}`,
    t_session_done: (x) => `${x}: done`, t_all_sessions: "All sessions done for today",
  },
  ar: {
    s_add_detail: "أضف تفصيلًا", s_remove: "إزالة", s_examples: "أمثلة", s_add_session_short: "جلسة",
    pad_delete: "حذف", p_amount: "كم مرة؟", p_days: "في كم يومًا؟", p_min: "على الأقل", p_cap: "توقف عند", p_session_amount: "كم مرة في هذه الجلسة؟",
    p_rhythm: "كم مرة يتكرر؟", p_session: "متى في اليوم؟", p_start: "يبدأ", p_end: "ينتهي", p_finish: "يكتمل", p_streak: "تُحسب السلسلة عند", p_name: "الاسم", p_shared: "مشاركة العدّ",
    s_once: "مرة واحدة", s_anycount: "كلما استطعت", s_anycount_sub: "بلا عدد: أي عدّ يُحسب تقدمًا",
    g_repeat: "التكرار", g_occasions: "المناسبات", g_totals: "الإجماليات",
    r_every_day: "كل يوم", r_weekdays: "أيام محددة من الأسبوع", r_every_n: "كل بضعة أيام", r_month_days: "أيام من الشهر", r_hijri_days: "أيام من كل شهر هجري", r_dates: "تواريخ محددة", r_yearly: "كل سنة",
    o_ramadan_whole: "رمضان، كل يوم", o_ramadan_first10: "رمضان، العشر الأوائل", o_ramadan_middle10: "رمضان، العشر الأواسط", o_ramadan_last10: "رمضان، العشر الأواخر", o_ramadan_odd: "رمضان، ليالي الوتر",
    o_shawwal_six: "ستة أيام من شوال", o_dhul_hijjah_first10: "العشر الأوائل من ذي الحجة", o_arafah: "يوم عرفة", o_ashura: "عاشوراء (٩–١٠ محرم)",
    tt_period_week: "إجمالي كل أسبوع", tt_period_month: "إجمالي كل شهر", tt_period_hijri_month: "إجمالي كل شهر هجري",
    tt_dpp_week: "في بعض أيام الأسبوع", tt_dpp_month: "في بعض أيام الشهر", tt_dpp_hijri_month: "في بعض أيام الشهر الهجري", tt_total: "إجمالي واحد",
    every_lbl: "كل", days_lbl: "أيام", from_lbl: "بدءًا من", white_btn: "الأيام البيض (١٣–١٥)", add_btn: "إضافة", range_lbl: "مدى من الأيام", cal_greg: "ميلادي", cal_hijri: "هجري", from_day: "من", to_day: "إلى",
    k_anytime: "أي وقت", k_prayer: "بعد صلاة", k_time: "في وقت محدد", k_between: "بين وقتين", remove_session: "إزالة هذه الجلسة",
    e_until: "حتى تاريخ", e_for: "لعدد من الأيام", e_open: "حتى أتوقف",
    fr_reach: "أنهِه عند بلوغه", fr_until: "استمر حتى تاريخ", sh_share: "شارك العدّ", sh_separate: "احسب كلًّا على حدة",
    d_minimum: "على الأقل…", d_cap: "توقف عند…", d_sessions: "قسّمه إلى جلسات", d_period: "البداية والنهاية", d_finish: "متى يكتمل", d_streak: "ما تحسبه السلسلة", d_name: "سمِّه", d_shared: "شارك العدّ مع هدفي الآخر",
    d_remind: "ذكّرني…", coming_soon: "قريبًا",
    err_amount: "أضف عددًا", err_days: (max) => `اختر من ١ إلى ${max} أيام`, err_wd: "اختر يومًا واحدًا على الأقل", err_dates: "أضف تاريخًا واحدًا على الأقل", err_every: "اختر من ١ إلى ٣٦٦ يومًا", err_yearly: "اختر تاريخًا صحيحًا",
    err_min: "أكثر من الهدف", err_cap: "أقل من الهدف", err_sessions: "كل جلسة تحتاج إلى عدد", err_sess_dup: "جلستان في الوقت نفسه",
    err_end: "ينتهي قبل أن يبدأ", err_need_end: "اختر تاريخ الانتهاء", err_for: "أضف عدد الأيام", err_streak_min: "لم يُحدَّد حد أدنى", err_streak_target: "لم يُحدَّد هدف", err_streak_cap: "لم يُحدَّد حد أقصى", err_name: "أضف اسمًا أو أزل هذا",
    chip_dpp: (t, d, p) => `${t} يوميًا، ${d} أيام في ${p}`, your_dhikrs: "أذكارك",
    sessions_done: (n, m) => `${n} من ${m} جلسات مكتملة`, session_now: (x) => `الآن: ${x}`,
    t_session_done: (x) => `${x}: اكتملت`, t_all_sessions: "اكتملت كل جلسات اليوم",
  },
  ml: {
    new_goal_title: "പുതിയ ലക്ഷ്യം", edit: "ലക്ഷ്യം തിരുത്തുക", add_goal_btn: "ലക്ഷ്യം ചേർക്കുക", save_changes: "മാറ്റങ്ങൾ സേവ് ചെയ്യുക", close: "അടയ്ക്കുക", back: "തിരികെ",
    step_dhikr: "ദിക്ർ തിരഞ്ഞെടുക്കുക", search_ph: "ദിക്റുകൾ തിരയുക", pad_done: "ശരി", clear: "മായ്ക്കുക", preview_goals: "പ്രിവ്യൂ",
    s_add_detail: "വിശദാംശം ചേർക്കുക", s_remove: "നീക്കുക", s_examples: "ഉദാഹരണങ്ങൾ", s_add_session_short: "സെഷൻ",
    pad_delete: "മായ്ക്കുക", p_amount: "എത്ര തവണ?", p_days: "എത്ര ദിവസം?", p_min: "കുറഞ്ഞത്", p_cap: "ഇവിടെ നിർത്തുക", p_session_amount: "ഈ സെഷനിൽ എത്ര?",
    p_rhythm: "എത്ര ഇടവിട്ട്?", p_session: "ദിവസത്തിൽ എപ്പോൾ?", p_start: "തുടക്കം", p_end: "അവസാനം", p_finish: "പൂർത്തീകരണം", p_streak: "സ്ട്രീക്ക് എണ്ണുന്നത്", p_name: "പേര്", p_shared: "പങ്കിട്ട എണ്ണം",
    s_once: "ഒരു തവണ", s_anycount: "കഴിയുമ്പോഴെല്ലാം", s_anycount_sub: "എണ്ണമില്ല: ഏത് എണ്ണവും പുരോഗതി",
    g_repeat: "ആവർത്തനം", g_occasions: "സന്ദർഭങ്ങൾ", g_totals: "ആകെത്തുകകൾ",
    r_every_day: "എല്ലാ ദിവസവും", r_weekdays: "തിരഞ്ഞെടുത്ത ആഴ്ചദിവസങ്ങൾ", r_every_n: "ഏതാനും ദിവസം കൂടുമ്പോൾ", r_month_days: "മാസത്തിലെ ദിവസങ്ങൾ", r_hijri_days: "ഹിജ്റ മാസത്തിലെ ദിവസങ്ങൾ", r_dates: "നിശ്ചിത തീയതികൾ", r_yearly: "എല്ലാ വർഷവും",
    o_ramadan_whole: "റമദാൻ, എല്ലാ ദിവസവും", o_ramadan_first10: "റമദാൻ, ആദ്യ പത്ത്", o_ramadan_middle10: "റമദാൻ, നടുവിലെ പത്ത്", o_ramadan_last10: "റമദാൻ, അവസാന പത്ത്", o_ramadan_odd: "റമദാൻ, ഒറ്റ രാവുകൾ",
    o_shawwal_six: "ശവ്വാലിലെ ആറ് ദിവസം", o_dhul_hijjah_first10: "ദുൽഹിജ്ജ ആദ്യ പത്ത്", o_arafah: "അറഫാ ദിനം", o_ashura: "ആശൂറാ (മുഹർറം 9–10)",
    tt_period_week: "ആഴ്ചയിൽ ആകെ", tt_period_month: "മാസത്തിൽ ആകെ", tt_period_hijri_month: "ഹിജ്റ മാസത്തിൽ ആകെ",
    tt_dpp_week: "ആഴ്ചയിൽ ചില ദിവസങ്ങൾ", tt_dpp_month: "മാസത്തിൽ ചില ദിവസങ്ങൾ", tt_dpp_hijri_month: "ഹിജ്റ മാസത്തിൽ ചില ദിവസങ്ങൾ", tt_total: "ഒരു ആകെത്തുക",
    d_minimum: "കുറഞ്ഞത്…", d_cap: "ഇവിടെ നിർത്തുക…", d_sessions: "സെഷനുകളായി തിരിക്കുക", d_period: "തുടക്കവും അവസാനവും", d_finish: "എപ്പോൾ പൂർത്തിയാകും", d_streak: "സ്ട്രീക്ക് എന്ത് എണ്ണും", d_name: "പേര് നൽകുക", d_shared: "മറ്റേ ലക്ഷ്യവുമായി എണ്ണം പങ്കിടുക",
    d_remind: "ഓർമ്മിപ്പിക്കുക…", coming_soon: "ഉടൻ വരുന്നു",
    err_amount: "ഒരു എണ്ണം ചേർക്കുക", err_min: "ലക്ഷ്യത്തേക്കാൾ കൂടുതൽ", err_cap: "ലക്ഷ്യത്തേക്കാൾ കുറവ്", err_end: "തുടങ്ങും മുമ്പ് അവസാനിക്കുന്നു",
    your_dhikrs: "നിങ്ങളുടെ ദിക്റുകൾ",
    sessions_done: (n, m) => `${m} സെഷനിൽ ${n} പൂർത്തിയായി`, session_now: (x) => `ഇപ്പോൾ: ${x}`,
  },
};
STRINGS.ml = STRINGS.ml || {};
for (const l of ["en", "ar", "ml"]) Object.assign(STRINGS[l], SHEET_STRINGS[l]);

/* --- The B draft --- */
function sdNew(prefill = {}) {
  return Object.assign({ flow: "sentence", mode: "create", goalId: null, dhikr: null, amount: "100", anyCount: false, rhythmReq: "per_due_date", period: "week", days: "5",
    schedule: { kind: "every_day" }, preset: null, occasion: null, yearlySingle: true, details: {}, picker: null, query: "" }, structuredClone(prefill));
}
const sdReq = (d) => (d.anyCount ? "tracker" : d.rhythmReq);
const autoStreak = (d) => (["tracker", "cumulative_total"].includes(sdReq(d)) ? "any_count" : d.details.minimum ? "minimum" : "target");
/* Drop details that no longer apply after the amount or rhythm changed. */
function sdNormalize(d) {
  const D = d.details, req = sdReq(d);
  if (req === "cumulative_total" || req === "tracker") delete D.minimum;
  if (req === "cumulative_total") delete D.cap;
  if (req !== "per_due_date") delete D.sessions;
  if (req !== "cumulative_total") delete D.finish;
  return d;
}
function sdFromGoal(g) {
  const d = sdNew(), D = d.details, req = g.requirement.type;
  const p0 = g.sessions[0]?.count_policy || g.count_policy;
  Object.assign(d, { mode: "edit", goalId: g.id, dhikr: g.dhikr, anyCount: req === "tracker", rhythmReq: req === "tracker" ? "per_due_date" : req,
    schedule: structuredClone(g.schedule), preset: g.preset || null, occasion: occasionOf(g.schedule), amount: String(p0.target ?? 100) });
  if (g.requirement.period) d.period = g.requirement.period;
  if (g.requirement.days) d.days = String(g.requirement.days);
  if (d.rhythmReq === "cumulative_total") d.schedule = { kind: "one_time" };
  if (g.schedule.kind === "yearly") d.yearlySingle = g.schedule.ranges.every((r) => r.start.month === r.end.month && r.start.day === r.end.day);
  if (!g.sessions.length) {
    if (g.count_policy.minimum != null) D.minimum = { value: String(g.count_policy.minimum) };
    if (g.count_policy.maximum != null) D.cap = { value: String(g.count_policy.maximum) };
  } else D.sessions = { list: g.sessions.map((s) => ({ ...parseSession(s.id), amount: String(s.count_policy.target ?? "") })) };
  const ap = g.active_period;
  if (ap.end_date || ap.duration_days || ap.start_date !== today()) D.period = { start: ap.start_date, mode: ap.duration_days ? "for" : ap.end_date ? "until" : "open", end: ap.end_date || "", days: String(ap.duration_days || 40) };
  if (req === "cumulative_total" && g.completion === "when_duration_ended") D.finish = { mode: "until" };
  if (p0.streak_threshold !== autoStreak(d)) D.streak = { value: p0.streak_threshold };
  if (g.name) D.name = { value: g.name[lang()] || g.name.en };
  if (g.counts === "dedicated") D.shared = false;
  return d;
}
function sdToGoal(d, base = null) {
  const D = d.details, req = sdReq(d);
  const num = (v) => { const n = intOrNull(v); return n > 0 ? n : 0; };
  const target = req === "tracker" ? null : num(d.amount);
  const fix = (th, p) => ((th === "minimum" && p.minimum == null) || (th === "maximum" && p.maximum == null) || (th === "target" && p.target == null) ? (p.target == null ? "any_count" : "target") : th);
  const threshold = D.streak?.value || autoStreak(d);
  let schedule = structuredClone(d.schedule);
  if (req === "period_total" || (req === "days_per_period" && d.occasion !== "shawwal_six")) schedule = { kind: "every_day" };
  if (req === "cumulative_total") schedule = { kind: "one_time" };
  if (schedule.kind === "every_n_days") { schedule.every = num(schedule.every) || 1; schedule.anchor_date = schedule.anchor_date || null; }
  if (schedule.days) schedule.days = [...schedule.days].sort((a, b) => a - b);
  if (schedule.dates) schedule.dates = [...schedule.dates].sort();
  const requirement = req === "period_total" ? { type: req, period: d.period } : req === "days_per_period" ? { type: req, period: d.period, days: num(d.days) || 1 } : { type: req };
  const cp = { minimum: D.minimum ? num(D.minimum.value) : null, target, maximum: D.cap ? num(D.cap.value) : null, streak_threshold: null };
  cp.streak_threshold = fix(threshold, cp);
  const sessions = D.sessions ? dedupeIds(D.sessions.list).map(({ id, s }) => {
    const p = { minimum: null, target: req === "tracker" ? null : num(s.amount), maximum: null, streak_threshold: null };
    p.streak_threshold = fix(threshold, p);
    return { id, count_policy: p };
  }) : [];
  const p = D.period, end = p?.mode === "until" && p.end ? p.end : null, duration = p?.mode === "for" ? num(p.days) || null : null;
  const nm = D.name?.value?.trim();
  return {
    id: base?.id || uuidv7(), dhikr: d.dhikr,
    name: nm ? (base?.name && (base.name[lang()] || base.name.en) === nm ? base.name : { en: nm, ar: nm, ml: nm }) : null,
    custom_arabic: base?.custom_arabic || null, preset: d.preset, schedule,
    active_period: { start_date: p?.start || today(), end_date: end, duration_days: duration },
    paused: base?.paused || [],
    count_policy: sessions.length ? { minimum: null, target: null, maximum: null, streak_threshold: "any_count" } : cp,
    sessions, requirement,
    completion: req === "cumulative_total" ? (D.finish?.mode === "until" ? "when_duration_ended" : "when_target_reached") : end || duration ? "when_duration_ended" : "never",
    counts: siblingsOf(d).length && D.shared === false ? "dedicated" : "shared",
    count_entries: base?.count_entries || [], created: base?.created || today(),
  };
}
const validMD = (cal, md) => Number.isInteger(md.month) && md.month >= 1 && md.month <= 12 && Number.isInteger(md.day) && md.day >= 1 && md.day <= (cal === "hijri" ? 30 : monthLen(2024, md.month));
function sdErrors(d) {
  const e = {}, D = d.details, s = d.schedule, req = sdReq(d), n = intOrNull(d.amount);
  const target = req === "tracker" || D.sessions ? null : n;
  if (!d.anyCount && !D.sessions && !(n > 0)) e.amount = t("err_amount");
  if (req === "days_per_period") { const max = { week: 7, month: 31, hijri_month: 30 }[d.period], k = intOrNull(d.days); if (!(k >= 1 && k <= max)) e.days = t("err_days", max); }
  if (["per_due_date", "tracker"].includes(req) || d.occasion === "shawwal_six") {
    if (s.kind === "weekdays" && !s.weekdays.length) e.rhythm = t("err_wd");
    if (["month_days", "hijri_month_days"].includes(s.kind) && !s.days.length) e.rhythm = t("err_wd");
    if (s.kind === "specific_dates" && !s.dates.length) e.rhythm = t("err_dates");
    if (s.kind === "every_n_days" && !(+s.every >= 1 && +s.every <= 366)) e.rhythm = t("err_every");
    if (s.kind === "yearly" && !s.ranges.every((r) => validMD(s.calendar, r.start) && validMD(s.calendar, r.end))) e.rhythm = t("err_yearly");
  }
  if (D.minimum) { const m = intOrNull(D.minimum.value); if (!(m > 0)) e.minimum = t("err_amount"); else if (target > 0 && m > target) e.minimum = t("err_min"); }
  if (D.cap) { const x = intOrNull(D.cap.value); if (!(x > 0)) e.cap = t("err_amount"); else if (target > 0 && x < target) e.cap = t("err_cap"); }
  if (D.sessions) {
    const ids = new Set();
    D.sessions.list.forEach((ss, i) => {
      if (!d.anyCount && !(intOrNull(ss.amount) > 0)) { e["session" + i] = true; e.sessions = t("err_sessions"); }
      const id = sessionBaseId(ss);
      if (ids.has(id)) { e["sessdup" + i] = true; e.sessions ||= t("err_sess_dup"); }
      ids.add(id);
    });
  }
  if (D.period) {
    const p = D.period;
    if (p.mode === "until") { if (!p.end) e.period = t("err_need_end"); else if (p.end < p.start) e.period = t("err_end"); }
    if (p.mode === "for" && !(intOrNull(p.days) >= 1)) e.period = t("err_for");
  }
  if (D.finish?.mode === "until" && !(D.period?.mode === "until" && D.period.end)) e.finish = t("err_need_end");
  if (D.streak) {
    const v = D.streak.value;
    if (v === "minimum" && !D.minimum) e.streak = t("err_streak_min");
    if (v === "maximum" && !D.cap) e.streak = t("err_streak_cap");
    if (v === "target" && req === "tracker") e.streak = t("err_streak_target");
  }
  if (D.name && !D.name.value.trim()) e.name = t("err_name");
  return e;
}
const sdValid = (d) => !!d.dhikr && !Object.keys(sdErrors(d)).length;

/* --- The sentence, built once with tokens (UI) and once as plain text (read-back) --- */
function runsText(days, L) {
  const xs = [...days].sort((a, b) => a - b), runs = [];
  for (const x of xs) { const r = runs.at(-1); if (r && x === r[1] + 1) r[1] = x; else runs.push([x, x]); }
  return L.and(runs.map(([a, b]) => (a === b ? String(a) : `${a}–${b}`)));
}
const gMonthDay = (m, d) => new Intl.DateTimeFormat(LOCALE(), { day: "numeric", month: "long", timeZone: "UTC" }).format(new Date(Date.UTC(2024, m - 1, Math.min(d, 31))));
function rhythmText(d, L = SL()) {
  const EN = SENTENCE_L10N.en.rhythm, R = (k) => L.rhythm[k] ?? EN[k];
  if (d.rhythmReq === "cumulative_total") return R("total");
  if (d.rhythmReq === "period_total") return L.period[d.period];
  if (d.rhythmReq === "days_per_period") return d.occasion === "shawwal_six" ? R("shawwal_six") : L.period[d.period];
  if (d.occasion) return L.rhythm.occasions?.[d.occasion] ?? EN.occasions[d.occasion];
  const s = d.schedule;
  switch (s.kind) {
    case "every_day": return R("every_day");
    case "one_time": return R("one_time");
    case "weekdays": {
      const ws = WEEKDAYS.filter((w) => s.weekdays.includes(w));
      if (!ws.length) return "?";
      return ws.length === 1 ? R("weekdays1")(weekdayName(ws[0])) : R("weekdays")(L.and(ws.map((w) => L.weekdayPlural(weekdayName(w)))));
    }
    case "every_n_days": return R("every_n")(+s.every || "?", s.anchor_date ? fmtDate(s.anchor_date) : null);
    case "month_days": return s.days.length ? R("month_days")(L.and([...s.days].sort((a, b) => a - b).map(L.ord))) : "?";
    case "hijri_month_days": return String([...s.days].sort((a, b) => a - b)) === "13,14,15" ? R("white") : s.days.length ? R("hijri_days")(runsText(s.days, L)) : "?";
    case "specific_dates": return s.dates.length ? R("dates")(L.and([...s.dates].sort().map((x) => fmtDate(x)))) : "?";
    case "yearly": {
      const r = s.ranges[0], f = (md) => (!validMD(s.calendar, md) ? "?" : s.calendar === "hijri" ? `${md.day} ${hMonths()[md.month - 1]}` : gMonthDay(md.month, md.day));
      return r.start.month === r.end.month && r.start.day === r.end.day ? R("yearly_on")(f(r.start)) : R("yearly_range")(f(r.start), f(r.end));
    }
  }
  return "";
}
const uiTok = (text, data, flags = {}) => `<button class="token pressable ${flags.bad ? "bad" : ""} ${flags.empty ? "empty" : ""}" data-action="s-open" ${Object.entries(data).map(([k, v]) => `data-${k}="${esc(v)}"`).join(" ")}><span>${esc(text)}</span></button>`;
const plainTok = (text) => text;
function sdParts(d, T) {
  const L = SL(), E = sdErrors(d), D = d.details, n = intOrNull(d.amount), req = sdReq(d);
  const fmtD = (x) => (x === today() ? L.today : x ? fmtDate(x) : "?");
  const dhikr = T(d.dhikr ? dhikrName(d.dhikr) : L.pickDhikr, { picker: "dhikr" }, { empty: !d.dhikr });
  const amount = T(d.anyCount ? L.anyCount : n > 0 ? L.amount(n, gN(n)) : L.pickAmount, { picker: "amount" }, { bad: !!E.amount, empty: !d.anyCount && !(n > 0) });
  const rhythm = T(rhythmText(d, L), { picker: "rhythm" }, { bad: !!E.rhythm });
  const days = T(d.days || "?", { picker: "number", field: "days" }, { bad: !!E.days });
  const main = L.main({ req, verb: L.verb[verbKind(d.dhikr)], dhikr, amount, rhythm, days, sessions: !!D.sessions });
  const cl = {};
  const numTok = (v, field, bad) => T(intOrNull(v) > 0 ? gN(intOrNull(v)) : "?", { picker: "number", field }, { bad });
  if (D.minimum) cl.minimum = L.min(numTok(D.minimum.value, "minimum", !!E.minimum));
  if (D.cap) cl.cap = L.cap(numTok(D.cap.value, "cap", !!E.cap));
  if (D.sessions) cl.sessions = L.and(D.sessions.list.map((s, i) => L.session(numTok(s.amount, `session:${i}`, !!E["session" + i]), T(sessionWhenText(s, L), { picker: "session", index: i }, { bad: !!E["sessdup" + i] }))));
  if (D.period) {
    const p = D.period, endTok = (x) => T(x, { picker: "end" }, { bad: !!E.period });
    const end = p.mode === "for" ? L.forDays(endTok(L.daysN(p.days || "?"))) : p.mode === "open" ? endTok(L.open) : (req === "cumulative_total" ? L.by : L.until)(endTok(fmtD(p.end)));
    cl.period = L.periodClause(L.from(T(fmtD(p.start), { picker: "start" })), end);
  }
  if (D.finish) cl.finish = D.finish.mode === "reach" ? T(L.finishReach, { picker: "finish" }) : L.finishUntil(T(L.finishUntilWord, { picker: "finish" }), T(fmtD(D.period?.end), { picker: "finish" }, { bad: !!E.finish }));
  const streakVal = D.streak?.value || autoStreak(d);
  if (D.streak) cl.streak = L.streak(T(L.streakVals[streakVal], { picker: "streak" }, { bad: !!E.streak }));
  if (D.name) cl.name = L.name(T(D.name.value.trim() ? L.quote(D.name.value.trim()) : "?", { picker: "name" }, { bad: !!E.name }));
  const sib = siblingsOf(d).length > 0;
  if (sib && D.shared !== false) cl.shared = L.shared(T(dhikrName(d.dhikr), { picker: "shared" }));
  return { main, cl, streakVal, sib, E };
}
function sdReadback(d) {
  const L = SL(), P = sdParts(d, plainTok), D = d.details;
  return L.readback({ main: P.main, sessions: P.cl.sessions, clauses: [P.cl.minimum, P.cl.cap, P.cl.period, P.cl.finish].filter(Boolean),
    streak: L.streakVals[P.streakVal], name: D.name?.value?.trim() ? L.quote(D.name.value.trim()) : null, shared: P.sib ? D.shared !== false : undefined, dhikr: dhikrName(d.dhikr) });
}
function sdPreview(d) {
  const g = sdToGoal(d, d.goalId ? goalById(d.goalId) : null);
  if (!d.dhikr) g.name = { en: SL().pickDhikr, ar: SL().pickDhikr, ml: SL().pickDhikr };
  return goalCard(g, "today", { preview: true, isNew: d.mode === "create" });
}

/* --- Examples (each returns a draft patch) --- */
const nextDec30 = () => { const y = +today().slice(0, 4); return `${today() > `${y}-12-30` ? y + 1 : y}-12-30`; };
const SD_EXAMPLES = [
  () => ({ dhikr: "swalath", amount: "100", details: { minimum: { value: "70" }, cap: { value: "313" }, streak: { value: "minimum" } } }),
  () => ({ dhikr: "isthighfar", amount: "100", details: { sessions: { list: [{ kind: "prayer", prayer: "fajr", amount: "100" }, { kind: "prayer", prayer: "maghrib", amount: "100" }] } } }),
  () => ({ dhikr: "tahleel", amount: "70000", rhythmReq: "cumulative_total", schedule: { kind: "one_time" }, details: { period: { start: today(), mode: "until", end: nextDec30(), days: "40" } } }),
  () => ({ dhikr: "asma-ul-husna-al-latif", amount: "129", details: { period: { start: today(), mode: "for", days: "40", end: "" } } }),
  () => ({ dhikr: "swalath", amount: "1000", rhythmReq: "period_total", period: "week" }),
  () => ({ dhikr: "swalath", amount: "100", rhythmReq: "days_per_period", period: "week", days: "5" }),
  () => ({ dhikr: "surah-ikhlas", amount: "3", schedule: { kind: "hijri_month_days", days: [13, 14, 15] }, preset: "white_days" }),
  () => ({ dhikr: "custom:dua-kumayl", amount: "1", schedule: { kind: "weekdays", weekdays: ["thursday"] } }),
  () => ({ dhikr: "isthighfar", amount: "1000", schedule: hijriRanges(OCCASIONS.ramadan_last10.ranges), preset: "ramadan_last_ten", occasion: "ramadan_last10" }),
];

/* --- Level 1: the sentence, details, preview, read-back --- */
const DETAIL_ORDER = ["minimum", "cap", "sessions", "period", "finish", "streak", "name", "shared"];
function sdLevel1(d) {
  const L = SL(), P = sdParts(d, uiTok), E = P.E;
  const reason = (k) => (typeof E[k] === "string" ? `<div class="sreason" role="alert">${esc(E[k])}</div>` : "");
  const line = (k) => `<div class="dline"><div class="dtext">${P.cl[k]}${k === "sessions" ? ` <button class="token add pressable" data-action="s-sess-add"><span>+ ${esc(t("s_add_session_short"))}</span></button>` : ""}</div>
      <button class="icon-btn pressable" data-action="s-remove" data-val="${k}" aria-label="${esc(t("s_remove"))}">${icon("close")}</button></div>${reason(k)}`;
  return `<div class="handle"></div>
    <div class="sheet-head"><h2 class="t-cardTitle">${d.mode === "edit" ? t("edit") : t("new_goal_title")}</h2>
      <button class="icon-btn pressable" data-action="close-create" aria-label="${esc(t("close"))}">${icon("close")}</button></div>
    <div class="sheet-scroll">
      <div class="examples" role="group" aria-label="${esc(t("s_examples"))}">${(L.examples || SENTENCE_L10N.en.examples).map((x, i) => `<button class="filter-chip pressable" data-action="s-example" data-i="${i}">${esc(x)}</button>`).join("")}</div>
      <p class="sentence t-title">${P.main}</p>
      ${reason("amount")}${reason("days")}${reason("rhythm")}
      <div class="dlines t-body">${DETAIL_ORDER.filter((k) => P.cl[k]).map(line).join("")}</div>
      <button class="add-detail pressable" data-action="s-open" data-picker="add">${icon("add", "small")}<span>${t("s_add_detail")}</span></button>
    </div>
    <div class="sheet-foot">
      <div data-slot="preview">${sdPreview(d)}</div>
      <p class="readback t-bodySmall" aria-live="polite">${esc(sdReadback(d))}</p>
      <button class="btn main pressable" data-action="create-save" ${sdValid(d) ? "" : "disabled"}>${saveLabel(d)}</button>
    </div>`;
}

/* --- Level 2: pickers --- */
function rhythmSel(d) {
  if (d.rhythmReq === "cumulative_total") return "total";
  if (d.rhythmReq === "period_total") return "period_" + d.period;
  if (d.rhythmReq === "days_per_period") return d.occasion === "shawwal_six" ? "shawwal_six" : "dpp_" + d.period;
  return d.occasion || d.schedule.kind;
}
function padHTML(value) {
  const keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "clear", "0", "del"];
  return `<div class="pad-display t-counter">${intOrNull(value) > 0 ? gN(intOrNull(value)) : "–"}</div>
    <div class="pad" dir="ltr">${keys.map((k) => `<button class="pressable" data-action="s-pad" data-key="${k}">${k === "del" ? `<span class="t-label">${t("pad_delete")}</span>` : k === "clear" ? `<span class="t-label">${t("clear")}</span>` : k}</button>`).join("")}</div>`;
}
const FIELD = {
  amount: [(d) => d.amount, (d, v) => { d.amount = v; d.anyCount = false; }],
  days: [(d) => d.days, (d, v) => (d.days = v)],
  minimum: [(d) => d.details.minimum?.value, (d, v) => (d.details.minimum.value = v)],
  cap: [(d) => d.details.cap?.value, (d, v) => (d.details.cap.value = v)],
};
const fieldGet = (d, f) => (f.startsWith("session:") ? d.details.sessions.list[+f.slice(8)].amount : FIELD[f][0](d)) ?? "";
const fieldSet = (d, f, v) => (f.startsWith("session:") ? (d.details.sessions.list[+f.slice(8)].amount = v) : FIELD[f][1](d, v));
function sdPicker(d) {
  const p = d.picker, D = d.details, L = SL();
  const head = (title) => `<div class="handle"></div><div class="sheet-head with-back"><button class="icon-btn pressable" data-action="s-close" aria-label="${esc(t("back"))}">${icon("back", "mirror")}</button><h2 class="t-cardTitle">${esc(title)}</h2></div>`;
  const foot = `<div class="sheet-foot"><button class="btn main pressable" data-action="s-close">${t("pad_done")}</button></div>`;
  const body = (html) => `<div class="sheet-scroll">${html}</div>`;
  const chip = (on, action, attrs, label) => `<button class="filter-chip pressable" aria-pressed="${on}" data-action="${action}" ${attrs}>${on ? icon("check", "small") : ""}${esc(label)}</button>`;
  const input = (path, value, type = "text", extra = "") => `<input class="field t-input ${type === "number" ? "small" : ""}" type="${type === "number" ? "text" : type}" ${type === "number" ? 'inputmode="numeric"' : ""} data-sinput="${path}" value="${esc(value ?? "")}" ${extra}>`;
  switch (p.kind) {
    case "dhikr": return head(t("step_dhikr")) + body(searchField(d));
    case "amount": {
      const quick = d.rhythmReq === "cumulative_total" ? [1000, 4444, 10000, 70000] : d.rhythmReq === "period_total" ? [100, 313, 1000, 7000] : [33, 100, 313, 1000];
      return head(t("p_amount")) + body(`${padHTML(d.anyCount ? "" : d.amount)}
        <div class="chip-row" style="justify-content:center;margin:var(--s-lg) 0">${chip(d.amount === "1" && !d.anyCount, "s-quick", 'data-n="1"', t("s_once"))}${quick.map((n) => chip(String(n) === d.amount && !d.anyCount, "s-quick", `data-n="${n}"`, gN(n))).join("")}</div>
        <div class="options">${optionRow("any", t("s_anycount"), t("s_anycount_sub"), d.anyCount, "s-anycount")}</div>`) + foot;
    }
    case "number": {
      const title = { days: t("p_days"), minimum: t("p_min"), cap: t("p_cap") }[p.field] || t("p_session_amount");
      return head(title) + body(padHTML(fieldGet(d, p.field))) + foot;
    }
    case "rhythm": {
      const sel = rhythmSel(d), s = d.schedule;
      const row = (id, label, extra = "") => optionRow(id, label, "", sel === id, "s-rhythm", extra);
      const grid = (n, list, op) => `<div class="daygrid">${Array.from({ length: n }, (_, i) => i + 1).map((x) => `<button class="filter-chip pressable" aria-pressed="${list.includes(x)}" data-action="s-sched" data-op="${op}" data-val="${x}">${x}</button>`).join("")}</div>`;
      const monthOpts = (cal, v) => Array.from({ length: 12 }, (_, i) => `<option value="${i + 1}" ${v === i + 1 ? "selected" : ""}>${esc(cal === "hijri" ? hMonths()[i] : new Intl.DateTimeFormat(LOCALE(), { month: "long", timeZone: "UTC" }).format(new Date(Date.UTC(2024, i, 1))))}</option>`).join("");
      const extras = {
        weekdays: s.kind === "weekdays" ? `<div class="chip-row">${WEEKDAYS.map((w) => chip(s.weekdays.includes(w), "s-sched", `data-op="wd" data-val="${w}"`, weekdayName(w, "short"))).join("")}</div>` : "",
        every_n_days: s.kind === "every_n_days" ? `<div class="inline-fields"><span>${t("every_lbl")}</span>${input("schedule.every", s.every, "number")}<span>${t("days_lbl")}, ${t("from_lbl")}</span>${input("schedule.anchor_date", s.anchor_date || d.details.period?.start || today(), "date")}</div>` : "",
        month_days: s.kind === "month_days" ? grid(31, s.days, "md") : "",
        hijri_month_days: s.kind === "hijri_month_days" ? `<div class="chip-row" style="margin-bottom:var(--s-sm)">${chip(String([...s.days].sort((a, b) => a - b)) === "13,14,15", "s-sched", 'data-op="white"', t("white_btn"))}</div>${grid(30, s.days, "hd")}` : "",
        specific_dates: s.kind === "specific_dates" ? `<div class="inline-fields"><input class="field t-input" type="date" data-new-date value="${addDays(today(), 7)}"><button class="btn secondary pressable" style="width:auto" data-action="s-sched" data-op="date-add">${t("add_btn")}</button></div>
            <div class="chip-row" style="margin-top:var(--s-sm)">${[...s.dates].sort().map((x) => `<button class="filter-chip pressable" aria-pressed="true" data-action="s-sched" data-op="date-rm" data-val="${x}">${esc(fmtDate(x, { day: "numeric", month: "short", year: "numeric" }))} ${icon("close", "small")}</button>`).join("")}</div>` : "",
        yearly: s.kind === "yearly" && !d.occasion ? `<div class="chip-row" style="margin-bottom:var(--s-sm)">${chip(s.calendar === "gregorian", "s-sched", 'data-op="cal" data-val="gregorian"', t("cal_greg"))}${chip(s.calendar === "hijri", "s-sched", 'data-op="cal" data-val="hijri"', t("cal_hijri"))}${chip(!d.yearlySingle, "s-sched", 'data-op="range"', t("range_lbl"))}</div>
            <div class="inline-fields"><span>${d.yearlySingle ? "" : t("from_day")}</span>${input("schedule.ranges.0.start.day", s.ranges[0].start.day, "number")}<select class="field t-input" data-sinput="schedule.ranges.0.start.month">${monthOpts(s.calendar, s.ranges[0].start.month)}</select></div>
            ${d.yearlySingle ? "" : `<div class="inline-fields" style="margin-top:var(--s-sm)"><span>${t("to_day")}</span>${input("schedule.ranges.0.end.day", s.ranges[0].end.day, "number")}<select class="field t-input" data-sinput="schedule.ranges.0.end.month">${monthOpts(s.calendar, s.ranges[0].end.month)}</select></div>`}` : "",
      };
      return head(t("p_rhythm")) + body(`
        <div class="pgroup t-sectionTitle">${t("g_repeat")}</div><div class="options">
          ${row("every_day", t("r_every_day"))}${row("weekdays", t("r_weekdays"), extras.weekdays)}${row("every_n_days", t("r_every_n"), extras.every_n_days)}
          ${row("month_days", t("r_month_days"), extras.month_days)}${row("hijri_month_days", t("r_hijri_days"), extras.hijri_month_days)}
          ${row("specific_dates", t("r_dates"), extras.specific_dates)}${row("yearly", t("r_yearly"), extras.yearly)}</div>
        <div class="pgroup t-sectionTitle">${t("g_occasions")}</div><div class="options">${Object.keys(OCCASIONS).map((k) => row(k, t("o_" + k))).join("")}</div>
        <div class="pgroup t-sectionTitle">${t("g_totals")}</div><div class="options">${["period_week", "period_month", "period_hijri_month", "dpp_week", "dpp_month", "dpp_hijri_month", "total"].map((k) => row(k, t("tt_" + k))).join("")}</div>`) + foot;
    }
    case "session": {
      const i = p.index, s = D.sessions.list[i];
      const row = (id, label, extra = "") => optionRow(id, label, "", s.kind === id, "s-sess-kind", extra);
      return head(t("p_session")) + body(`<div class="options">
        ${row("anytime", t("k_anytime"))}
        ${row("prayer", t("k_prayer"), `<div class="chip-row">${PRAYERS.map((pr) => chip(s.prayer === pr, "s-sess-prayer", `data-val="${pr}"`, L.prayers[pr])).join("")}</div>`)}
        ${row("time", t("k_time"), `<div class="inline-fields">${input(`details.sessions.list.${i}.time`, s.time, "time")}</div>`)}
        ${row("between", t("k_between"), `<div class="inline-fields">${input(`details.sessions.list.${i}.from`, s.from, "time")}<span>–</span>${input(`details.sessions.list.${i}.to`, s.to, "time")}</div>`)}
        </div>${D.sessions.list.length > 1 ? `<button class="btn text pressable" style="color:var(--c-error);margin-top:var(--s-md)" data-action="s-sess-rm" data-val="${i}">${t("remove_session")}</button>` : ""}`) + foot;
    }
    case "start": return head(t("p_start")) + body(input("details.period.start", D.period.start, "date")) + foot;
    case "end": {
      const P = D.period, row = (id, label, extra = "") => optionRow(id, label, "", P.mode === id, "s-end-mode", extra);
      return head(t("p_end")) + body(`<div class="options">
        ${row("until", t("e_until"), input("details.period.end", P.end, "date"))}
        ${row("for", t("e_for"), `<div class="inline-fields">${input("details.period.days", P.days, "number")}<span>${t("days_lbl")}</span></div>`)}
        ${row("open", t("e_open"))}</div>`) + foot;
    }
    case "finish": {
      const row = (id, label, extra = "") => optionRow(id, label, "", D.finish.mode === id, "s-finish", extra);
      return head(t("p_finish")) + body(`<div class="options">${row("reach", t("fr_reach"))}${row("until", t("fr_until"), D.period ? input("details.period.end", D.period.end, "date") : "")}</div>`) + foot;
    }
    case "streak": {
      const req = sdReq(d), cur = D.streak?.value || autoStreak(d);
      const vals = ["any_count", D.minimum && "minimum", !["tracker", "cumulative_total"].includes(req) && "target", D.cap && "maximum"].filter(Boolean);
      return head(t("p_streak")) + body(`<div class="options">${vals.map((v) => optionRow(v, L.streakVals[v], "", cur === v, "s-streak")).join("")}</div>`);
    }
    case "name": return head(t("p_name")) + body(input("details.name.value", D.name.value, "text", 'maxlength="40" autofocus')) + foot;
    case "shared": return head(t("p_shared")) + body(`<div class="options">${optionRow("share", t("sh_share"), t("shared_yes_sub"), D.shared !== false, "s-shared")}${optionRow("separate", t("sh_separate"), t("shared_no_sub"), D.shared === false, "s-shared")}</div>`);
    case "add": {
      const req = sdReq(d), sib = siblingsOf(d).length > 0;
      const avail = {
        minimum: !D.minimum && !D.sessions && !["tracker", "cumulative_total"].includes(req),
        cap: !D.cap && !D.sessions && req !== "cumulative_total",
        sessions: !D.sessions && !D.minimum && !D.cap && req === "per_due_date",
        period: !D.period, finish: !D.finish && req === "cumulative_total", streak: !D.streak, name: !D.name, shared: sib && D.shared === false,
      };
      return head(t("s_add_detail")) + body(`<div class="options">${Object.keys(avail).filter((k) => avail[k]).map((k) => optionRow(k, t("d_" + k), "", false, "s-add")).join("")}
        <div><button class="option-row" disabled aria-disabled="true" style="opacity:var(--disabled-opacity)"><div class="body"><div class="t-rowTitle">${t("d_remind")}</div><div class="sub">${t("coming_soon")}</div></div></button></div></div>`);
    }
  }
  return "";
}

/* --- Rendering the sheet (two levels, one height) --- */
function renderSentence(opts = {}) {
  const d = state.draft, host = document.getElementById("overlay-host");
  let sheet = host.querySelector(".overlay:not([data-closing]) .create-sheet");
  if (!sheet) {
    renderOverlay(`<div class="overlay" data-overlay><div class="scrim" data-action="close-create"></div>
      <div class="bsheet create-sheet" role="dialog" aria-label="${esc(t("new_goal_title"))}"><div class="level1">${sdLevel1(d)}</div><div class="level2-host"></div></div></div>`, "sheet");
    sheet = host.querySelector(".overlay:not([data-closing]) .create-sheet");
  } else {
    const l1 = sheet.querySelector(".level1"), sc = l1.querySelector(".sheet-scroll")?.scrollTop || 0;
    l1.innerHTML = sdLevel1(d);
    l1.querySelector(".sheet-scroll").scrollTop = sc;
  }
  if (opts.mainOnly) return;
  const l2 = sheet.querySelector(".level2-host"), was = l2.dataset.key || "";
  const now = d.picker ? `${d.picker.kind}:${d.picker.field || ""}:${d.picker.index ?? ""}` : "";
  const rtl = lang() === "ar" ? -1 : 1;
  if (!d.picker) {
    const panel = l2.firstElementChild;
    l2.dataset.key = "";
    if (!panel) return;
    if (reduced()) { panel.remove(); return; }
    panel.animate([{ transform: "none" }, { transform: `translateX(${100 * rtl}%)` }], { duration: MOTION.duration.short, easing: MOTION.easing.accelerate, fill: "forwards" }).onfinish = () => panel.remove();
    return;
  }
  const sc2 = l2.querySelector(".sheet-scroll")?.scrollTop || 0;
  l2.innerHTML = `<div class="level2">${sdPicker(d)}</div>`;
  l2.dataset.key = now;
  if (was === now) { l2.querySelector(".sheet-scroll") && (l2.querySelector(".sheet-scroll").scrollTop = sc2); return; }
  const panel = l2.firstElementChild, s = spring("spatial");
  if (reduced()) panel.animate([{ opacity: 0 }, { opacity: 1 }], { duration: MOTION.duration.color, easing: "linear" });
  else panel.animate([{ transform: `translateX(${100 * rtl}%)` }, { transform: "none" }], { duration: s.duration, easing: s.easing });
  panel.querySelector("[autofocus]")?.focus();
}
function setPath(obj, path, value) {
  const keys = path.split(".");
  let o = obj;
  for (const k of keys.slice(0, -1)) o = o[/^\d+$/.test(k) ? +k : k];
  const last = keys.at(-1);
  if (["month", "day", "every"].includes(last)) value = value === "" ? "" : +value;
  if (last === "anchor_date" && value === "") value = null;
  o[last] = value;
}
function applyRhythm(d, val) {
  const set = (o) => Object.assign(d, { rhythmReq: "per_due_date", preset: null, occasion: null }, o);
  const td = today(), [, mm, dd] = td.split("-").map(Number);
  let close = true;
  if (val === "every_day") set({ schedule: { kind: "every_day" } });
  else if (val === "weekdays") { close = false; if (d.schedule.kind !== "weekdays" || d.rhythmReq !== "per_due_date") set({ schedule: { kind: "weekdays", weekdays: [weekday(td)] } }); else set({}); }
  else if (val === "every_n_days") { close = false; if (d.schedule.kind !== "every_n_days") set({ schedule: { kind: "every_n_days", every: 2, anchor_date: null } }); else set({}); }
  else if (val === "month_days") { close = false; if (d.schedule.kind !== "month_days") set({ schedule: { kind: "month_days", days: [1] } }); else set({}); }
  else if (val === "hijri_month_days") { close = false; if (d.schedule.kind !== "hijri_month_days") set({ schedule: { kind: "hijri_month_days", days: [13, 14, 15] }, preset: "white_days" }); else set({ preset: d.preset }); }
  else if (val === "specific_dates") { close = false; if (d.schedule.kind !== "specific_dates") set({ schedule: { kind: "specific_dates", dates: [addDays(td, 7)] } }); else set({}); }
  else if (val === "yearly") { close = false; if (d.schedule.kind !== "yearly" || d.occasion) { set({ schedule: { kind: "yearly", calendar: "gregorian", ranges: [{ start: { month: mm, day: dd }, end: { month: mm, day: dd } }] } }); d.yearlySingle = true; } else set({}); }
  else if (OCCASIONS[val]) { const o = OCCASIONS[val]; set({ schedule: hijriRanges(o.ranges), preset: o.preset, occasion: val, ...(o.req || {}) }); }
  else if (val.startsWith("period_")) set({ rhythmReq: "period_total", period: val.slice(7), schedule: { kind: "every_day" } });
  else if (val.startsWith("dpp_")) set({ rhythmReq: "days_per_period", period: val.slice(4), schedule: { kind: "every_day" }, days: d.days || "5" });
  else if (val === "total") set({ rhythmReq: "cumulative_total", schedule: { kind: "one_time" } });
  if (d.rhythmReq !== "per_due_date") d.anyCount = false;
  sdNormalize(d);
  if (close) d.picker = null;
}
function sentenceAction(a, el) {
  const d = state.draft, ds = el.dataset, D = d.details, v = ds.val;
  const done = () => { sdNormalize(d); renderSentence(); return true; };
  switch (a) {
    case "close-create": closeOverlay(); return true;
    case "create-save": saveDraft(); return true;
    case "s-open": d.picker = { kind: ds.picker, field: ds.field, index: ds.index != null ? +ds.index : undefined }; if (ds.picker === "dhikr") d.query = ""; return done();
    case "s-close": d.picker = null; return done();
    case "pick-dhikr": d.dhikr = ds.key; d.query = ""; d.picker = null; return done();
    case "clear-query": d.query = ""; return done();
    case "s-pad": {
      const f = d.picker.field || "amount", k = ds.key;
      let s = String(fieldGet(d, f));
      if (k === "del") s = s.slice(0, -1); else if (k === "clear") s = ""; else if (s.length < 7) s = (s === "0" ? "" : s) + k;
      fieldSet(d, f, s); haptic("tick"); return done();
    }
    case "s-quick": fieldSet(d, d.picker.field || "amount", ds.n); return done();
    case "s-anycount": d.anyCount = true; if (d.rhythmReq !== "per_due_date") { d.rhythmReq = "per_due_date"; d.schedule = { kind: "every_day" }; d.occasion = null; d.preset = null; } d.picker = null; return done();
    case "s-rhythm": applyRhythm(d, v); return done();
    case "s-sched": {
      const s = d.schedule, op = ds.op, toggle = (arr, x) => { const i = arr.indexOf(x); i >= 0 ? arr.splice(i, 1) : arr.push(x); };
      if (op === "wd") toggle(s.weekdays, v);
      if (op === "md") toggle(s.days, +v);
      if (op === "hd") { toggle(s.days, +v); d.preset = String([...s.days].sort((x, y) => x - y)) === "13,14,15" ? "white_days" : null; }
      if (op === "white") { s.days = [13, 14, 15]; d.preset = "white_days"; }
      if (op === "date-add") { const x = el.closest(".level2").querySelector("[data-new-date]").value; if (x && !s.dates.includes(x)) s.dates.push(x); }
      if (op === "date-rm") s.dates = s.dates.filter((x) => x !== v);
      if (op === "cal") s.calendar = v;
      if (op === "range") {
        d.yearlySingle = !d.yearlySingle; const r = s.ranges[0], max = s.calendar === "hijri" ? 30 : monthLen(2024, r.start.month);
        if (d.yearlySingle) r.end = { ...r.start };
        else { if (r.start.day + 9 > max) r.start.day = max - 9; r.end = { month: r.start.month, day: r.start.day + 9 }; }
      }
      return done();
    }
    case "s-sess-add": {
      const list = D.sessions.list, used = list.filter((s) => s.kind === "prayer").map((s) => s.prayer);
      list.push({ kind: "prayer", prayer: PRAYERS.find((x) => !used.includes(x)) || "isha", amount: list.at(-1)?.amount || d.amount });
      return done();
    }
    case "s-sess-kind": Object.assign(D.sessions.list[d.picker.index], { kind: v }, { prayer: D.sessions.list[d.picker.index].prayer || "fajr", time: D.sessions.list[d.picker.index].time || "07:00", from: D.sessions.list[d.picker.index].from || "18:00", to: D.sessions.list[d.picker.index].to || "20:00" }); return done();
    case "s-sess-prayer": D.sessions.list[d.picker.index].prayer = v; return done();
    case "s-sess-rm": D.sessions.list.splice(+v, 1); d.picker = null; return done();
    case "s-end-mode": D.period.mode = v; if (v === "until" && !D.period.end) D.period.end = addDays(D.period.start, 30); return done();
    case "s-finish": D.finish.mode = v; if (v === "until") { D.period ||= { start: today(), mode: "until", end: "", days: "40" }; D.period.mode = "until"; if (!D.period.end) D.period.end = addDays(D.period.start, 60); } return done();
    case "s-streak": D.streak = { value: v }; d.picker = null; return done();
    case "s-shared": D.shared = v === "share"; d.picker = null; return done();
    case "s-add": {
      const target = intOrNull(d.amount) || 100;
      if (v === "minimum") { D.minimum = { value: String(Math.max(1, Math.round(target * 0.7))) }; d.picker = { kind: "number", field: "minimum" }; }
      if (v === "cap") { D.cap = { value: String(target * 3) }; d.picker = { kind: "number", field: "cap" }; }
      if (v === "sessions") { D.sessions = { list: [{ kind: "prayer", prayer: "fajr", amount: d.amount || "100" }] }; d.picker = null; }
      if (v === "period") { D.period = { start: today(), mode: "until", end: addDays(today(), 30), days: "40" }; d.picker = { kind: "end" }; }
      if (v === "finish") { D.finish = { mode: "reach" }; d.picker = { kind: "finish" }; }
      if (v === "streak") { D.streak = { value: autoStreak(d) }; d.picker = { kind: "streak" }; }
      if (v === "name") { D.name = { value: "" }; d.picker = { kind: "name" }; }
      if (v === "shared") { D.shared = true; d.picker = null; }
      return done();
    }
    case "s-remove": if (v === "shared") D.shared = false; else delete D[v]; if (v === "period" && D.finish?.mode === "until") D.finish.mode = "reach"; return done();
    case "s-example": {
      const keep = { mode: d.mode, goalId: d.goalId };
      state.draft = Object.assign(sdNew(SD_EXAMPLES[+ds.i]()), keep);
      haptic("tick"); sdNormalize(state.draft); renderSentence(); return true;
    }
  }
  return false;
}

/* --- C. Templates first --- */
const TEMPLATES = {
  daily: { icon: "streak", apply: { when: "every_day", count: "100" } },
  ramadan: { avatar: "tpl_ramadan_avatar", apply: { when: "ramadan", ramadanPart: "whole", count: "100" }, extra: (d) => ramadanChips(d) },
  white: { avatar: "tpl_white_avatar", apply: { when: "white", count: "100" } },
  weekly: { icon: "goals", apply: { when: "weekdays", weekdays: ["friday"], count: "100" }, extra: (d) => weekdayChips(d) },
  total: { icon: "check", apply: { when: "once", count: "70000" }, extra: (d) => field(d, "end", t("f_by"), t("f_end_help"), "date"), skipEnd: true },
  custom: { icon: "tune", apply: { moreOpen: true }, extra: (d) => whenOptions(d) },
};
function renderTemplates() {
  const d = state.draft;
  if (d.picker === "dhikr") return { cls: "fixed no-nav", html: `
    <header class="topbar"><button class="icon-btn pressable" data-action="close-picker" aria-label="${esc(t("back"))}">${icon("back", "mirror")}</button></header>
    <div class="create-body"><h1 class="t-title">${t("step_dhikr")}</h1><p class="lede t-bodySmall">${t("step_dhikr_lede")}</p>${searchField(d)}</div>` };
  if (!d.template) return { cls: "fixed no-nav", html: `
    <header class="topbar"><button class="icon-btn pressable" data-action="create-back" aria-label="${esc(t("close"))}">${icon("close")}</button></header>
    <div class="create-body">
      <h1 class="t-title">${t("new_goal_title")}</h1><p class="lede t-bodySmall">${t("templates_lede")}</p>
      ${d.dhikr ? `<p class="t-label" style="margin:calc(-1 * var(--s-md)) 0 var(--s-lg);color:var(--c-accent)">${esc(t("for_dhikr", dhikrName(d.dhikr)))}</p>` : ""}
      <div class="templates">${Object.entries(TEMPLATES).map(([id, tp]) => `<button class="tpl-card pressable" data-action="pick-template" data-tpl="${id}">
        <span class="tpl-icon" aria-hidden="true">${tp.icon ? icon(tp.icon) : esc(t(tp.avatar))}</span>
        <span class="body"><span class="t-rowTitle">${t("tpl_" + id)}</span><span class="t-bodySmall sub">${t("tpl_" + id + "_ex")}</span></span>
        ${icon("chevron", "mirror")}</button>`).join("")}</div>
    </div>` };
  const tp = TEMPLATES[d.template];
  const dh = d.dhikr ? catalog.byKey[d.dhikr] : null;
  return { cls: "fixed no-nav", html: `
    <header class="topbar"><button class="icon-btn pressable" data-action="create-back" aria-label="${esc(t("back"))}">${icon("back", "mirror")}</button></header>
    <div class="create-body">
      <h1 class="t-title">${d.mode === "edit" ? t("edit") : t("tpl_" + d.template)}</h1>
      <p class="lede t-bodySmall">${d.mode === "edit" ? "" : t("tpl_" + d.template + "_ex")}</p>
      <div class="field-group"><div class="field-label t-label">${t("f_dhikr")}</div>
        <button class="field field-button pressable" data-action="open-picker" data-picker="dhikr" data-field="dhikr">
          <span class="${dh ? "" : "ph"}">${esc(dh ? dhikrName(d.dhikr) : t("tok_pick_dhikr"))}</span>${icon("chevron", "mirror")}</button></div>
      <div class="field-group"><label class="field-label t-label" for="f-count">${d.when === "once" ? t("f_count_total") : t("f_count")}</label>
        <input id="f-count" class="field t-input" inputmode="numeric" data-input="count" value="${esc(d.count)}">
        <div class="field-msg error" data-err="count"></div>
        <div class="chip-row" style="margin-top:var(--s-sm)">${quickCounts(d).map((n) => `<button class="filter-chip" aria-pressed="${String(n) === d.count}" data-action="quick-count" data-n="${n}">${fmtN(n)}</button>`).join("")}</div></div>
      ${tp.extra ? `<div class="field-group">${d.template === "total" ? "" : `<div class="field-label t-label">${t("f_when")}</div>`}${tp.extra(d)}</div>` : ""}
      <button class="expander t-sectionTitle" data-action="toggle-more" aria-expanded="${d.moreOpen}" style="margin-top:0">${t("more_options")}${icon("expand")}</button>
      ${d.moreOpen ? morePanel(d, { skipEnd: !!tp.skipEnd }) : ""}
      ${sharedQuestion(d)}
    </div>
    <footer class="create-foot with-preview"><div data-slot="preview">${previewHTML(d)}</div>
      <button class="btn main pressable" data-action="create-save" data-validate ${draftValid(d) ? "" : "disabled"}>${saveLabel(d)}</button></footer>` };
}

/* --- Dispatch --- */
function renderCreate() { return state.draft?.flow === "templates" ? renderTemplates() : renderWizard(); }
function openCreate(prefill = {}, flow = v("createFlow")) {
  stopAudio();
  state.draft = flow === "sentence" ? sdNew(prefill) : newDraft(flow, prefill);
  showDraft();
}
function openEdit(g) { stopAudio(); state.draft = v("createFlow") === "sentence" ? sdFromGoal(g) : goalToDraft(g); showDraft(); }
function showDraft() {
  if (state.draft.flow === "sentence") { state.overlay = { kind: "create" }; renderSentence(); }
  else navigate({ name: "create" });
}
function refreshCreate(transition = null) {
  if (!state.draft) return;
  if (state.draft.flow === "sentence") renderSentence(); else render(transition);
}
const createRoot = () => (state.draft?.flow === "sentence" ? document.querySelector("#overlay-host .overlay:not([data-closing]) .create-sheet") : currentScreen);
function refreshCreateValidation() {
  const host = createRoot(), d = state.draft;
  if (!host || !d) return;
  const e = errorsOf(d);
  host.querySelectorAll("[data-err]").forEach((el) => {
    const k = el.dataset.err, msg = e[k];
    if (k === "count" && !d.count) { el.textContent = ""; return; }
    el.textContent = msg || el.dataset.help || "";
    el.classList.toggle("error", !!msg);
    host.querySelector(`[data-input="${k}"]`)?.classList.toggle("error", !!msg);
  });
  const valid = d.flow === "wizard" ? STEP_DEFS[CREATE_STEPS()[d.step]].valid(d) : draftValid(d);
  host.querySelectorAll("[data-validate]").forEach((b) => (b.disabled = !valid));
  const pv = host.querySelector('[data-slot="preview"]');
  if (pv) pv.innerHTML = previewHTML(d);
}
function saveDraft() {
  const d = state.draft, isB = d.flow === "sentence";
  if (isB ? !sdValid(d) : !draftValid(d)) return;
  const base = d.goalId ? goalById(d.goalId) : null;
  const g = isB ? sdToGoal(d, base) : draftToGoal(d, base);
  if (base) state.goals[state.goals.indexOf(base)] = g; else state.goals.push(g);
  save();
  if (d.flow === "sentence") closeOverlay();
  state.draft = null;
  if (d.mode === "edit") { if (d.flow === "sentence") render(); else goBack(); toast(t("t_updated")); return; }
  state.goalsTab = "active"; state.stack = [];
  navigate({ name: "goals" }, d.flow === "sentence" && state.route.name === "goals" ? null : "pop");
  toast(t("t_saved")); flashGoal(g.id);
}
function createAction(a, el) {
  const d = state.draft;
  if (!d) return false;
  if (d.flow === "sentence") return sentenceAction(a, el);
  switch (a) {
    case "create-back":
      if (d.picker) { d.picker = null; refreshCreate(); return true; }
      if (d.flow === "templates" && d.template && d.mode === "create") { d.template = null; refreshCreate("pop"); return true; }
      if (d.flow !== "wizard" || d.step === 0 || d.mode === "edit") { state.draft = null; goBack(); return true; }
      d.step--; refreshCreate("pop"); return true;
    case "create-next": {
      if (d.step === CREATE_STEPS().length - 1) { saveDraft(); return true; }
      d.step++; haptic("tick"); refreshCreate("push"); return true;
    }
    case "wizard-skip": d.step = CREATE_STEPS().indexOf("review"); refreshCreate("push"); return true;
    case "create-save": saveDraft(); return true;
    case "close-create": closeOverlay(); return true;
    case "pick-dhikr":
      d.dhikr = el.dataset.key; d.query = "";
      if (d.flow === "wizard" && CREATE_STEPS()[d.step] === "dhikr") {
        refreshCreate();
        setTimeout(() => { if (state.draft === d && CREATE_STEPS()[d.step] === "dhikr") { d.step++; refreshCreate("push"); } }, 180);
      } else { d.picker = null; refreshCreate(); }
      return true;
    case "open-picker": d.picker = el.dataset.picker; d.pickerField = el.dataset.field; refreshCreate(d.flow === "templates" ? "push" : null); return true;
    case "close-picker": d.picker = null; refreshCreate(d.flow === "templates" ? "pop" : null); return true;
    case "quick-count": d[el.dataset.field || "count"] = el.dataset.n; refreshCreate(); return true;
    case "counts-mode": d.countsMode = el.dataset.val; refreshCreate(); return true;
    case "pick-template": {
      const tp = TEMPLATES[el.dataset.tpl];
      const fresh = newDraft(d.flow);
      const reset = Object.fromEntries(["when", "count", "weekdays", "ramadanPart", "minimum", "maximum", "end", "sessions", "streak", "moreOpen"].map((k) => [k, fresh[k]]));
      Object.assign(d, reset, structuredClone(tp.apply), { template: el.dataset.tpl });
      refreshCreate("push"); return true;
    }
    case "clear-query": d.query = ""; refreshCreate(); return true;
    case "pick-when": d.when = el.dataset.val; if (d.when === "once" && intOrNull(d.count) < 1000 && d.flow !== "wizard") d.count = "10000"; refreshCreate(); return true;
    case "toggle-weekday": { const w = d.weekdays, i = w.indexOf(el.dataset.wd); i >= 0 ? w.splice(i, 1) : w.push(el.dataset.wd); refreshCreate(); return true; }
    case "ramadan-part": d.ramadanPart = el.dataset.part; refreshCreate(); return true;
    case "toggle-more": {
      d.moreOpen = !d.moreOpen; refreshCreate();
      const p = d.moreOpen && !reduced() && createRoot()?.querySelector(".more-panel, .srows");
      if (p) { const s = spring("spatial"); p.animate([{ opacity: 0, transform: "translateY(-8px)" }, { opacity: 1, transform: "none" }], { duration: s.duration, easing: s.easing }); }
      return true;
    }
    case "toggle-session": { const s = d.sessions, i = s.indexOf(el.dataset.session); i >= 0 ? s.splice(i, 1) : s.push(el.dataset.session); refreshCreate(); return true; }
    case "streak-opt": d.streak = el.dataset.opt || el.dataset.val; if (d.picker === "streak") d.picker = null; refreshCreate(); return true;
    case "toggle-json": d.showJson = !d.showJson; refreshCreate(); return true;
  }
  return false;
}

/* ============================================================== 11. Overlays */
function openMenu(goalId, context) {
  const g = goalById(goalId);
  const paused = pausedOn(g, today());
  state.overlay = { kind: "menu", goalId, context };
  const counting = context === "counting";
  renderOverlay(`<div class="overlay" data-overlay><div class="scrim" data-action="close-overlay"></div>
    <div class="bsheet" role="dialog" aria-label="${esc(goalTitle(g))}"><div class="handle"></div>
      <div class="sheet-title t-cardTitle">${esc(goalTitle(g))}</div><div class="sheet-sub t-caption">${esc(chipText(g))}</div>
      ${counting ? `<button class="menu-row pressable" data-action="set-goal-from" data-dhikr="${esc(g.dhikr)}">${icon("add")}${t("set_goal")}</button>` : ""}
      ${counting ? `<button class="menu-row pressable" data-action="undo">${icon("back", "mirror")}${t("undo")}</button><button class="menu-row pressable" data-action="reset-today">${icon("close")}${t("reset_today")}</button>` : ""}
      <button class="menu-row pressable" data-action="edit-goal">${icon("tune")}${t("edit")}</button>
      <button class="menu-row pressable" data-action="toggle-pause">${icon(paused ? "play" : "pause")}${paused ? t("resume") : t("pause")}</button>
      <button class="menu-row danger pressable" data-action="ask-delete">${icon("delete")}${t("delete")}</button>
    </div></div>`, "sheet");
}
function openDeleteDialog(goalId) {
  state.overlay = { kind: "dialog", goalId };
  renderOverlay(`<div class="overlay center" data-overlay><div class="scrim" data-action="close-overlay"></div>
    <div class="dialog" role="alertdialog" aria-labelledby="dlg-t"><h2 id="dlg-t" class="t-cardTitle">${t("delete_title")}</h2><p class="t-body">${t("delete_body")}</p>
      <div class="actions"><button class="btn text" data-action="close-overlay">${t("cancel")}</button><button class="btn error pressable" data-action="confirm-delete">${t("delete_btn")}</button></div></div></div>`, "dialog");
}
function renderOverlay(html, kind) {
  const host = document.getElementById("overlay-host");
  host.innerHTML = html;
  const panel = host.querySelector(".bsheet, .dialog"), scrim = host.querySelector(".scrim");
  if (reduced()) { host.firstElementChild.animate([{ opacity: 0 }, { opacity: 1 }], { duration: MOTION.duration.color, easing: "linear" }); return; }
  scrim.animate([{ opacity: 0 }, { opacity: 1 }], { duration: MOTION.duration.color, easing: "linear" });
  if (kind === "sheet") { const s = spring("spatial"); panel.animate([{ transform: "translateY(100%)" }, { transform: "none" }], { duration: s.duration, easing: s.easing }); }
  else panel.animate([{ opacity: 0, transform: "scale(.96)" }, { opacity: 1, transform: "none" }], { duration: MOTION.duration.short, easing: MOTION.easing.decelerate });
}
function closeOverlay() {
  const host = document.getElementById("overlay-host"), el = host.firstElementChild;
  if (el) el.dataset.closing = "1";
  if (state.overlay?.kind === "create") state.draft = null;
  state.overlay = null;
  if (!el) return;
  const panel = el.querySelector(".bsheet");
  const a = el.animate([{ opacity: 1 }, { opacity: 0 }], { duration: MOTION.duration.color, easing: "linear", fill: "forwards" });
  if (panel && !reduced()) panel.animate([{ transform: "none" }, { transform: "translateY(40%)" }], { duration: MOTION.duration.short, easing: MOTION.easing.accelerate, fill: "forwards" });
  a.onfinish = () => { if (host.firstElementChild === el) host.innerHTML = ""; };
}
let toastTimer;
function toast(msg) {
  const host = document.getElementById("toast-host");
  host.innerHTML = `<div class="toast" role="status">${esc(msg)}</div>`;
  const el = host.firstElementChild;
  if (["counting", "create"].includes(state.route.name)) el.style.bottom = "calc(34px + var(--s-lg))";
  el.animate([{ opacity: 0, transform: reduced() ? "none" : "translateY(8px)" }, { opacity: 1, transform: "none" }], { duration: MOTION.duration.short, easing: MOTION.easing.decelerate });
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => { const a = el.animate([{ opacity: 1 }, { opacity: 0 }], { duration: MOTION.duration.color, fill: "forwards" }); a.onfinish = () => el.remove(); }, 2200);
}

/* ============================================================== 12. Motion */
const reduced = () => state.settings.reducedMotion;
let currentScreen = null;
function navigate(route, kind = "push") {
  stopAudio();
  if (kind === "push") state.stack.push(state.route);
  state.route = route;
  render(kind);
}
function goBack() {
  const prev = state.stack.pop() || { name: "home" };
  stopAudio();
  state.route = prev;
  render("pop");
}
function render(transition = null) {
  const host = document.getElementById("screen-host");
  const def = screens[state.route.name]();
  const el = document.createElement("div");
  el.className = `screen current ${def.cls || ""}`;
  el.innerHTML = def.html;
  const old = currentScreen;
  if (!transition && old) { const st = old.scrollTop; host.replaceChild(el, old); el.scrollTop = st; currentScreen = el; renderNav(); return; }
  host.appendChild(el);
  currentScreen = el;
  renderNav();
  if (!old) return;
  old.classList.remove("current");
  const cleanup = () => old.remove();
  if (reduced() || !transition) {
    el.animate([{ opacity: 0 }, { opacity: 1 }], { duration: MOTION.duration.color, easing: "linear" }).onfinish = cleanup;
    return;
  }
  const D = MOTION.duration, E = MOTION.easing.emphasized;
  if (transition === "push") {
    const m = MOTION.pagePush;
    el.animate([{ transform: `scale(${m.enterScaleFrom})`, opacity: m.enterFadeFrom }, { transform: "none", opacity: 1 }], { duration: D.page, easing: E });
    old.style.zIndex = -1;
    old.animate([{ transform: "none", filter: "brightness(1)", borderRadius: "0" }, { transform: `scale(${m.exitScaleTo})`, filter: `brightness(${1 - m.depthDim})`, borderRadius: "32px" }], { duration: D.page, easing: E, fill: "forwards" }).onfinish = cleanup;
  } else if (transition === "pop") {
    const m = MOTION.pagePop;
    host.insertBefore(el, old);
    el.animate([{ transform: `scale(${m.enterScaleFrom})`, opacity: m.enterFadeFrom }, { transform: "none", opacity: 1 }], { duration: D.page, easing: E });
    old.animate([{ transform: "none", opacity: 1 }, { transform: `scale(${m.exitScaleTo})`, opacity: 0 }], { duration: D.short, easing: E, fill: "forwards" }).onfinish = cleanup;
  } else {
    const m = MOTION.tabSwitch;
    el.animate([{ transform: `scale(${m.enterScaleFrom})`, opacity: m.enterFadeFrom }, { transform: "none", opacity: 1 }], { duration: D.medium, easing: E });
    old.animate([{ transform: "none", opacity: 1 }, { transform: `scale(${m.exitScaleTo})`, opacity: 0 }], { duration: D.fade, easing: "linear", fill: "forwards" }).onfinish = cleanup;
  }
  if (state.route.name === "goals") listAppear(el);
}
function listAppear(root) {
  if (reduced()) return;
  const m = MOTION.listAppear;
  [...root.querySelectorAll(".goal-card")].slice(0, m.maxStaggered).forEach((c, i) =>
    c.animate([{ opacity: 0, transform: `translateY(${m.offset}px)` }, { opacity: 1, transform: "none" }], { duration: MOTION.duration.short, easing: MOTION.easing.decelerate, delay: i * m.stagger, fill: "backwards" }));
}
function flashGoal(id) {
  setTimeout(() => {
    const el = currentScreen?.querySelector(`.goal-card[data-id="${id}"]`);
    if (!el) return;
    el.scrollIntoView({ block: "center", behavior: reduced() ? "auto" : "smooth" });
    el.animate([{ boxShadow: "0 0 0 3px var(--c-accent)" }, { boxShadow: "0 0 0 0 transparent" }], { duration: 1200, easing: "linear" });
  }, MOTION.duration.page);
}
function renderNav() {
  const host = document.getElementById("nav-host");
  const name = state.route.name;
  if (!TABS.includes(name)) { host.innerHTML = ""; return; }
  const prev = host.querySelector('[aria-selected="true"]')?.dataset.tab;
  host.innerHTML = `<nav class="navbar" role="tablist" aria-label="Main">${TABS.map((k) => `<button role="tab" aria-selected="${k === name}" data-action="tab" data-tab="${k}">
    <span class="pill">${icon(k)}</span><span class="t-navLabel">${t("nav_" + k)}</span></button>`).join("")}</nav>`;
  if (prev && prev !== name && !reduced()) {
    const btn = host.querySelector(`[data-tab="${name}"]`), pill = btn.querySelector(".pill"), ic = pill.querySelector(".icon");
    const soft = spring("bouncySoft"), b = spring("bouncy");
    pill.animate([{ transform: "scaleX(0.7)", opacity: 0.4 }, { transform: "none", opacity: 1 }], { duration: soft.duration, easing: soft.easing });
    ic.animate([{ transform: "scale(1)" }, { transform: "scale(1.1)", offset: 0.25 }, { transform: "scale(1)" }], { duration: b.duration + 80, easing: b.easing });
  }
}
/* press: scale down while held, spring back on release (motion.json press) */
function pressDown(el) {
  if (reduced() || !el) return;
  const scale = el.matches(".card, .goal-card, .home-row, .tile, .dhikr-row, .option-row, .menu-row") ? MOTION.press.cardScale : MOTION.press.buttonScale;
  el._press?.cancel();
  el._press = el.animate([{ transform: "scale(1)" }, { transform: `scale(${scale})` }], { duration: MOTION.duration.fade, easing: MOTION.easing.emphasized, fill: "forwards" });
  el._pressScale = scale;
}
function pressUp(el) {
  if (!el?._press) return;
  const s = spring("spatialFast"), from = el._pressScale;
  el._press.cancel(); el._press = null;
  el.animate([{ transform: `scale(${from})` }, { transform: "scale(1)" }], { duration: s.duration, easing: s.easing });
}

/* --- Counting --- */
function haptic(kind) {
  const pattern = { tick: 8, threshold: 20, success: [20, 60, 40] }[kind];
  const ok = typeof navigator.vibrate === "function" && navigator.vibrate(pattern);
  const log = document.getElementById("haptic-log");
  if (log) log.textContent = `${new Date().toLocaleTimeString()} haptic: ${kind}${ok ? "" : " (no vibrate API here)"}`;
}
function setCount(g, session, value) {
  const td = today();
  const [from] = windowOf(g, td);
  const before = countIn(g, from, addDays(td, -1), session === undefined ? null : session);
  const todayValue = Math.max(0, value - before);
  const entry = g.count_entries.find((c) => c.date === td && c.session === session);
  if (entry) entry.count = todayValue; else if (todayValue) g.count_entries.push({ date: td, session, count: todayValue });
  if (entry && !entry.count) g.count_entries.splice(g.count_entries.indexOf(entry), 1);
}
/* counts: "shared" — a count on one goal also counts for the other shared goals on the same
   dhikr (prototype model: mirrored entries, goals without sessions, while both are active). */
function shareDelta(g, delta) {
  if (!delta || g.counts !== "shared" || g.sessions.length) return;
  const td = today();
  for (const o of state.goals) {
    if (o === g || o.dhikr !== g.dhikr || o.counts !== "shared" || o.sessions.length || !inActive(o, td)) continue;
    const entry = o.count_entries.find((c) => c.date === td && c.session === null);
    if (entry) entry.count = Math.max(0, entry.count + delta); else if (delta > 0) o.count_entries.push({ date: td, session: null, count: delta });
  }
}
function increment(by = 1) {
  const g = goalById(state.route.goalId);
  if (!g) return;
  const td = today(), session = g.sessions.length ? state.session : null, p = policyOf(g, session);
  const before = progressOf(g, td, session);
  if (p.maximum != null && before >= p.maximum) { haptic("threshold"); toast(t("t_cap", fmtN(p.maximum))); popCircle(true); return; }
  setCount(g, session, before + by);
  shareDelta(g, by);
  const after = before + by;
  save();
  if (p.target && before < p.target && after >= p.target) {
    haptic("success");
    if (!g.sessions.length) toast(t("t_target"));
    else toast(g.sessions.every((x) => countOn(g, td, x.id) >= (x.count_policy.target ?? 1)) ? t("t_all_sessions") : t("t_session_done", capFirst(sessionLabel(session))));
  }
  else if (p.minimum && before < p.minimum && after >= p.minimum) { haptic("threshold"); toast(t("t_min")); }
  else haptic("tick");
  updateCounting(before, after);
  popCircle();
}
/* Sessions on the counter (decision B): manual pills. The current (or next) session is
   pre-selected by time; any session can be picked at any time; windows only guide. */
const PRAYER_TIMES = { fajr: "05:10", dhuhr: "12:25", asr: "15:42", maghrib: "18:05", isha: "19:20" }; // stand-in times for today
const NAMED_SESSION_TIMES = { morning: "06:00", evening: "17:00", before_sleep: "21:00" };
const nowHM = () => state.settings.now || new Date().toTimeString().slice(0, 5);
function sessionWindow(id) {
  const s = parseSession(id);
  if (s.kind === "prayer") return [PRAYER_TIMES[s.prayer], null];
  if (s.kind === "time") return [s.time, null];
  if (s.kind === "between") return [s.from, s.to];
  if (s.kind === "named") return [NAMED_SESSION_TIMES[s.id] || "00:00", null];
  return ["00:00", null];
}
function currentSessionId(g) {
  const now = nowHM();
  const list = g.sessions.map((x) => ({ id: x.id, w: sessionWindow(x.id) })).sort((a, b) => (a.w[0] < b.w[0] ? -1 : 1));
  // a session's window runs from its start to its own end (between) or the next session's start
  const ends = list.map((x, i) => x.w[1] || list[i + 1]?.w[0] || "24:00");
  const cur = list.find((x, i) => x.w[0] <= now && now < ends[i]);
  return (cur || list.find((x) => x.w[0] > now) || list.at(-1)).id;
}
const capFirst = (x) => x.charAt(0).toLocaleUpperCase() + x.slice(1);
function sessionPills(g, selected, td) {
  const done = g.sessions.filter((x) => countOn(g, td, x.id) >= (x.count_policy.target ?? 1)).length;
  const cur = currentSessionId(g);
  return `<div class="session-bar" data-slot="sessions">
    <div class="seg counter-seg" role="tablist" aria-label="${esc(t("f_sessions"))}">${g.sessions.map((x) => {
      const n = progressOf(g, td, x.id), tg = x.count_policy.target, met = tg != null && n >= tg;
      return `<div class="pill-wrap"><button class="pressable ${met ? "met" : ""}" role="tab" aria-selected="${x.id === selected}" data-action="session" data-session="${x.id}">
        <span class="pill-label">${esc(capFirst(sessionLabel(x.id)))}</span><span class="pill-count">${met ? icon("check", "small") : ""}${tg != null ? `${fmtN(n)}/${fmtN(tg)}` : fmtN(n)}</span></button><span class="bar"></span></div>`;
    }).join("")}</div>
    <div class="session-state t-caption">${esc(t("sessions_done", done, g.sessions.length))}${cur !== selected ? ` · ${esc(t("session_now", sessionLabel(cur)))}` : ""}</div>
  </div>`;
}
function updateCounting(before, after) {
  const g = goalById(state.route.goalId), root = currentScreen;
  if (!g || !root) return;
  const td = today(), session = g.sessions.length ? state.session : null, p = policyOf(g, session);
  // number roll (countTap: numberTransition roll)
  const num = root.querySelector('[data-slot="num"]');
  num.querySelectorAll(".out").forEach((n) => n.remove());
  const old = num.firstElementChild, fresh = document.createElement("span");
  fresh.textContent = after;
  if (old) { old.classList.add("out"); num.appendChild(fresh); } else num.appendChild(fresh);
  const up = after >= before ? 1 : -1;
  if (reduced()) {
    old?.animate([{ opacity: 1 }, { opacity: 0 }], { duration: MOTION.duration.color, fill: "forwards" }).finished.then(() => old.remove()).catch(() => {});
    fresh.animate([{ opacity: 0 }, { opacity: 1 }], { duration: MOTION.duration.color });
  } else {
    const s = spring("spatial");
    old?.animate([{ transform: "none", opacity: 1 }, { transform: `translateY(${-60 * up}%)`, opacity: 0 }], { duration: MOTION.duration.short, easing: MOTION.easing.emphasized, fill: "forwards" }).finished.then(() => old.remove()).catch(() => {});
    fresh.animate([{ transform: `translateY(${60 * up}%)`, opacity: 0 }, { transform: "none", opacity: 1 }], { duration: s.duration, easing: s.easing });
  }
  // ring fill (ringFill: spatial spring; countComplete: spatialSlow)
  const ringHost = root.querySelector('[data-slot="ring"]');
  const oldArc = ringHost.querySelector(".r-arc"), oldDash = parseFloat(oldArc.getAttribute("stroke-dasharray"));
  const svg = ringHost.querySelector("svg");
  const tmp = document.createElement("div"); tmp.innerHTML = ringSVG(264, 10, after, p);
  ringHost.replaceChild(tmp.firstElementChild, svg);
  const arc = ringHost.querySelector(".r-arc"), newDash = parseFloat(arc.getAttribute("stroke-dasharray"));
  const crossedLap = p.target && (before <= p.target) !== (after <= p.target);
  if (!reduced() && !crossedLap && oldDash !== newDash) {
    const s = spring(p.target && after === p.target ? "spatialSlow" : "spatial");
    arc.setAttribute("opacity", 1);
    arc.animate([{ strokeDasharray: `${oldDash} 100` }, { strokeDasharray: `${newDash} 100` }], { duration: s.duration, easing: s.easing });
  } else if (crossedLap && !reduced()) {
    ringHost.querySelector(".r-lap").animate([{ opacity: 0 }, { opacity: 1 }], { duration: MOTION.duration.color, easing: "linear" });
  }
  // chip + streak + label (contentSwap)
  const chip = root.querySelector('[data-slot="cchip"]'), next = counterChip(g, after, p, td);
  if (chip.textContent !== next) { chip.textContent = next; chip.animate([{ opacity: 0 }, { opacity: 1 }], { duration: MOTION.duration.color, easing: "linear" }); }
  root.querySelector('[data-slot="streak"]').innerHTML = streakHTML(g, td);
  const pills = root.querySelector('[data-slot="sessions"]');
  if (pills) { const sc = pills.querySelector(".seg")?.scrollLeft || 0; pills.outerHTML = sessionPills(g, session, td); root.querySelector('[data-slot="sessions"] .seg').scrollLeft = sc; }
  root.querySelector('[data-counter="circle"]').setAttribute("aria-label", `${t("tap_circle")}: ${after}`);
}
function popCircle(blocked = false) {
  const c = currentScreen?.querySelector('[data-counter="circle"]');
  if (!c || reduced()) return;
  c._press?.cancel(); c._press = null;
  if (blocked) { c.animate([{ transform: "translateX(0)" }, { transform: "translateX(-6px)" }, { transform: "translateX(6px)" }, { transform: "translateX(0)" }], { duration: MOTION.duration.short, easing: "linear" }); return; }
  const b = spring("bouncy"), lead = 70;
  c.animate([
    { transform: `scale(${MOTION.press.buttonScale})`, easing: MOTION.easing.emphasized },
    { transform: `scale(${MOTION.countTap.popScale})`, offset: lead / (lead + b.duration), easing: b.easing },
    { transform: "scale(1)" },
  ], { duration: lead + b.duration });
}
let audioTimer = null;
function toggleAudio() {
  if (audioTimer) return stopAudio();
  audioTimer = setInterval(() => increment(1), 1200);
  const b = currentScreen.querySelector('[data-slot="audio"]');
  b.innerHTML = `${icon("pause")}<span>${t("stop_audio")}</span>`;
}
function stopAudio() {
  if (!audioTimer) return;
  clearInterval(audioTimer); audioTimer = null;
  const b = currentScreen?.querySelector('[data-slot="audio"]');
  if (b) b.innerHTML = `${icon("play")}<span>${t("start_audio")}</span>`;
}

/* ============================================================== 13. Lab */
const NOTES = `
<div class="notes">
  <div class="tq"><strong>Token question: the gold ring.</strong> The approved counting design draws progress in amber/gold
    (<span class="swatch" style="background:#D9A520"></span><code>#D9A520</code> light,
    <span class="swatch" style="background:#E4B442"></span><code>#E4B442</code> dark here, both guessed). It isn't in
    <code>colors.json</code>' palette, and <code>npm test</code> rejects off-palette role values. Options: add a palette colour and a role
    such as <code>progressHighlight</code> (needs a 3 : 1 contrast pair against background, surface and the pale circle), or use
    <code>progress</code> (try the "Counter ring colour" variant). Everything else uses token colours.</div>

  <h3>Minimum / target display</h3>
  <ul>
    <li>The design shows one arc that runs to the target, the chip "minimum 70" and "target 100" in the goal chip. How the minimum shows on the ring itself isn't designed. Variants: a minimum dot, and gold → green once the minimum is met.</li>
    <li>Past the target the ring is a grey full lap plus a gold overflow arc. The grey isn't named; <code>outlineStrong</code> is used. A second overflow lap (count over 2× target) just stays full here.</li>
    <li>The chip under the counter is "minimum 70" in the design. Draft: it shows the next threshold (minimum → target → "+10 over target"), with a variant for the static chip.</li>
    <li>At exactly the target the ring is one full gold lap (not grey), so reaching the target reads as done.</li>
    <li>A cap (maximum) blocks further taps with a shake, a threshold haptic and a toast. Not designed.</li>
  </ul>

  <h3>Copy and chips</h3>
  <ul>
    <li>The design's chip copy isn't systematic ("Daily 100" vs "minimum 70, target 100 daily" vs "10 every thursday"). The prototype reproduces those exactly and invents the rest (weekday lists, white days, caps, sessions). Needs a copy system and plural rules for ar and ml.</li>
    <li>Capitalisation differs between chips ("Daily", "minimum", "Every", "every"). Kept as designed.</li>
    <li>"70000 times" has no digit grouping in the design; variant for grouped digits. Arabic mode uses Western digits; Arabic-Indic digits are an open question.</li>
    <li>Upcoming second line: "1 ramadan" and "5 thurdays" (typo in the design) are read as occurrences left. They could also mean "starts 1 Ramadan" and "5 Thursdays done"; variant shows the next due date instead.</li>
    <li>Target 1 drops the number ("Every Ramadan 1-10 daily"), which is how the Ramadan design chip is reproduced.</li>
  </ul>

  <h3>Model and data assumptions</h3>
  <ul>
    <li>A goal's title is its dhikr's title, except "Ramadan first 10 dhikr" and "Dua Kumayl", which need a goal name (the schema has none) or a custom dhikr. Dua Kumayl isn't in the catalog, so it's a stand-in custom dhikr.</li>
    <li>Rules are a simplified re-implementation for the prototype, not the fixture-tested domain code: Hijri dates come from <code>Intl</code> islamic-umalqura (no corrections, midnight reset, no Maghrib reset), week start is Monday.</li>
    <li>With sessions, list rings show the sum across sessions against the summed targets; the counter shows one session at a time. Each session copies the goal's count policy (the draft has no per-session numbers yet).</li>
    <li>A cumulative goal that reaches its total moves to History at once (completion "when target reached"). It might deserve a "done today" moment on Today's goals first.</li>
    <li>"Once, with a total" maps to <code>one_time</code> + <code>cumulative_total</code> + <code>when_target_reached</code>. The design's 70000/4444 goals are modelled as <code>every_day</code> + <code>cumulative_total</code> (as in the streak fixture).</li>
    <li>Streak threshold defaults: minimum when set, else target; cumulative goals use any count.</li>
    <li>A paused goal moves to a "Paused" section on Active (not in the design). Resume ends the pause yesterday.</li>
    <li>"Ramadan → First 10" isn't a preset (presets have whole month, last ten and odd nights), so it saves as a custom yearly Hijri range.</li>
  </ul>

  <h3>Create flows (A / B / C)</h3>
  <ul>
    <li>All three edit one draft and save through the same <code>draftToGoal</code>, so the saved goal is identical whichever flow made it. Edit opens the goal in the current flow.</li>
    <li>Entry points: My Goals +, "Set a goal" on the counting page's ⋮ menu, and "Set a goal" on each dhikr of the Library stub (both pre-fill the dhikr; the wizard then starts at How many?).</li>
    <li>B was reworked for advanced goals (below). Its tokens have a 48 touch target, and pickers open as a second level so the sheet keeps one height.</li>
    <li>C's Ramadan and White days cards use a text avatar ("R", "13"): <code>icons.json</code> has no moon or calendar icon.</li>
    <li>"In total" in B and C defaults to 10,000 / 70,000 when the number was a daily-sized one.</li>
  </ul>

  <h3>B, the sentence: what doesn't fit</h3>
  <ul>
    <li>Session timing (after a prayer, at a time, between two times) isn't in the goal-model session (<code>{ id, count_policy }</code>), so it's encoded in the id: <code>after_fajr</code>, <code>at_0730</code>, <code>between_1800_2000</code>. A real schema needs a session kind.</li>
    <li>A minimum or cap per session has no room in "[100] after [Fajr]", so minimum and cap are offered only without sessions (and sessions only without them).</li>
    <li>"Days per period" with a narrower schedule (3 of my Mon–Fri) has no sentence; only the Shawwal occasion combines the two. A period total also resets the schedule to every day.</li>
    <li>The active period is "until a date" or "for N days", not both, though the schema allows both (the earlier wins).</li>
    <li>Yearly schedules edit one date or one range; several ranges come only from occasions (Ramadan odd nights).</li>
    <li>A cumulative goal saved from B uses <code>one_time</code>; the seeded 70000/4444 goals use <code>every_day</code>, so editing them in B changes that.</li>
    <li>For cumulative goals the streak offers "any count" only; "the target" would compare one day with the whole total.</li>
    <li>"Read" (dua) and "Say" are the same verb in Malayalam here. Malayalam covers the sentence sheet only; the rest of the UI falls back to English. Arabic and Malayalam wording need a native review.</li>
    <li>Not in the sentence: pausing (a menu action), Hijri corrections and the day reset (account settings), reminders (a disabled "coming soon" row).</li>
    <li>The day grids are 48 tall but about 45 wide, under the 48 touch target width.</li>
  </ul>

  <h3>Sessions on the counter (decision B)</h3>
  <ul>
    <li>Manual pills under the header, each with its own progress. The session whose window holds the current time (or the next one) is pre-selected; the Lab's "Time of day" moves the clock. Any session can be picked at any time, including a missed one; windows only guide.</li>
    <li>A session's window runs from its start to its own end ("between") or to the next session's start. Prayer times are fixed stand-ins (Fajr 05:10, Dhuhr 12:25, Asr 15:42, Maghrib 18:05, Isha 19:20).</li>
    <li>The day is met only when every session meets its own number, so the streak needs all of them. Home and My Goals rings show the day's combined progress.</li>
  </ul>

  <h3>Shared counts (decision C)</h3>
  <ul>
    <li>When another live goal uses the same dhikr, every flow asks "Count X from your other goal too?" with shared pre-selected. Stored as <code>counts: "shared" | "dedicated"</code> on the goal; the count history moved to <code>count_entries</code> (state key bumped to v2, so saved prototype state reset).</li>
    <li>Prototype model: a count on a shared goal is mirrored into the other shared goals on that dhikr for today (goals without sessions, while active). How the real model stores this, and whether history before the new goal counts, is open.</li>
  </ul>

  <h3>Design gaps</h3>
  <ul>
    <li>No timer icon in <code>icons.json</code>, so the timer button is a text label; no edit/pencil icon (<code>tune</code> used); no backspace icon (the pad's key says "Delete"). The list button uses the <code>goals</code> icon. What the timer and list buttons do isn't designed (toasts).</li>
    <li>"Start audio count" is simulated: +1 every 1.2 s until stopped.</li>
    <li>"Aa" cycles three Arabic sizes (24, 28, 32); only 24 (<code>quran</code>) is a token.</li>
    <li>Ring sizes: My Goals uses 48 (no token; <code>ringSmall</code> is 36, used on Home). The counter circle (228), ring (264) and its stroke (10) have no tokens.</li>
    <li>The streak glyph is 16 px (no token) and the goal chip uses <code>caption</code> text with xs × sm padding, tighter than the tag chip spec, to fit the design.</li>
    <li>Counting in RTL mirrors the ring (it fills counter-clockwise). Unconfirmed.</li>
    <li>No compact top bar when the large title scrolls away; no swipe-to-dismiss on sheets; toasts aren't a spec'd component.</li>
    <li>Home's Next prayer card and collection tiles are static stand-ins.</li>
    <li>The option rows in "When?" have no avatar circle (the spec has one, for language rows).</li>
    <li>Strings: en and ar only (ml missing), kept in <code>STRINGS</code> in prototype.js, not localization resources.</li>
  </ul>
</div>`;
function renderLab() {
  const s = state.settings;
  const seg = (key, opts) => `<span class="seg-mini">${Object.entries(opts).map(([val, label]) => `<button data-lab="${key}" data-val="${val}" aria-pressed="${String(key === "lang" ? lang() : s[key]) === val}">${label}</button>`).join("")}</span>`;
  const fath = state.goals.find((g) => g.dhikr === "swalath-al-fathimiyya");
  const ram = gregorianOfHijri(hijri(s.today).m < 9 ? hijri(s.today).y : hijri(s.today).y + 1, 9, 1, s.today);
  const white = findDate((d) => hijri(d).d === 13, addDays(s.today, 1), 40);
  const thu = findDate((d) => weekday(d) === "thursday", addDays(s.today, 1), 8);
  document.getElementById("lab-controls").innerHTML = `
    <h2>Look</h2>
    <div class="row"><label>Theme</label>${seg("theme", { light: "Light", dark: "Dark" })}</div>
    <div class="row"><label>Language</label>${seg("lang", { en: "English", ar: "العربية (RTL)", ml: "മലയാളം" })}</div>
    <div class="row"><label>Reduced motion</label>${seg("reducedMotion", { false: "Off", true: "On" })}</div>
    <h2>Today</h2>
    <div class="row"><label for="lab-today">Effective practice day</label><input id="lab-today" type="date" value="${s.today}"></div>
    <div class="row"><label for="lab-now">Time of day (picks the current session)</label><input id="lab-now" type="time" value="${s.now || ""}"></div>
    <div class="msg">Hijri: ${esc(fmtHijriEn(s.today))} · ${weekday(s.today)}</div>
    <div class="btns" style="margin-top:8px">
      <button data-today="${addDays(s.today, -1)}">− 1 day</button><button data-today="${addDays(s.today, 1)}">+ 1 day</button>
      ${thu ? `<button data-today="${thu}">Next Thursday</button>` : ""}${white ? `<button data-today="${white}">Next white day</button>` : ""}
      ${ram ? `<button data-today="${ram}">1 Ramadan</button>` : ""}<button data-today="${localToday()}">Real today</button>
    </div>
    <h2>Jump to</h2>
    <div class="btns">
      <button data-jump="home">Home</button><button data-jump="goals">My Goals</button><button data-jump="history">History</button>
      <button data-jump="create">Create</button><button data-jump="menu">⋮ menu</button><button data-jump="library">Library</button>
    </div>
    <h2>Create flow</h2>
    <div class="btns">${Object.entries(VARIANTS.createFlow.options).map(([k, label]) => `<button data-try="${k}" class="${v("createFlow") === k ? "primary" : ""}">Try ${esc(label)}</button>`).join("")}</div>
    <div class="msg">Opens the create flow from My Goals in that variant (and sets <code>createFlow</code>).</div>
    ${fath ? `<div class="btns" style="margin-top:6px">${[0, 13, 70, 99, 100, 110].map((n) => `<button data-jump="count" data-n="${n}">Counter at ${n}</button>`).join("")}</div>` : ""}
    <h2>Haptics</h2>
    <div class="haptic-log" id="haptic-log">Each count fires navigator.vibrate when available; logged here.</div>
    <h2>Data</h2>
    <div class="btns"><button data-labaction="reset">Reset goals to the seed</button><button data-labaction="reset-all">Reset everything</button></div>`;
  document.getElementById("lab-variants").innerHTML = `<p class="sub" style="margin-top:0">From <code>VARIANTS</code> in prototype.js: add an entry there to get a switch here.</p>` +
    Object.entries(VARIANTS).map(([key, def]) => `<div class="variant"><div class="name">${esc(def.label)} <code>${key}</code></div><div class="note">${esc(def.note)}</div>
      <span class="seg-mini">${Object.entries(def.options).map(([val, label]) => `<button data-variant="${key}" data-val="${val}" aria-pressed="${v(key) === val}">${esc(label)}</button>`).join("")}</span></div>`).join("");
  document.getElementById("lab-notes").innerHTML = NOTES;
  if (state.labTab !== "data" || !document.getElementById("lab-json")) renderLabData();
}
const fmtHijriEn = (ds) => { const h = hijri(ds); return `${h.d} ${HIJRI_MONTHS.en[h.m - 1]} ${h.y}`; };
function renderLabData() {
  document.getElementById("lab-data").innerHTML = `
    <p class="sub" style="margin-top:0">The goals, in the goal-model shape plus prototype fields (<code>id</code>, <code>dhikr</code>, <code>name</code>, <code>preset</code>, <code>count_entries</code>, <code>counts</code>: shared | dedicated). Edit and apply.</p>
    <textarea id="lab-json" spellcheck="false">${esc(JSON.stringify(state.goals, null, 1))}</textarea>
    <div class="btns" style="margin-top:8px"><button class="primary" data-labaction="apply-json">Apply</button><button data-labaction="refresh-json">Reload from state</button><button data-labaction="reset">Reset to seed</button></div>
    <div class="msg" id="lab-json-msg"></div>`;
}
function applyJSON() {
  const msg = document.getElementById("lab-json-msg");
  try {
    const goals = JSON.parse(document.getElementById("lab-json").value);
    if (!Array.isArray(goals)) throw new Error("Expected an array of goals");
    goals.forEach((g, i) => {
      for (const k of ["id", "dhikr", "schedule", "active_period", "count_policy", "sessions", "requirement", "completion", "count_entries"]) if (!(k in g)) throw new Error(`Goal ${i}: missing "${k}"`);
      g.paused ||= [];
      g.counts ||= "shared";
    });
    state.goals = goals; save(); render(); msg.className = "msg"; msg.textContent = `Applied ${goals.length} goals.`;
  } catch (e) { msg.className = "msg err"; msg.textContent = e.message; }
}
function applySettings() {
  const phone = document.getElementById("phone"), s = state.settings;
  phone.dataset.theme = s.theme;
  phone.dir = lang() === "ar" ? "rtl" : "ltr";
  phone.lang = lang();
  phone.classList.toggle("reduced", !!s.reducedMotion);
}

/* ============================================================== 14. Events + boot */
function handleAction(el, e) {
  const a = el.dataset.action, id = el.dataset.id;
  if (createAction(a, el)) return;
  switch (a) {
    case "tab": {
      const tab = el.dataset.tab;
      if (tab === state.route.name) return;
      haptic("tick"); state.stack = []; state.route = { name: tab }; stopAudio(); render("tab"); return;
    }
    case "goals-tab": if (state.goalsTab !== el.dataset.tab) { state.goalsTab = el.dataset.tab; render(); listAppear(currentScreen); } return;
    case "open-goal": state.session = null; navigate({ name: "counting", goalId: id }); return;
    case "back": goBack(); return;
    case "add-goal": openCreate(); return;
    case "set-goal-from": { const dhikr = el.dataset.dhikr; if (state.overlay) closeOverlay(); openCreate({ dhikr }); return; }
    case "goal-menu": e.stopPropagation(); openMenu(id, el.dataset.context); return;
    case "close-overlay": closeOverlay(); return;
    case "edit-goal": { const gid = state.overlay.goalId; closeOverlay(); openEdit(goalById(gid)); return; }
    case "toggle-pause": {
      const g = goalById(state.overlay.goalId), td = today(), open = g.paused.find((p) => td >= p.from && (p.to == null || td <= p.to));
      if (open) { if (open.from >= td) g.paused.splice(g.paused.indexOf(open), 1); else open.to = addDays(td, -1); toast(t("t_resumed")); }
      else { g.paused.push({ from: td, to: null }); toast(t("t_paused")); }
      save(); closeOverlay(); render(); return;
    }
    case "ask-delete": { const gid = state.overlay.goalId; openDeleteDialog(gid); return; }
    case "confirm-delete": {
      const gid = state.overlay.goalId;
      state.goals = state.goals.filter((g) => g.id !== gid); save(); closeOverlay(); toast(t("t_deleted"));
      if (state.route.name === "counting") goBack(); else render();
      return;
    }
    case "undo": case "reset-today": {
      const g = goalById(state.overlay.goalId), session = g.sessions.length ? state.session : null, before = progressOf(g, today(), session);
      const todayCount = countOn(g, today(), session);
      const after = a === "undo" ? Math.max(before - (todayCount > 0 ? 1 : 0), 0) : before - todayCount;
      setCount(g, session, after); shareDelta(g, after - before); save(); closeOverlay(); updateCounting(before, after); toast(a === "undo" ? t("t_undo") : t("t_reset")); return;
    }
    case "text-size": state.settings.arabicSize = (state.settings.arabicSize + 1) % 3; save(); currentScreen.querySelector(".arabic-card")?.setAttribute("data-size", state.settings.arabicSize); return;
    case "audio": toggleAudio(); return;
    case "timer": toast(t("t_timer")); return;
    case "count-list": toast(t("t_list")); return;
    case "toast-placeholder": toast(t("placeholder")); return;
    case "session": state.session = el.dataset.session; render(); return;
  }
}
function boot() {
  load();
  applySettings();
  const phone = document.getElementById("phone");
  phone.addEventListener("click", (e) => {
    const el = e.target.closest("[data-action]");
    if (el && phone.contains(el)) handleAction(el, e);
  });
  phone.addEventListener("keydown", (e) => {
    if ((e.key === "Enter" || e.key === " ") && e.target.matches('[role="button"]')) { e.preventDefault(); e.target.click(); }
    if (state.route.name === "counting" && (e.key === " " || e.key === "ArrowUp") && !e.target.matches("button, input")) { e.preventDefault(); increment(); }
    if (e.key === "Escape" && state.overlay) closeOverlay();
  });
  // Press feedback + counting taps
  let pressed = null;
  phone.addEventListener("pointerdown", (e) => {
    const counter = e.target.closest("[data-counter]");
    if (counter && state.route.name === "counting") {
      const whole = v("tapArea") === "screen";
      if (counter.dataset.counter === "circle" || (whole && !e.target.closest("button:not([data-counter])"))) {
        const c = currentScreen.querySelector('[data-counter="circle"]');
        pressDown(c); pressed = { counting: true, el: c };
        return;
      }
    }
    const el = e.target.closest(".pressable");
    if (el) { pressDown(el); pressed = { el }; }
  });
  const release = (e, cancel) => {
    if (!pressed) return;
    if (pressed.counting) { if (!cancel) increment(); else pressUp(pressed.el); }
    else pressUp(pressed.el);
    pressed = null;
  };
  window.addEventListener("pointerup", (e) => release(e, false));
  window.addEventListener("pointercancel", (e) => release(e, true));
  // Inputs in the create flow update the draft without re-rendering (keeps focus)
  phone.addEventListener("input", (e) => {
    const d = state.draft;
    if (d?.flow === "sentence") {
      if (e.target.dataset.input === "query") { d.query = e.target.value; createRoot().querySelector('[data-slot="dhikr-list"]').innerHTML = dhikrList(d); return; }
      const path = e.target.dataset.sinput;
      if (!path) return;
      setPath(d, path, e.target.value);
      if (d.yearlySingle && path.startsWith("schedule.ranges.0.start")) d.schedule.ranges[0].end = { ...d.schedule.ranges[0].start };
      renderSentence({ mainOnly: true });
      return;
    }
    const k = e.target.dataset.input;
    if (!k || !state.draft) return;
    state.draft[k] = e.target.value;
    const root = createRoot();
    if (k === "query") { root.querySelector('[data-slot="dhikr-list"]').innerHTML = dhikrList(state.draft); return; }
    refreshCreateValidation();
    if (k === "count") root.querySelectorAll('[data-action="quick-count"]').forEach((b) => b.setAttribute("aria-pressed", b.dataset.n === e.target.value));
  });
  // Lab
  const lab = document.getElementById("lab");
  lab.addEventListener("click", (e) => {
    const b = e.target.closest("button");
    if (!b) return;
    if (b.dataset.labtab) {
      state.labTab = b.dataset.labtab;
      lab.querySelectorAll("[data-labtab]").forEach((x) => x.setAttribute("aria-selected", x === b));
      lab.querySelectorAll("[data-labsection]").forEach((x) => x.classList.toggle("on", x.dataset.labsection === state.labTab));
      if (state.labTab === "data") renderLabData();
      return;
    }
    if (b.dataset.lab) {
      const k = b.dataset.lab; state.settings[k] = k === "reducedMotion" ? b.dataset.val === "true" : b.dataset.val;
      if (k === "lang") state.settings.dir = b.dataset.val === "ar" ? "rtl" : "ltr";
      save(); applySettings(); render(); if (state.draft?.flow === "sentence") renderSentence(); renderLab(); return;
    }
    if (b.dataset.variant) {
      state.variants[b.dataset.variant] = b.dataset.val; save();
      if (state.draft && ["createOrder", "createFlow"].includes(b.dataset.variant)) { closeOverlay(); state.draft = null; if (state.route.name === "create") { state.route = { name: "goals" }; state.stack = []; } }
      render(); renderLab(); return;
    }
    if (b.dataset.today) { setToday(b.dataset.today); return; }
    if (b.dataset.jump) { jump(b.dataset.jump, +b.dataset.n); return; }
    if (b.dataset.try) { state.variants.createFlow = b.dataset.try; save(); jump("create"); renderLab(); return; }
    const la = b.dataset.labaction;
    if (la === "apply-json") applyJSON();
    if (la === "refresh-json") renderLabData();
    if (la === "reset") { state.goals = seedGoals(state.settings.today); save(); state.stack = []; state.route = { name: state.route.name === "counting" || state.route.name === "create" ? "goals" : state.route.name }; render(); renderLab(); renderLabData(); }
    if (la === "reset-all") { localStorage.removeItem(STORE_KEY); location.reload(); }
  });
  lab.addEventListener("change", (e) => {
    if (e.target.id === "lab-today" && e.target.value) setToday(e.target.value);
    if (e.target.id === "lab-now") { state.settings.now = e.target.value; save(); state.session = null; render(); }
  });

  render();
  renderLab();
  loadCatalog();
}
function setToday(ds) { state.settings.today = ds; save(); render(); renderLab(); }
function jump(where, n) {
  if (state.overlay) closeOverlay(); stopAudio(); state.draft = null;
  if (where === "home" || where === "goals" || where === "history") {
    state.stack = []; state.goalsTab = where === "history" ? "history" : "active";
    state.route = { name: where === "history" ? "goals" : where }; render("tab"); return;
  }
  if (where === "create") { state.stack = []; state.route = { name: "goals" }; render("tab"); openCreate(); return; }
  if (where === "library") { state.stack = []; state.route = { name: "library" }; render("tab"); return; }
  const g = state.goals.find((x) => x.dhikr === "swalath-al-fathimiyya") || state.goals[0];
  if (where === "menu") { if (state.route.name !== "goals") { state.stack = []; state.route = { name: "goals" }; render("tab"); } openMenu(g.id); return; }
  if (where === "count") {
    setCount(g, g.sessions.length ? g.sessions[0].id : null, n); save();
    state.session = null; state.stack = [{ name: "goals" }]; state.route = { name: "counting", goalId: g.id }; render("push");
  }
}
async function loadCatalog() {
  try {
    const res = await fetch("../../contracts/dhikr-catalog/v1/catalog.json");
    if (!res.ok) throw new Error(res.status);
    const c = await res.json();
    catalog.dhikrs = [...c.dhikrs, ...CUSTOM_DHIKRS]; catalog.collections = c.collections; indexCatalog();
    render();
  } catch (e) {
    console.warn("Catalog not loaded (serve from the repo root); using the embedded subset.", e);
  }
}

/* Scripting hook for screenshots and quick experiments in the console. */
window.proto = {
  state, VARIANTS, CREATE_STEPS, STEP_DEFS, render, renderLab, jump, setToday,
  set(settings) {
    if ("dir" in settings && !("lang" in settings)) settings.lang = settings.dir === "rtl" ? "ar" : "en";
    if ("lang" in settings && !("dir" in settings)) settings.dir = settings.lang === "ar" ? "rtl" : "ltr";
    Object.assign(state.settings, settings); save(); applySettings(); render(); if (state.draft?.flow === "sentence") renderSentence(); renderLab();
  },
  /* Open the sentence sheet (B), optionally filled with example i. */
  sentence(i) {
    if (state.overlay) closeOverlay();
    state.variants.createFlow = "sentence"; save(); state.stack = []; state.route = { name: "goals" }; render();
    openCreate({}, "sentence");
    if (i != null) { state.draft = sdNew(SD_EXAMPLES[i]()); sdNormalize(state.draft); renderSentence(); }
    renderLab();
  },
  saveDraft: () => saveDraft(),
  sentenceGoal: () => sdToGoal(state.draft),
  sentenceValid: () => sdValid(state.draft),
  sentenceErrors: () => sdErrors(state.draft),
  variant(key, value) { state.variants[key] = value; save(); render(); renderLab(); },
  count(n) { jump("count", n); },
  rules: { isDue, classify, streakOf, chipText, progressOf, draftToGoal, goalToDraft, hijri, sdFromGoal, sdToGoal,
    project: (g) => (({ schedule, active_period, paused, count_policy, sessions, requirement, completion, name, preset, counts }) => ({ schedule, active_period, paused, count_policy, sessions, requirement, completion, name, preset, counts }))(g) },
};
boot();
