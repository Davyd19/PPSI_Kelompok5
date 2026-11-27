import { test } from 'node:test';
import assert from 'node:assert/strict';
import { watchWebSession, WEB_IDLE_MS } from './web-session.js';
function setup(renew) {
  let clock = 0, tick, expired = 0, applied = 0;
  const handlers = new Map();
  const stop = watchWebSession({
    now: () => clock,
    target: { addEventListener: (key, fn) => handlers.set(key, fn), removeEventListener: key => handlers.delete(key) },
    schedule: fn => { tick = fn; return 1; }, cancel: () => {},
    expire: () => expired++, renew: renew || (async () => ({ apply: () => applied++ }))
  });
  return { advance: ms => { clock += ms; }, tick: () => tick(),
    activity: (trusted = true) => handlers.get('keydown')?.({ isTrusted: trusted }),
    flush: () => new Promise(resolve => setImmediate(resolve)), stop,
    get expired() { return expired; }, get applied() { return applied; }, get listeners() { return handlers.size; } };
}
test('idle tab never renews and expires exactly at thirty minutes', async () => {
  const s = setup(); s.advance(WEB_IDLE_MS - 1); s.tick(); await s.flush();
  assert.equal(s.applied, 0); assert.equal(s.expired, 0);
  s.advance(1); s.tick(); assert.equal(s.expired, 1); assert.equal(s.listeners, 0);
});
test('trusted activity renews once per minute and keeps an active session alive past login expiry', async () => {
  const s = setup();
  for (let minute = 0; minute < 40; minute++) {
    s.advance(60000); s.activity(); await s.flush();
    s.activity(); await s.flush();
  }
  assert.equal(s.expired, 0); assert.equal(s.applied, 40);
  s.advance(WEB_IDLE_MS); s.tick(); assert.equal(s.expired, 1);
});
test('synthetic events cannot keep a session alive or revive it after sleep', () => {
  const s = setup(); s.advance(WEB_IDLE_MS); s.activity(false); s.tick(); assert.equal(s.expired, 1);
  const sleep = setup(); sleep.advance(WEB_IDLE_MS); sleep.activity(); assert.equal(sleep.expired, 1);
});
test('late refresh response cannot restore session after logout', async () => {
  let resolve;
  const s = setup(() => new Promise(done => { resolve = done; }));
  s.advance(60000); s.activity(); s.stop();
  resolve({ apply: () => assert.fail('Token restored after stop') }); await s.flush();
});
test('network failure retains session for retry but never bypasses idle limit', async () => {
  const s = setup(async () => { throw new Error('offline'); });
  s.advance(60000); s.activity(); await s.flush(); assert.equal(s.expired, 0);
  s.advance(WEB_IDLE_MS); s.tick(); assert.equal(s.expired, 1);
});
