/**
 * The time and the browser's time zone, as the practice rules read them. Device context: the time
 * zone is always the browser's own and never sent anywhere. Tests set both.
 */
export const clock = {
  now: (): Date => new Date(),
  timeZone: (): string => Intl.DateTimeFormat().resolvedOptions().timeZone,
};
