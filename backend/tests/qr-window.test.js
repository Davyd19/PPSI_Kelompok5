const { test } = require('node:test');
const assert = require('node:assert/strict');
const { schedule, state } = require('../src/utils/qr-window');
const now = new Date('2026-11-26T00:00:00Z');
const body = {qr_aktif_mulai:'2026-11-26T07:00:00+07:00',qr_aktif_sampai:'2026-11-26T08:00:00+07:00'};
test('QR window: inclusive start, exclusive end; scheduled and closed reject', () => {
 const w = schedule(body, '2026-11-26', now), row = {...w,status:'AKTIF'};
 assert.equal(state(row,new Date(now-1)), 'TERJADWAL');
 assert.equal(state(row,now),'AKTIF');
 assert.equal(state(row,w.token_kedaluwarsa),'BERAKHIR');
 assert.equal(state({...row,status:'DITUTUP'},now),'BERAKHIR');
});
test('invalid/cross-day/missing-zone/reversed/expired windows reject', () => {
 for (const change of [{qr_aktif_sampai:'2026-11-27T08:00:00+07:00'}, {qr_aktif_mulai:'2026-11-26T09:00:00+07:00'}, {qr_aktif_mulai:'2026-11-26T07:00:00'}, {qr_aktif_sampai:null}]) assert.throws(()=>schedule({...body,...change},'2026-11-26',now));
 assert.throws(()=>schedule(body,'2026-11-26',new Date('2026-11-26T01:00:00Z')));
});
test('legacy durations adapt without crossing WIB midnight', () => {
 const w=schedule({berlaku_menit:15},'2026-11-26',new Date('2026-11-26T16:55:00Z'));
 assert.equal(w.token_kedaluwarsa.toISOString(),'2026-11-26T16:59:59.999Z');
 assert.throws(()=>schedule({berlaku_menit:0},'2026-11-26',now));
});
