export const WEB_IDLE_MS = 30 * 60 * 1000;
const RENEW_INTERVAL_MS = 60 * 1000;

// Aktivitas nyata memperpanjang sesi; polling API dan tab diam tidak dihitung.
export function watchWebSession({ target = window, now = Date.now, renew, expire,
  schedule = setInterval, cancel = clearInterval }) {
  let lastActivity = now();
  let lastRenewal = lastActivity;
  let lastAttempt = lastActivity;
  let pending = false;
  let stopped = false;
  const events = ['pointerdown', 'pointermove', 'keydown', 'scroll', 'touchstart'];
  const stop = () => {
    stopped = true;
    cancel(timer);
    for (const name of events) target.removeEventListener(name, activity, true);
  };
  const check = async () => {
    if (stopped) return;
    const time = now();
    if (time - lastActivity >= WEB_IDLE_MS) {
      stop();
      expire();
      return;
    }
    if (pending || time - lastAttempt < RENEW_INTERVAL_MS || lastActivity <= lastRenewal) return;
    lastAttempt = time;
    pending = true;
    const renewalActivity = lastActivity;
    try {
      const token = await renew();
      if (!stopped && now() - lastActivity < WEB_IDLE_MS) {
        lastRenewal = renewalActivity;
        token.apply();
      }
    } catch {
      // Gangguan jaringan tidak menghapus sesi; respons 401 ditangani klien API.
    } finally {
      pending = false;
    }
  };
  const activity = event => {
    if (!event.isTrusted || stopped) return;
    if (now() - lastActivity >= WEB_IDLE_MS) { void check(); return; }
    lastActivity = now();
    void check();
  };
  const timer = schedule(() => { void check(); }, 15000);
  for (const name of events) target.addEventListener(name, activity, { capture: true, passive: true });
  return stop;
}
