const {
  test
} = require('node:test');
const assert = require('node:assert/strict');
const {
  evaluateExtended,
  discipline
} = require('../src/utils/badge-evaluation');
const semesters = [{
  id: 1,
  tanggal_mulai: '2026-07-01',
  tanggal_selesai: '2026-12-31'
}, {
  id: 2,
  tanggal_mulai: '2027-01-01',
  tanggal_selesai: '2027-06-30'
}];
const level = (source, overrides = {}) => ({
  id_semester_mulai: 1,
  sumber_data: source,
  cara_hitung: 'AKUMULASI',
  target: 2,
  cakupan_perhitungan: 'SEMESTER',
  ...overrides
});
const evaluate = (l, events, now = '2026-11-26') => evaluateExtended(l, semesters, {
  events
}, now);
test('portfolio counts one record per student; attachments and duplicates do not multiply it', () => {
  const rows = [{
    id: 1,
    tanggal: '2026-10-01'
  }, {
    id: 1,
    tanggal: '2026-10-01'
  }, {
    id: 2,
    tanggal: '2026-10-02'
  }];
  const result = evaluate(level('PRESTASI'), rows);
  assert.equal(result.progress, 2);
  assert.equal(result.achievedOn, '2026-10-02');
});
test('club filter and semester prevent unrelated events satisfying a rule', () => {
  const rows = [{
    id: 1,
    tanggal: '2026-06-01',
    id_ekstrakurikuler: 1
  }, {
    id: 2,
    tanggal: '2026-10-01',
    id_ekstrakurikuler: 2
  }, {
    id: 3,
    tanggal: '2026-10-02',
    id_ekstrakurikuler: 1
  }];
  const r = evaluate(level('KEGIATAN', {
    id_ekstrakurikuler: 1
  }), rows);
  assert.equal(r.progress, 1);
  assert.equal(r.achievedOn, null);
});
test('membership counts different clubs and includes an overlapping earlier active span', () => {
  const rows = [{
    id: 1,
    tanggal: '2026-06-01',
    tanggal_selesai: '2026-08-01',
    id_ekstrakurikuler: 1
  }, {
    id: 2,
    tanggal: '2026-09-01',
    tanggal_selesai: null,
    id_ekstrakurikuler: 1
  }, {
    id: 3,
    tanggal: '2026-08-01',
    tanggal_selesai: null,
    id_ekstrakurikuler: 2
  }];
  const r = evaluate(level('KEANGGOTAAN_EKSKUL'), rows);
  assert.equal(r.progress, 2);
  assert.equal(r.achievedOn, '2026-08-01');
});
test('percentage excludes legitimate exceptions, needs a complete semester and at least one event', () => {
  const l = level('PRESENSI_SEKOLAH', {
    cara_hitung: 'PERSENTASE',
    target: 100,
    status_kehadiran_yang_dihitung: 'HADIR',
    jenis_presensi: 'PAGI'
  });
  const rows = [{
    id: 1,
    tanggal: '2026-10-01',
    jenis_sesi: 'PAGI',
    status: 'HADIR'
  }, {
    id: 2,
    tanggal: '2026-10-02',
    jenis_sesi: 'PAGI',
    status: 'PENGECUALIAN_SAH'
  }];
  assert.equal(evaluate(l, rows).achievedOn, null);
  assert.equal(evaluate(l, rows).pending, true);
  assert.equal(evaluate(l, rows, '2027-01-01').achievedOn, '2026-12-31');
  assert.equal(evaluate(l, [], '2027-01-01').achievedOn, null);
  assert.equal(evaluate(l, [...rows, {
    id: 3,
    tanggal: '2026-10-03',
    jenis_sesi: 'PAGI',
    status: null
  }], '2027-01-01').achievedOn, null);
});
test('discipline requires enrolled full days and never counts today', () => {
  const l = level('PELANGGARAN', {
    cara_hitung: 'HARI_TANPA_PELANGGARAN',
    target: 3
  });
  const data = {
    reports: [],
    roster: [{
      tanggal_mulai: '2026-11-24',
      tanggal_selesai: null
    }]
  };
  assert.equal(evaluateExtended(l, semesters, data, '2026-11-26').progress, 2);
  assert.equal(evaluateExtended(l, semesters, data, '2026-11-26').achievedOn, null);
  assert.equal(evaluateExtended(l, semesters, data, '2026-11-27').achievedOn, '2026-11-26');
});
test('verified occurrence resets streak; rejected does not; pending keeps it provisional', () => {
  const roster = [{
    tanggal_mulai: '2026-11-01',
    tanggal_selesai: null
  }];
  const report = {
    tanggal: '2026-11-03',
    status_verifikasi: 'TERVERIFIKASI'
  };
  const r = discipline('2026-11-01', '2026-11-06', [report], roster, 4);
  assert.equal(r.progress, 3);
  assert.equal(r.proof, null);
  assert.ok(discipline('2026-11-01', '2026-11-06', [{
    ...report,
    status_verifikasi: 'DITOLAK'
  }], roster, 4).proof);
  const pending = discipline('2026-11-01', '2026-11-06', [{
    ...report,
    status_verifikasi: 'MENUNGGU'
  }], roster, 4);
  assert.equal(pending.pending, true);
  assert.equal(pending.proof, null);
  assert.equal(pending.possible, 6);
});
test('a later violation does not erase an earlier valid earned window; late verification corrects it', () => {
  const roster = [{
    tanggal_mulai: '2026-11-01',
    tanggal_selesai: null
  }];
  const later = {
    tanggal: '2026-11-06',
    status_verifikasi: 'TERVERIFIKASI'
  };
  const r = discipline('2026-11-01', '2026-11-07', [later], roster, 4);
  assert.deepEqual(r.proof, {
    start: '2026-11-01',
    end: '2026-11-04'
  });
  const corrected = discipline('2026-11-01', '2026-11-07', [later, {
    tanggal: '2026-11-03',
    status_verifikasi: 'TERVERIFIKASI'
  }], roster, 4);
  assert.equal(corrected.proof, null);
});
test('a gap in enrollment breaks the discipline streak', () => {
  const roster = [{
    tanggal_mulai: '2026-11-01',
    tanggal_selesai: '2026-11-02'
  }, {
    tanggal_mulai: '2026-11-04',
    tanggal_selesai: null
  }];
  assert.equal(discipline('2026-11-01', '2026-11-06', [], roster, 4).proof, null);
});
