import { useEffect, useState } from "react";

/** How long to wait between code emails when the server doesn't say (as the frozen apps did). */
export const RESEND_COOLDOWN_SECONDS = 60;

/**
 * A countdown in whole seconds, ticking once a second until it reaches zero.
 * `start` restarts it, for example with a `429`'s `Retry-After`.
 */
export function useCooldown(initialSeconds: number): { remaining: number; start: (seconds: number) => void } {
  const [until, setUntil] = useState(() => Date.now() + initialSeconds * 1000);
  const [now, setNow] = useState(() => Date.now());

  useEffect(() => {
    const timer = setInterval(() => {
      const tick = Date.now();
      setNow(tick);
      if (tick >= until) clearInterval(timer);
    }, 1000);
    return () => {
      clearInterval(timer);
    };
  }, [until]);

  return {
    remaining: Math.max(0, Math.ceil((until - now) / 1000)),
    start: (seconds) => {
      const startedAt = Date.now();
      setNow(startedAt);
      setUntil(startedAt + seconds * 1000);
    },
  };
}
