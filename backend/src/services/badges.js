const { Op, QueryTypes } = require('sequelize');
const { sequelize, models } = require('../models');
const { today } = require('../controllers/auth.controller');
const audit = require('../utils/audit');
const {evaluateExtended}=require('../utils/badge-evaluation');

function measure(events, method, status) {
  let score = 0, possible = 0, run = 0, possibleRun = 0, pending = false, milestones = [];
  for (const event of events) {
    if (['PENGECUALIAN_SAH','PENGECUALIAN_SAH_ZUHUR'].includes(event.status)) continue;
    const hit = event.status === status;
    const unknown = event.status == null;
    pending ||= unknown;
    if (method === 'AKUMULASI') {
      possible += Number(hit || unknown);
      if (hit) milestones[++score] = event.tanggal;
    } else {
      run = hit ? run + 1 : 0;
      possibleRun = hit || unknown ? possibleRun + 1 : 0;
      possible = Math.max(possible,possibleRun);
      if (run > score) milestones[++score] = event.tanggal;
    }
  }
  return {score,possible,pending,milestones};
}

function evaluate(level, semesters, source, now) {
  const start = semesters.find(s => s.id === level.id_semester_mulai);
  const end = semesters.find(s => s.id === level.id_semester_selesai);
  if (!start || (level.id_semester_selesai && !end) || start.tanggal_mulai > now) return null;
  const last = end?.tanggal_selesai ?? '9999-12-31';
  const applicable = semesters.filter(s => s.tanggal_mulai >= start.tanggal_mulai &&
    s.tanggal_mulai <= last && s.tanggal_mulai <= now);
  const selected = source.filter(e => e.tanggal >= start.tanggal_mulai && e.tanggal <= last &&
    e.tanggal <= now && (!level.jenis_presensi || e.jenis_sesi === level.jenis_presensi));
  const measureWindow = events => measure(events, level.cara_hitung, level.status_kehadiran_yang_dihitung);
  const windows = level.cakupan_perhitungan === 'SEMESTER'
    ? applicable.map(s => ({ semester:s, score:measureWindow(selected.filter(e => e.tanggal >= s.tanggal_mulai && e.tanggal <= s.tanggal_selesai)) }))
    : [{semester:null,score:measureWindow(selected)}];
  const visible = windows.find(w => w.semester && now <= w.semester.tanggal_selesai) || windows.at(-1);
  const earned = windows.find(w => w.score.score >= level.target);
  return {
    progress:visible?.score.score ?? 0, pending:visible?.score.pending ?? false,
    achievedOn:earned?.score.milestones[level.target] ?? null,
    mayStillQualify:windows.some(w => w.score.possible >= level.target),
    current:now <= last
  };
}

const school = `SELECT DISTINCT r.id_siswa, ss.id, ss.tanggal, ss.jenis_sesi, p.status_kehadiran AS status
  FROM sesi_presensi_sekolah ss JOIN semester sm ON sm.id=ss.id_semester
  JOIN kelas c ON c.id_tahun_ajaran=sm.id_tahun_ajaran
  JOIN riwayat_kelas_siswa r ON r.id_kelas=c.id AND r.tanggal_mulai<=ss.tanggal
    AND (r.tanggal_selesai IS NULL OR r.tanggal_selesai>=ss.tanggal)
  LEFT JOIN presensi_sekolah p ON p.id_sesi_presensi_sekolah=ss.id AND p.id_siswa=r.id_siswa
  WHERE ss.status='DITUTUP' AND ss.tanggal<=:day AND r.id_siswa IN (:students)
  ORDER BY ss.tanggal,ss.id`;
const club = `SELECT DISTINCT m.id_siswa, e.id, e.tanggal, NULL AS jenis_sesi, ep.id_ekstrakurikuler, p.status_kehadiran AS status
  FROM pertemuan_ekstrakurikuler e JOIN periode_ekstrakurikuler ep ON ep.id=e.id_periode_ekstrakurikuler JOIN keanggotaan_ekstrakurikuler m ON m.id_periode_ekstrakurikuler=e.id_periode_ekstrakurikuler
  JOIN masa_keanggotaan a ON a.id_keanggotaan_ekstrakurikuler=m.id AND a.tanggal_mulai<=e.tanggal
    AND (a.tanggal_selesai IS NULL OR a.tanggal_selesai>=e.tanggal)
  LEFT JOIN presensi_ekstrakurikuler p ON p.id_pertemuan_ekstrakurikuler=e.id AND p.id_keanggotaan_ekstrakurikuler=m.id
  WHERE e.status_presensi='DITUTUP' AND e.status_pertemuan<>'DIBATALKAN' AND e.tanggal<=:day
    AND m.id_siswa IN (:students) ORDER BY e.tanggal,e.id`;

async function context(transaction) {
  const semesters = await models.semester.findAll({transaction,order:[['tanggal_mulai','ASC']]});
  const levels = await sequelize.query(`SELECT l.*, v.id_semester_mulai,v.id_semester_selesai,v.status AS status_versi,
    b.nama AS badge,b.deskripsi,b.ikon,b.status AS status_badge
    FROM level_badge l JOIN versi_aturan_badge v ON v.id=l.id_versi_aturan_badge
    JOIN badge b ON b.id=v.id_badge ORDER BY b.nama,l.urutan,l.id`, {type:QueryTypes.SELECT,transaction});
  return { semesters, levels, day:today() };
}

async function input(students, ctx, transaction) {
  const opts = {type:QueryTypes.SELECT,replacements:{students,day:ctx.day},transaction};
  const schoolRows = await sequelize.query(school,opts);
  const clubRows = await sequelize.query(club,opts);
  const portfolioRows=await sequelize.query(`SELECT pp.id_siswa,p.id,p.tanggal,p.jenis,ep.id_ekstrakurikuler FROM peserta_portofolio pp JOIN portofolio p ON p.id=pp.id_portofolio LEFT JOIN periode_ekstrakurikuler ep ON ep.id=p.id_periode_ekstrakurikuler WHERE pp.id_siswa IN (:students) AND p.status_catatan='AKTIF' AND p.tanggal<=:day ORDER BY p.tanggal,p.id`,opts);
  const memberRows=await sequelize.query(`SELECT m.id_siswa,a.id,a.tanggal_mulai AS tanggal,a.tanggal_selesai,ep.id_ekstrakurikuler FROM keanggotaan_ekstrakurikuler m JOIN masa_keanggotaan a ON a.id_keanggotaan_ekstrakurikuler=m.id JOIN periode_ekstrakurikuler ep ON ep.id=m.id_periode_ekstrakurikuler WHERE m.id_siswa IN (:students) AND a.tanggal_mulai<=:day ORDER BY a.tanggal_mulai,a.id`,opts);
  const reportRows=await sequelize.query(`SELECT id_siswa,id,DATE(CONVERT_TZ(waktu_kejadian,'+00:00','+07:00')) AS tanggal,status_verifikasi FROM laporan_pelanggaran WHERE id_siswa IN (:students) AND DATE(CONVERT_TZ(waktu_kejadian,'+00:00','+07:00'))<=:day`,opts);
  const rosterRows=await models.riwayat_kelas.findAll({where:{id_siswa:students},raw:true,transaction});
  const achievements = await models.pencapaian.findAll({where:{id_siswa:students},transaction});
  const group = (rows, id) => {
    const result = new Map();
    for (const row of rows) {
      const key = id(row);
      if (!result.has(key)) result.set(key,[]);
      result.get(key).push(row);
    }
    return result;
  };
  return {school:group(schoolRows,r=>r.id_siswa),club:group(clubRows,r=>r.id_siswa),awards:group(achievements,r=>r.id_siswa),portfolio:group(portfolioRows,r=>r.id_siswa),members:group(memberRows,r=>r.id_siswa),reports:group(reportRows,r=>r.id_siswa),roster:group(rosterRows,r=>r.id_siswa)};
}

function studentLevels(id, ctx, data) {
  const existing = new Map((data.awards.get(id) ?? []).map(a=>[a.id_level_badge,a]));
  return ctx.levels.map(level => {
    const award = existing.get(level.id);
    const source=level.sumber_data==='PRESENSI_SEKOLAH'?data.school:level.sumber_data==='PRESENSI_EKSKUL'?data.club:level.sumber_data==='KEANGGOTAAN_EKSKUL'?data.members:data.portfolio;
    let events=source.get(id)||[];
    if(['PRESTASI','KEGIATAN'].includes(level.sumber_data))events=events.filter(e=>e.jenis===level.sumber_data);
    const legacy=level.sumber_data.startsWith('PRESENSI_')&&['AKUMULASI','BERUNTUN'].includes(level.cara_hitung)&&!level.id_ekstrakurikuler;
    const result=legacy?evaluate(level,ctx.semesters,events,ctx.day):evaluateExtended(level,ctx.semesters,{events,reports:data.reports.get(id)||[],roster:data.roster.get(id)||[]},ctx.day);
    return {level,award,result};
  });
}

async function collection(id) {
  return sequelize.transaction(async t => {
    const ctx = await context(t);
    const data = await input([id],ctx,t);
    return studentLevels(id,ctx,data).filter(({level,award,result}) =>
      level.status_badge === 'AKTIF' && (award?.aktif || (result?.current && level.status_versi === 'AKTIF'))
    ).map(({level,award,result})=>({
      id:level.id,badge:level.badge,nama:level.nama,deskripsi:level.deskripsi,ikon:level.ikon,
      sumber_data:level.sumber_data,cara_hitung:level.cara_hitung,periode_bukti_mulai:award?.periode_bukti_mulai??result?.proofStart,periode_bukti_selesai:award?.periode_bukti_selesai??result?.proofEnd,target:level.target,progress:result?.progress ?? 0,sementara:result?.pending ?? false,
      diperoleh:!!award?.aktif,waktu_diperoleh:award?.aktif ? award.waktu_diperoleh : null
    }));
  });
}

async function reconcile({studentIds} = {}) {
  const target = studentIds === undefined ? null : [...new Set(studentIds.map(Number))];
  if(target && (!target.length || target.some(id=>!Number.isSafeInteger(id)||id<1))) return {skipped:false,changed:0};
  // A database advisory lock serializes scheduled jobs and the manual command across processes.
  const connection = await sequelize.connectionManager.getConnection({type:'WRITE'});
  const query = sql => new Promise((resolve,reject)=>connection.query(sql,(error,result)=>error?reject(error):resolve(result)));
  let acquired = false;
  let changed = 0;
  try {
    const [lock] = await query("SELECT GET_LOCK(CONCAT(DATABASE(), ':badge'),0) AS acquired");
    acquired = lock.acquired === 1;
    if (!acquired) return {skipped:true,changed};
    let after = 0;
    for (;;) {
      const students = await models.siswa.findAll({where:{id:{[Op.gt]:after,...(target?{[Op.in]:target}:{})}},attributes:['id'],order:[['id','ASC']],limit:100});
      if (!students.length) return {skipped:false,changed};
      const ids = students.map(s=>s.id);
      await sequelize.transaction(async t => {
        const ctx = await context(t);
        const data = await input(ids,ctx,t);
        for (const id of ids) for (const {level,award,result} of studentLevels(id,ctx,data)) {
          if (!result) continue;
          const eligible = result.achievedOn && level.status_badge==='AKTIF' && level.status_versi==='AKTIF';
          if (!award && eligible) {
            const row = await models.pencapaian.create({
              id_siswa:id,id_level_badge:level.id,waktu_diperoleh:new Date(),
              aktif:true,waktu_perubahan_status:new Date(),periode_bukti_mulai:result.proofStart??null,periode_bukti_selesai:result.proofEnd??null
            },{transaction:t});
            await audit({},'pencapaian',row.id,null,{aktif:true},'BERI_BADGE',t);
            changed++;
          } else if (award && ((!award.aktif && eligible) || (award.aktif && !result.achievedOn && !result.mayStillQualify))) {
            const before = award.aktif;
            await award.update({aktif:!before,waktu_perubahan_status:new Date()},{transaction:t});
            await audit({},'pencapaian',award.id,{aktif:before},{aktif:award.aktif},award.aktif?'AKTIFKAN_BADGE':'CABUT_BADGE',t);
            changed++;
          }
          if(award && result.achievedOn && result.proofStart && (award.periode_bukti_mulai!==result.proofStart||award.periode_bukti_selesai!==result.proofEnd)){
            const before={periode_bukti_mulai:award.periode_bukti_mulai,periode_bukti_selesai:award.periode_bukti_selesai};
            await award.update({periode_bukti_mulai:result.proofStart,periode_bukti_selesai:result.proofEnd},{transaction:t});
            await audit({},'pencapaian',award.id,before,{periode_bukti_mulai:result.proofStart,periode_bukti_selesai:result.proofEnd},'PERBARUI_BUKTI_BADGE',t);
          }
        }
      });
      after = ids.at(-1);
    }
  } finally {
    try { if (acquired) await query("SELECT RELEASE_LOCK(CONCAT(DATABASE(), ':badge'))"); }
    finally { await sequelize.connectionManager.releaseConnection(connection); }
  }
}

module.exports = { collection,reconcile,measure,evaluate };
