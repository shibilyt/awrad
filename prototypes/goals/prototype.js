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
    label: "Create flow order",
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
    prayer_name: "العصر", prayer_in: "بعد ١ س ١٢ د", prayer_place: "كوزيكود",
  },
};
const lang = () => (state.settings.dir === "rtl" ? "ar" : "en");
function t(key, ...args) {
  const s = STRINGS[lang()][key] ?? STRINGS.en[key];
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
  return new Intl.DateTimeFormat(lang() === "ar" ? "ar-u-nu-latn" : "en-GB", { timeZone: "UTC", ...opts }).format(toDate(ds));
}
const fmtHijri = (ds, withYear = false) => { const h = hijri(ds); return `${h.d} ${HIJRI_MONTHS[lang()][h.m - 1]}${withYear ? " " + h.y : ""}`; };
const weekdayName = (wd, style = "long") => new Intl.DateTimeFormat(lang() === "ar" ? "ar" : "en-GB", { weekday: style, timeZone: "UTC" }).format(toDate(addDays("2024-01-01", WEEKDAYS.indexOf(wd))));

/* ============================================================== 5. Goal rules (simplified)
 * Shapes follow contracts/goal-model/v1/goal-model.schema.json (goal_shape), plus prototype-only
 * fields: id, dhikr, name (optional override), preset, counts [{date, session, count}].
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
  for (const c of g.counts) if (c.date >= from && c.date <= to && (session === undefined || c.session === session)) n += c.count;
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
    const sorted = [...g.counts].filter((c) => c.date <= today && inActive(g, c.date)).sort((a, b) => (a.date < b.date ? -1 : 1));
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
  const months = HIJRI_MONTHS[lang()];
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
  if (r.type === "tracker") text = t("chip_tracker");
  else if (r.type === "cumulative_total") { text = t("chip_times", T); if (activeEnd(g)) text += t("chip_by", fmtDate(activeEnd(g))); }
  else if (r.type === "period_total") text = t("chip_period_total", T, t("period")[r.period]);
  else if (r.type === "days_per_period") text = t("chip_days_per_period", r.days, t("period")[r.period]);
  else if (s.kind === "every_day") text = M ? t("chip_min_target_daily", M, T) : t("chip_daily", T);
  else {
    if (s.kind === "weekdays") {
      const days = s.weekdays.map((w) => weekdayName(w, s.weekdays.length > 2 ? "short" : "long")).join(", ");
      text = t("chip_weekdays", p.target, lang() === "en" ? days.toLowerCase() : days).replace(String(p.target), T);
    } else if (s.kind === "yearly" && s.calendar === "hijri") text = t("chip_season", seasonLabel(g), p.target).replace(String(p.target), T);
    else if (s.kind === "hijri_month_days") text = t("chip_white", p.target).replace(String(p.target), T);
    else text = t("chip_generic", T);
    if (M) text = t("chip_min_prefix", M) + text;
  }
  if (r.type !== "tracker" && p.maximum != null) text += t("chip_cap", fmtN(p.maximum));
  if (g.sessions.length > 1) text += t("chip_sessions", g.sessions.length);
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
const catalog = { dhikrs: FALLBACK_DHIKRS, collections: [], byKey: {} };
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
    counts: [], created: o.start,
  };
}
/* Fill counts so the goal has `streak` met due days before today, then a miss, then older history. */
function seedCounts(g, today, { streak, perDay, todayCount = 0, older = 0, olderDays = 0, until = today }) {
  let d = addDays(until, -1), placed = 0;
  if (until === today && todayCount) g.counts.push({ date: today, session: null, count: todayCount });
  while (placed < streak && d >= g.active_period.start_date) {
    if (isDue(g, d)) { g.counts.push({ date: d, session: null, count: typeof perDay === "function" ? perDay(placed) : perDay }); placed++; }
    d = addDays(d, -1);
  }
  d = addDays(d, -2);
  for (let i = 0; i < olderDays && d >= g.active_period.start_date; d = addDays(d, -1)) {
    if (isDue(g, d)) { g.counts.push({ date: d, session: null, count: Math.round(older / olderDays) }); i++; }
  }
  g.counts.sort((a, b) => (a.date < b.date ? -1 : 1));
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
const STORE_KEY = "awrad-goals-proto-v1";
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
    if (g.sessions.length && !g.sessions.some((s) => s.id === state.session)) state.session = g.sessions[0].id;
    const session = g.sessions.length ? state.session : null;
    const p = policyOf(g, session), count = progressOf(g, td, session);
    const whole = v("tapArea") === "screen";
    const ar = goalArabic(g);
    const sessions = g.sessions.length > 1 ? `<div class="counter-sessions">${g.sessions.map((s) => `<button class="filter-chip" aria-pressed="${s.id === session}" data-action="session" data-session="${s.id}">${esc(t("session_names")[s.id] || s.id)} · ${progressOf(g, td, s.id)}</button>`).join("")}</div>` : "";
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
      <div class="count-body">
        ${ar ? `<div class="arabic-card" data-size="${state.settings.arabicSize}"><div class="t-quran" lang="ar">${esc(ar)}</div></div>` : ""}
        <div class="count-actions">
          <button class="btn main pressable" data-action="audio" data-slot="audio">${icon("play")}<span>${t("start_audio")}</span></button>
          <button class="btn square pressable" data-action="timer" aria-label="${esc(t("timer"))}">${icon("timer")}</button>
          <button class="btn square pressable" data-action="count-list" aria-label="${esc(t("count_list"))}">${icon("goals")}</button>
        </div>
        <div class="counter-zone ${whole ? "whole" : ""}" ${whole ? 'data-counter="zone"' : ""}>
          ${sessions}
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
  library() { return placeholder("nav_library"); },
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

/* ============================================================== 10. Create flow (draft v0)
 * CREATE_STEPS is the whole flow. A step: { id, title(draft), lede(draft), body(draft), valid(draft) }.
 * Reorder, remove or add entries to change the flow; the step indicator follows.
 */
const SESSION_IDS = ["after_fajr", "morning", "after_maghrib", "evening", "before_sleep"];
const RAMADAN_PARTS = {
  whole: { preset: "ramadan", ranges: [[9, 1, 9, 30]] },
  first10: { preset: null, ranges: [[9, 1, 9, 10]] },
  last10: { preset: "ramadan_last_ten", ranges: [[9, 21, 9, 30]] },
  odd: { preset: "ramadan_odd_nights", ranges: [[9, 21, 9, 21], [9, 23, 9, 23], [9, 25, 9, 25], [9, 27, 9, 27], [9, 29, 9, 29]] },
};
const STEP_DEFS = {
  dhikr: {
    title: () => t("step_dhikr"), lede: () => t("step_dhikr_lede"),
    body: (d) => `<div class="search">${icon("search")}<input class="field t-input" data-input="query" placeholder="${esc(t("search_ph"))}" value="${esc(d.query)}" aria-label="${esc(t("search_ph"))}">
      ${d.query ? `<button class="icon-btn" data-action="clear-query" aria-label="${esc(t("close"))}">${icon("close")}</button>` : ""}</div>
      <div data-slot="dhikr-list">${dhikrList(d)}</div>`,
    valid: (d) => !!d.dhikr,
  },
  count: {
    title: () => t("step_count"), lede: (d) => (d.when === "once" ? t("step_count_total") : t("step_count_daily")),
    body: (d) => `<input class="big-number" inputmode="numeric" data-input="count" value="${esc(d.count)}" aria-label="${esc(t("step_count"))}">
      <div class="field-msg error" data-err="count"></div>
      <div class="chip-row" style="margin-top:var(--s-lg);justify-content:center">${(d.when === "once" ? [1000, 4444, 10000, 70000] : [3, 33, 100, 313, 1000]).map((n) => `<button class="filter-chip" aria-pressed="${String(n) === d.count}" data-action="quick-count" data-n="${n}">${fmtN(n)}</button>`).join("")}</div>`,
    valid: (d) => !errorsOf(d).count,
  },
  when: {
    title: () => t("step_when"), lede: () => t("step_when_lede"),
    body: (d) => whenBody(d),
    valid: (d) => { const e = errorsOf(d); return !e.weekdays && !e.minimum && !e.maximum && !e.end; },
  },
  review: {
    title: () => t("step_review"), lede: () => t("step_review_lede"),
    body: (d) => reviewBody(d), valid: () => true,
  },
};
const CREATE_STEPS = () => (v("createOrder") === "whenFirst" ? ["dhikr", "when", "count", "review"] : ["dhikr", "count", "when", "review"]);

function newDraft() {
  return { mode: "create", goalId: null, step: 0, dhikr: null, query: "", count: "100", when: "every_day", weekdays: [weekday(today())], ramadanPart: "first10",
    minimum: "", maximum: "", start: today(), end: "", sessions: [], streak: "auto", moreOpen: false, showJson: false, customSchedule: null };
}
function goalToDraft(g) {
  const d = newDraft();
  const p = policyOf(g);
  Object.assign(d, { mode: "edit", goalId: g.id, dhikr: g.dhikr, count: String(p.target ?? ""), minimum: p.minimum != null ? String(p.minimum) : "", maximum: p.maximum != null ? String(p.maximum) : "",
    start: g.active_period.start_date, end: g.active_period.end_date || "", sessions: g.sessions.map((s) => s.id), streak: p.streak_threshold });
  const s = g.schedule;
  if (g.requirement.type === "cumulative_total" && (s.kind === "one_time" || s.kind === "every_day")) d.when = "once";
  else if (g.requirement.type !== "per_due_date") { d.when = "custom"; d.customSchedule = s; }
  else if (s.kind === "every_day") d.when = "every_day";
  else if (s.kind === "weekdays") { d.when = "weekdays"; d.weekdays = [...s.weekdays]; }
  else if (s.kind === "hijri_month_days" && String(s.days) === "13,14,15") d.when = "white";
  else {
    const part = s.kind === "yearly" && s.calendar === "hijri" && Object.entries(RAMADAN_PARTS).find(([, v]) => JSON.stringify(v.ranges) === JSON.stringify(s.ranges.map((r) => [r.start.month, r.start.day, r.end.month, r.end.day])));
    if (part) { d.when = "ramadan"; d.ramadanPart = part[0]; } else { d.when = "custom"; d.customSchedule = s; }
  }
  d.moreOpen = !!(d.minimum || d.maximum || d.end || d.sessions.length);
  d.step = CREATE_STEPS().indexOf("review");
  return d;
}
const intOrNull = (s) => (String(s).trim() === "" ? null : /^\d+$/.test(String(s).trim()) ? parseInt(s, 10) : NaN);
function errorsOf(d) {
  const e = {}, c = intOrNull(d.count), m = intOrNull(d.minimum), x = intOrNull(d.maximum);
  if (!(c > 0)) e.count = t("err_count");
  if (d.when === "weekdays" && !d.weekdays.length) e.weekdays = t("err_weekdays");
  if (Number.isNaN(m) || (m != null && c > 0 && m >= c)) e.minimum = Number.isNaN(m) ? t("err_count") : t("err_min");
  if (Number.isNaN(x) || (x != null && c > 0 && x < c)) e.maximum = Number.isNaN(x) ? t("err_count") : t("err_cap");
  if (d.end && d.end < d.start) e.end = t("err_end");
  return e;
}
/* The draft → a goal in the contract's shape (plus prototype fields). */
function draftToGoal(d, base = null) {
  const target = intOrNull(d.count) || 1, minimum = intOrNull(d.minimum) || null, maximum = intOrNull(d.maximum) || null;
  const once = d.when === "once";
  let schedule, preset = null;
  if (d.when === "every_day") schedule = { kind: "every_day" };
  else if (d.when === "weekdays") schedule = { kind: "weekdays", weekdays: WEEKDAYS.filter((w) => d.weekdays.includes(w)) };
  else if (d.when === "ramadan") { const part = RAMADAN_PARTS[d.ramadanPart]; preset = part.preset; schedule = { kind: "yearly", calendar: "hijri", ranges: part.ranges.map(([a, b, c, e]) => ({ start: { month: a, day: b }, end: { month: c, day: e } })) }; }
  else if (d.when === "white") { preset = "white_days"; schedule = { kind: "hijri_month_days", days: [13, 14, 15] }; }
  else if (once) schedule = { kind: "one_time" };
  else schedule = d.customSchedule || { kind: "every_day" };
  const threshold = d.streak !== "auto" ? d.streak : once ? "any_count" : minimum ? "minimum" : "target";
  const cp = { minimum, target, maximum, streak_threshold: threshold === "minimum" && !minimum ? "target" : threshold === "maximum" && !maximum ? "target" : threshold };
  const sessions = d.sessions.map((id) => ({ id, count_policy: { ...cp } }));
  return {
    id: base?.id || uuidv7(), dhikr: d.dhikr, name: base?.name || null, custom_arabic: base?.custom_arabic || null, preset,
    schedule,
    active_period: { start_date: d.start, end_date: d.end || null, duration_days: null },
    paused: base?.paused || [],
    count_policy: sessions.length ? { minimum: null, target: null, maximum: null, streak_threshold: "any_count" } : cp,
    sessions,
    requirement: base && d.when === "custom" ? base.requirement : { type: once ? "cumulative_total" : "per_due_date" },
    completion: once ? "when_target_reached" : d.end ? "when_duration_ended" : "never",
    counts: base?.counts || [], created: base?.created || today(),
  };
}
const normalise = (s) => s.toLowerCase().normalize("NFD").replace(/[ً-ٰٟۖ-ۭـ]/g, "").replace(/[̀-ͯ'’-]/g, "");
function dhikrList(d) {
  const q = normalise(d.query.trim());
  const rowHTML = (x) => `<button class="dhikr-row pressable ${d.dhikr === x.key ? "selected" : ""}" data-action="pick-dhikr" data-key="${x.key}">
      <div class="body"><div class="t-rowTitle">${esc(x.title[lang()] || x.title.en)}</div><div class="ar t-quranLine" lang="ar">${esc(x.arabic.split("\n")[0])}</div></div>
      ${d.dhikr === x.key ? icon("check") : icon("chevron", "mirror")}</button>`;
  if (q) {
    const hits = catalog.dhikrs.filter((x) => [x.key, ...Object.values(x.title), ...Object.values(x.aliases || {}).flat(), x.arabic].some((s) => normalise(String(s)).includes(q)));
    return hits.length ? `<div class="dhikr-list">${hits.slice(0, 40).map(rowHTML).join("")}</div>` : `<p class="t-body" style="color:var(--c-onSurfaceVariant)">${t("no_results")}</p>`;
  }
  const groups = catalog.collections.length ? catalog.collections : [{ key: "all", title: { en: "All" }, dhikrs: catalog.dhikrs.map((x) => x.key) }];
  return groups.map((c) => `<div class="dhikr-group-title t-sectionTitle">${esc(c.title[lang()] || c.title.en)}</div><div class="dhikr-list">${c.dhikrs.slice(0, c.key === "asma-ul-husna" ? 6 : 99).map((k) => catalog.byKey[k]).filter(Boolean).map(rowHTML).join("")}</div>`).join("");
}
function optionRow(id, label, sub, d, extra = "") {
  const on = d.when === id;
  return `<div><button class="option-row pressable" role="radio" aria-checked="${on}" data-action="pick-when" data-when="${id}">
    <div class="body"><div class="t-rowTitle">${esc(label)}</div>${sub ? `<div class="sub">${esc(sub)}</div>` : ""}</div>
    <span class="tick">${icon("check")}</span></button>${on && extra ? `<div class="option-extra">${extra}</div>` : ""}</div>`;
}
function whenBody(d) {
  const e = errorsOf(d);
  const weekdayChips = `<div class="chip-row">${WEEKDAYS.map((w) => `<button class="filter-chip" aria-pressed="${d.weekdays.includes(w)}" data-action="toggle-weekday" data-wd="${w}">${d.weekdays.includes(w) ? icon("check", "small") : ""}${esc(weekdayName(w, "short"))}</button>`).join("")}</div>
    <div class="field-msg error" data-err="weekdays">${e.weekdays || ""}</div>`;
  const ramadanChips = `<div class="chip-row">${Object.keys(RAMADAN_PARTS).map((k) => `<button class="filter-chip" aria-pressed="${d.ramadanPart === k}" data-action="ramadan-part" data-part="${k}">${t("ramadan_" + k)}</button>`).join("")}</div>`;
  const field = (key, label, help, type = "number") => `<div class="field-group"><label class="field-label t-label" for="f-${key}">${label}</label>
      <input id="f-${key}" class="field t-input ${e[key] ? "error" : ""}" type="${type === "number" ? "text" : type}" ${type === "number" ? 'inputmode="numeric"' : ""} data-input="${key}" value="${esc(d[key])}" ${type === "number" ? 'placeholder="–"' : ""}>
      <div class="field-msg ${e[key] ? "error" : ""}" data-err="${key}" data-help="${esc(help || "")}">${e[key] || help || ""}</div></div>`;
  const streakOpts = ["auto", "any_count", "minimum", "target", "maximum"].map((k) => `<button class="filter-chip" aria-pressed="${d.streak === k}" data-action="streak-opt" data-opt="${k}">${t("streak_opt")[k]}</button>`).join("");
  return `<div class="options" role="radiogroup">
      ${optionRow("every_day", t("when_every_day"), "", d)}
      ${optionRow("weekdays", t("when_weekdays"), "", d, weekdayChips)}
      ${optionRow("ramadan", t("when_ramadan"), "", d, ramadanChips)}
      ${optionRow("white", t("when_white"), t("when_white_sub"), d)}
      ${optionRow("once", t("when_once"), t("when_once_sub"), d)}
      ${d.when === "custom" ? optionRow("custom", t("when_custom"), t("when_custom_sub"), d) : ""}
    </div>
    <button class="expander t-sectionTitle" data-action="toggle-more" aria-expanded="${d.moreOpen}">${t("more_options")}${icon("expand")}</button>
    ${d.moreOpen ? `<div class="more-panel">
      <div class="field-pair">${d.when === "once" ? "" : field("minimum", t("f_minimum"), t("f_minimum_help"))}${field("maximum", t("f_cap"), t("f_cap_help"))}</div>
      <div class="field-pair">${field("start", t("f_start"), "", "date")}${field("end", t("f_end"), t("f_end_help"), "date")}</div>
      ${d.when === "once" ? "" : `<div class="field-group"><div class="field-label t-label">${t("f_sessions")}</div>
        <div class="chip-row">${SESSION_IDS.map((s) => `<button class="filter-chip" aria-pressed="${d.sessions.includes(s)}" data-action="toggle-session" data-session="${s}">${d.sessions.includes(s) ? icon("check", "small") : ""}${t("session_names")[s]}</button>`).join("")}</div>
        <div class="field-msg">${t("f_sessions_help")}</div></div>`}
      <div class="field-group"><div class="field-label t-label">${t("f_streak")}</div><div class="chip-row">${streakOpts}</div></div>
    </div>` : ""}`;
}
function reviewBody(d) {
  const g = draftToGoal(d, d.goalId ? goalById(d.goalId) : null);
  const p = policyOf(g), x = catalog.byKey[g.dhikr];
  const scheduleText = { every_day: t("when_every_day"), weekdays: t("when_weekdays"), yearly: seasonLabel(g) || "yearly", hijri_month_days: t("when_white"), one_time: t("when_once") }[g.schedule.kind] || g.schedule.kind;
  const row = (k, val) => `<div class="row t-body"><span class="k">${k}</span><span class="v">${esc(val)}</span></div>`;
  return `<div class="review-preview">
      <div class="label t-label">${t("preview_goals")}</div>
      ${goalCard(g, "today", { preview: true, isNew: d.mode === "create" })}
      <div class="label t-label">${t("preview_home")}</div>
      ${homeRow(g, { preview: true, isNew: d.mode === "create" })}
    </div>
    <div class="summary">
      ${row(t("s_dhikr"), x ? x.title[lang()] || x.title.en : goalTitle(g))}
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
      ${d.showJson ? `<pre>${esc(JSON.stringify((({ counts, ...rest }) => rest)(g), null, 2))}</pre>` : ""}</div>`;
}
function renderCreate() {
  const d = state.draft, steps = CREATE_STEPS(), id = steps[d.step], def = STEP_DEFS[id];
  const last = d.step === steps.length - 1;
  const label = last ? (d.mode === "edit" ? t("save_changes") : t("save")) : t("continue");
  return { cls: "fixed no-nav", html: `
    <header class="topbar">
      <button class="icon-btn pressable" data-action="create-back" aria-label="${esc(d.step === 0 ? t("close") : t("back"))}">${d.step === 0 ? icon("close") : icon("back", "mirror")}</button>
      <div class="steps" role="img" aria-label="Step ${d.step + 1} of ${steps.length}">${steps.map((_, i) => `<i class="${i <= d.step ? "on" : ""}"></i>`).join("")}</div>
      <span style="width:var(--touchTarget)"></span>
    </header>
    <div class="create-body" data-step="${id}">
      <h1 class="t-title">${esc(def.title(d))}</h1>
      <p class="lede t-bodySmall" data-slot="lede">${esc(def.lede(d))}</p>
      ${def.body(d)}
    </div>
    <footer class="create-foot"><button class="btn main pressable" data-action="create-next" ${def.valid(d) ? "" : "disabled"}>${label}</button></footer>` };
}
function refreshCreateValidation() {
  const host = document.querySelector(".screen.current"), d = state.draft;
  if (!host || !d) return;
  const e = errorsOf(d);
  host.querySelectorAll("[data-err]").forEach((el) => {
    const k = el.dataset.err, msg = e[k];
    if (k === "count" && !d.count) { el.textContent = ""; return; }
    el.textContent = msg || el.dataset.help || "";
    el.classList.toggle("error", !!msg);
    host.querySelector(`[data-input="${k}"]`)?.classList.toggle("error", !!msg);
  });
  const def = STEP_DEFS[CREATE_STEPS()[d.step]];
  host.querySelector('[data-action="create-next"]').disabled = !def.valid(d);
}
function saveDraft() {
  const d = state.draft;
  const base = d.goalId ? goalById(d.goalId) : null;
  const g = draftToGoal(d, base);
  if (base) state.goals[state.goals.indexOf(base)] = g; else state.goals.push(g);
  save();
  state.draft = null;
  if (d.mode === "edit") { goBack(); toast(t("t_updated")); }
  else { state.goalsTab = "active"; state.stack = []; navigate({ name: "goals" }, "pop"); toast(t("t_saved")); flashGoal(g.id); }
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
  const entry = g.counts.find((c) => c.date === td && c.session === session);
  if (entry) entry.count = todayValue; else if (todayValue) g.counts.push({ date: td, session, count: todayValue });
  if (entry && !entry.count) g.counts.splice(g.counts.indexOf(entry), 1);
}
function increment(by = 1) {
  const g = goalById(state.route.goalId);
  if (!g) return;
  const td = today(), session = g.sessions.length ? state.session : null, p = policyOf(g, session);
  const before = progressOf(g, td, session);
  if (p.maximum != null && before >= p.maximum) { haptic("threshold"); toast(t("t_cap", fmtN(p.maximum))); popCircle(true); return; }
  setCount(g, session, before + by);
  const after = before + by;
  save();
  if (p.target && before < p.target && after >= p.target) { haptic("success"); toast(t("t_target")); }
  else if (p.minimum && before < p.minimum && after >= p.minimum) { haptic("threshold"); toast(t("t_min")); }
  else haptic("tick");
  updateCounting(before, after);
  popCircle();
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
  root.querySelector('[data-counter="circle"]').setAttribute("aria-label", `${t("tap_circle")}: ${after}`);
  root.querySelectorAll('[data-action="session"]').forEach((b) => (b.textContent = `${t("session_names")[b.dataset.session] || b.dataset.session} · ${progressOf(g, td, b.dataset.session)}`));
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

  <h3>Design gaps</h3>
  <ul>
    <li>No timer icon in <code>icons.json</code> (placeholder drawn); no edit/pencil icon (<code>tune</code> used). The list button uses the <code>goals</code> icon. What the timer and list buttons do isn't designed (toasts).</li>
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
  const seg = (key, opts) => `<span class="seg-mini">${Object.entries(opts).map(([val, label]) => `<button data-lab="${key}" data-val="${val}" aria-pressed="${String(s[key]) === val}">${label}</button>`).join("")}</span>`;
  const fath = state.goals.find((g) => g.dhikr === "swalath-al-fathimiyya");
  const ram = gregorianOfHijri(hijri(s.today).m < 9 ? hijri(s.today).y : hijri(s.today).y + 1, 9, 1, s.today);
  const white = findDate((d) => hijri(d).d === 13, addDays(s.today, 1), 40);
  const thu = findDate((d) => weekday(d) === "thursday", addDays(s.today, 1), 8);
  document.getElementById("lab-controls").innerHTML = `
    <h2>Look</h2>
    <div class="row"><label>Theme</label>${seg("theme", { light: "Light", dark: "Dark" })}</div>
    <div class="row"><label>Direction</label>${seg("dir", { ltr: "LTR (English)", rtl: "RTL (Arabic)" })}</div>
    <div class="row"><label>Reduced motion</label>${seg("reducedMotion", { false: "Off", true: "On" })}</div>
    <h2>Today</h2>
    <div class="row"><label for="lab-today">Effective practice day</label><input id="lab-today" type="date" value="${s.today}"></div>
    <div class="msg">Hijri: ${esc(fmtHijriEn(s.today))} · ${weekday(s.today)}</div>
    <div class="btns" style="margin-top:8px">
      <button data-today="${addDays(s.today, -1)}">− 1 day</button><button data-today="${addDays(s.today, 1)}">+ 1 day</button>
      ${thu ? `<button data-today="${thu}">Next Thursday</button>` : ""}${white ? `<button data-today="${white}">Next white day</button>` : ""}
      ${ram ? `<button data-today="${ram}">1 Ramadan</button>` : ""}<button data-today="${localToday()}">Real today</button>
    </div>
    <h2>Jump to</h2>
    <div class="btns">
      <button data-jump="home">Home</button><button data-jump="goals">My Goals</button><button data-jump="history">History</button>
      <button data-jump="create">Create</button><button data-jump="menu">⋮ menu</button>
    </div>
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
    <p class="sub" style="margin-top:0">The goals, in the goal-model shape plus prototype fields (<code>id</code>, <code>dhikr</code>, <code>name</code>, <code>preset</code>, <code>counts</code>). Edit and apply.</p>
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
      for (const k of ["id", "dhikr", "schedule", "active_period", "count_policy", "sessions", "requirement", "completion", "counts"]) if (!(k in g)) throw new Error(`Goal ${i}: missing "${k}"`);
      g.paused ||= [];
    });
    state.goals = goals; save(); render(); msg.className = "msg"; msg.textContent = `Applied ${goals.length} goals.`;
  } catch (e) { msg.className = "msg err"; msg.textContent = e.message; }
}
function applySettings() {
  const phone = document.getElementById("phone"), s = state.settings;
  phone.dataset.theme = s.theme;
  phone.dir = s.dir;
  phone.lang = s.dir === "rtl" ? "ar" : "en";
  phone.classList.toggle("reduced", !!s.reducedMotion);
}

/* ============================================================== 14. Events + boot */
function handleAction(el, e) {
  const a = el.dataset.action, id = el.dataset.id;
  switch (a) {
    case "tab": {
      const tab = el.dataset.tab;
      if (tab === state.route.name) return;
      haptic("tick"); state.stack = []; state.route = { name: tab }; stopAudio(); render("tab"); return;
    }
    case "goals-tab": if (state.goalsTab !== el.dataset.tab) { state.goalsTab = el.dataset.tab; render(); listAppear(currentScreen); } return;
    case "open-goal": navigate({ name: "counting", goalId: id }); return;
    case "back": goBack(); return;
    case "add-goal": state.draft = newDraft(); navigate({ name: "create" }); return;
    case "goal-menu": e.stopPropagation(); openMenu(id, el.dataset.context); return;
    case "close-overlay": closeOverlay(); return;
    case "edit-goal": { const gid = state.overlay.goalId; closeOverlay(); state.draft = goalToDraft(goalById(gid)); navigate({ name: "create" }); return; }
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
      setCount(g, session, after); save(); closeOverlay(); updateCounting(before, after); toast(a === "undo" ? t("t_undo") : t("t_reset")); return;
    }
    case "text-size": state.settings.arabicSize = (state.settings.arabicSize + 1) % 3; save(); currentScreen.querySelector(".arabic-card")?.setAttribute("data-size", state.settings.arabicSize); return;
    case "audio": toggleAudio(); return;
    case "timer": toast(t("t_timer")); return;
    case "count-list": toast(t("t_list")); return;
    case "toast-placeholder": toast(t("placeholder")); return;
    case "session": state.session = el.dataset.session; render(); return;
    // Create flow
    case "create-back": if (state.draft.step === 0) { state.draft = null; goBack(); } else { state.draft.step--; render("pop"); } return;
    case "create-next": {
      const steps = CREATE_STEPS();
      if (state.draft.step === steps.length - 1) return saveDraft();
      state.draft.step++; haptic("tick"); render("push"); return;
    }
    case "pick-dhikr": state.draft.dhikr = el.dataset.key; render(); setTimeout(() => { if (state.route.name === "create" && STEP_DEFS[CREATE_STEPS()[state.draft.step]] === STEP_DEFS.dhikr) { state.draft.step++; render("push"); } }, 180); return;
    case "clear-query": state.draft.query = ""; render(); return;
    case "quick-count": state.draft.count = el.dataset.n; render(); return;
    case "pick-when": state.draft.when = el.dataset.when; render(); return;
    case "toggle-weekday": { const w = state.draft.weekdays, i = w.indexOf(el.dataset.wd); i >= 0 ? w.splice(i, 1) : w.push(el.dataset.wd); render(); return; }
    case "ramadan-part": state.draft.ramadanPart = el.dataset.part; render(); return;
    case "toggle-more": state.draft.moreOpen = !state.draft.moreOpen; render(); if (state.draft.moreOpen && !reduced()) { const p = currentScreen.querySelector(".more-panel"); const s = spring("spatial"); p.animate([{ opacity: 0, transform: "translateY(-8px)" }, { opacity: 1, transform: "none" }], { duration: s.duration, easing: s.easing }); } return;
    case "toggle-session": { const s = state.draft.sessions, i = s.indexOf(el.dataset.session); i >= 0 ? s.splice(i, 1) : s.push(el.dataset.session); render(); return; }
    case "streak-opt": state.draft.streak = el.dataset.opt; render(); return;
    case "toggle-json": state.draft.showJson = !state.draft.showJson; render(); return;
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
    const k = e.target.dataset.input;
    if (!k || !state.draft) return;
    state.draft[k] = e.target.value;
    if (k === "query") { currentScreen.querySelector('[data-slot="dhikr-list"]').innerHTML = dhikrList(state.draft); return; }
    refreshCreateValidation();
    if (k === "count") currentScreen.querySelectorAll('[data-action="quick-count"]').forEach((b) => b.setAttribute("aria-pressed", b.dataset.n === e.target.value));
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
    if (b.dataset.lab) { const k = b.dataset.lab; state.settings[k] = k === "reducedMotion" ? b.dataset.val === "true" : b.dataset.val; save(); applySettings(); render(); renderLab(); return; }
    if (b.dataset.variant) { state.variants[b.dataset.variant] = b.dataset.val; save(); if (state.draft && b.dataset.variant === "createOrder") state.draft.step = Math.min(state.draft.step, 3); render(); renderLab(); return; }
    if (b.dataset.today) { setToday(b.dataset.today); return; }
    if (b.dataset.jump) { jump(b.dataset.jump, +b.dataset.n); return; }
    const la = b.dataset.labaction;
    if (la === "apply-json") applyJSON();
    if (la === "refresh-json") renderLabData();
    if (la === "reset") { state.goals = seedGoals(state.settings.today); save(); state.stack = []; state.route = { name: state.route.name === "counting" || state.route.name === "create" ? "goals" : state.route.name }; render(); renderLab(); renderLabData(); }
    if (la === "reset-all") { localStorage.removeItem(STORE_KEY); location.reload(); }
  });
  lab.addEventListener("change", (e) => { if (e.target.id === "lab-today" && e.target.value) setToday(e.target.value); });

  render();
  renderLab();
  loadCatalog();
}
function setToday(ds) { state.settings.today = ds; save(); render(); renderLab(); }
function jump(where, n) {
  closeOverlay(); stopAudio(); state.draft = null;
  if (where === "home" || where === "goals" || where === "history") {
    state.stack = []; state.goalsTab = where === "history" ? "history" : "active";
    state.route = { name: where === "history" ? "goals" : where }; render("tab"); return;
  }
  if (where === "create") { state.stack = [{ name: "goals" }]; state.draft = newDraft(); state.route = { name: "create" }; render("push"); return; }
  const g = state.goals.find((x) => x.dhikr === "swalath-al-fathimiyya") || state.goals[0];
  if (where === "menu") { if (state.route.name !== "goals") { state.stack = []; state.route = { name: "goals" }; render("tab"); } openMenu(g.id); return; }
  if (where === "count") {
    setCount(g, g.sessions.length ? g.sessions[0].id : null, n); save();
    state.stack = [{ name: "goals" }]; state.route = { name: "counting", goalId: g.id }; render("push");
  }
}
async function loadCatalog() {
  try {
    const res = await fetch("../../contracts/dhikr-catalog/v1/catalog.json");
    if (!res.ok) throw new Error(res.status);
    const c = await res.json();
    catalog.dhikrs = c.dhikrs; catalog.collections = c.collections; indexCatalog();
    render();
  } catch (e) {
    console.warn("Catalog not loaded (serve from the repo root); using the embedded subset.", e);
  }
}

/* Scripting hook for screenshots and quick experiments in the console. */
window.proto = {
  state, VARIANTS, CREATE_STEPS, STEP_DEFS, render, renderLab, jump, setToday,
  set(settings) { Object.assign(state.settings, settings); save(); applySettings(); render(); renderLab(); },
  variant(key, value) { state.variants[key] = value; save(); render(); renderLab(); },
  count(n) { jump("count", n); },
  rules: { isDue, classify, streakOf, chipText, progressOf, draftToGoal, goalToDraft, hijri },
};
boot();
