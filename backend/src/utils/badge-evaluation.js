const shift = (day, n) => {
  const d = new Date(day + 'T00:00:00Z');
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
};
function discipline(start, end, rows, roster, target) {
  let run = 0,
    possibleRun = 0,
    max = 0,
    possible = 0,
    pending = false,
    proof = null;
  const flags = new Map();
  for (const row of rows) {
    if (row.tanggal < start || row.tanggal > end || row.status_verifikasi === 'DITOLAK') continue;
    const flag = row.status_verifikasi === 'TERVERIFIKASI' ? 'BLOCK' : 'PENDING';
    if (flags.get(row.tanggal) !== 'BLOCK') flags.set(row.tanggal, flag);
  }
  for (let day = start; day <= end; day = shift(day, 1)) {
    const enrolled = roster.some(r => r.tanggal_mulai <= day && (!r.tanggal_selesai || r.tanggal_selesai >= day));
    const flag = flags.get(day);
    pending ||= enrolled && flag === 'PENDING';
    run = enrolled && !flag ? run + 1 : 0;
    possibleRun = enrolled && flag !== 'BLOCK' ? possibleRun + 1 : 0;
    max = Math.max(max, run);
    possible = Math.max(possible, possibleRun);
    if (!proof && run >= target) proof = {
      start: shift(day, 1 - target),
      end: day
    };
  }
  return {
    score: max,
    progress: proof ? max : run,
    possible,
    pending: proof ? false : pending,
    proof
  };
}
function evaluateExtended(level, semesters, data, now) {
  const begin = semesters.find(s => s.id === level.id_semester_mulai),
    last = semesters.find(s => s.id === level.id_semester_selesai);
  if (!begin || level.id_semester_selesai && !last || begin.tanggal_mulai > now) return null;
  const finish = last?.tanggal_selesai || '9999-12-31';
  const periods = level.cakupan_perhitungan === 'SEMESTER' ? semesters.filter(s => s.tanggal_mulai >= begin.tanggal_mulai && s.tanggal_mulai <= finish && s.tanggal_mulai <= now).map(s => ({
    start: s.tanggal_mulai,
    end: s.tanggal_selesai
  })) : [{
    start: begin.tanggal_mulai,
    end: finish
  }];
  const windows = periods.map(period => {
    const end = period.end < now ? period.end : now;
    if (level.sumber_data === 'PELANGGARAN') return {
      ...period,
      ...discipline(period.start, end < now ? end : shift(now, -1), data.reports || [], data.roster || [], level.target)
    };
    let rows = (data.events || []).filter(e => !level.id_ekstrakurikuler || e.id_ekstrakurikuler === level.id_ekstrakurikuler);
    if (level.sumber_data === 'KEANGGOTAAN_EKSKUL') rows = rows.filter(e => e.tanggal <= end && (!e.tanggal_selesai || e.tanggal_selesai >= period.start)).map(e => ({
      ...e,
      tanggal: e.tanggal < period.start ? period.start : e.tanggal
    }));else rows = rows.filter(e => e.tanggal >= period.start && e.tanggal <= end && (!level.jenis_presensi || e.jenis_sesi === level.jenis_presensi));
    rows = rows.toSorted((a, b) => a.tanggal.localeCompare(b.tanggal) || a.id - b.id);
    if (level.cara_hitung === 'PERSENTASE') {
      rows = rows.filter(e => !['PENGECUALIAN_SAH', 'PENGECUALIAN_SAH_ZUHUR'].includes(e.status));
      const hits = rows.filter(e => e.status === level.status_kehadiran_yang_dihitung).length;
      const pending = rows.some(e => e.status == null) || now <= period.end;
      const score = rows.length ? Math.round(hits / rows.length * 10000) / 100 : 0;
      return {
        ...period,
        score,
        progress: score,
        possible: pending ? 100 : score,
        pending,
        proof: !pending && rows.length && score >= level.target ? {
          start: period.start,
          end: period.end
        } : null
      };
    }
    const unique = new Map();
    for (const row of rows) {
      const id = level.sumber_data === 'KEANGGOTAAN_EKSKUL' ? row.id_ekstrakurikuler : row.id;
      if (!unique.has(id)) unique.set(id, row);
    }
    let score = 0,
      possible = 0,
      run = 0,
      possibleRun = 0,
      pending = false,
      proof = null,
      runStart = null;
    for (const row of unique.values()) {
      if (['PENGECUALIAN_SAH', 'PENGECUALIAN_SAH_ZUHUR'].includes(row.status)) continue;
      const attendance = level.sumber_data.startsWith('PRESENSI_');
      const hit = !attendance || row.status === level.status_kehadiran_yang_dihitung,
        unknown = attendance && row.status == null;
      pending ||= unknown;
      if (level.cara_hitung === 'BERUNTUN') {
        if (!run && hit) runStart = row.tanggal;
        run = hit ? run + 1 : 0;
        possibleRun = hit || unknown ? possibleRun + 1 : 0;
        score = Math.max(score, run);
        possible = Math.max(possible, possibleRun);
        if (!proof && run >= level.target) proof = {
          start: runStart,
          end: row.tanggal
        };
      } else {
        score += Number(hit);
        possible += Number(hit || unknown);
        if (!proof && score >= level.target) proof = {
          start: period.start,
          end: row.tanggal
        };
      }
    }
    return {
      ...period,
      score,
      progress: score,
      possible,
      pending,
      proof
    };
  });
  const earned = windows.find(w => w.proof),
    visible = windows.find(w => w.end >= now) || windows.at(-1);
  return {
    progress: visible?.progress || 0,
    pending: visible?.pending || false,
    achievedOn: earned?.proof.end || null,
    proofStart: earned?.proof.start || null,
    proofEnd: earned?.proof.end || null,
    mayStillQualify: windows.some(w => w.possible >= level.target),
    current: now <= finish
  };
}
module.exports = {
  evaluateExtended,
  discipline,
  shift
};
