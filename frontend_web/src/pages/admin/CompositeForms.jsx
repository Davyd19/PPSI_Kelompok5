import { useRef, useState } from 'react';
import Button from '../../components/Button';
import Icon from '../../components/Icon';
import { apiRequest } from '../../api/client';
import { RelationField } from './AdminForms';
import { useConfirm } from '../../hooks/useConfirm';
import { today } from '../../utils/calendar';
const normalize = values => Object.fromEntries(Object.entries(values).map(([key, value]) => [key, value === '' ? null : value]));
function Fields({
  spec,
  values,
  setValues
}) {
  return <div className="admin-form-grid">{spec.fields.map(f => <label className="admin-field" key={f.name}>{f.label}{!f.nullable ? ' *' : ''}{f.options ? <select value={values[f.name] ?? ''} onChange={e => setValues(v => ({
        ...v,
        [f.name]: e.target.value
      }))}><option value="">Pilih</option>{f.options.map(o => <option key={o}>{o}</option>)}</select> : <input type={f.name === 'email' ? 'email' : 'text'} value={values[f.name] ?? ''} onChange={e => setValues(v => ({
        ...v,
        [f.name]: e.target.value
      }))} />}</label>)}<label className="admin-field">Kata sandi awal *<input type="password" autoComplete="new-password" minLength={10} maxLength={128} value={values.kata_sandi ?? ''} onChange={e => setValues(v => ({
        ...v,
        kata_sandi: e.target.value
      }))} /><small>10–128 karakter; sampaikan secara pribadi.</small></label></div>;
}
export function StudentForm({
  metadata,
  studentId,
  onSaved,
  onClose
}) {
  const confirm = useConfirm(),
    lock = useRef(false);
  const [step, setStep] = useState(studentId ? 2 : 0),
    [student, setStudent] = useState({
      status_siswa: 'AKTIF',
      status_akun: 'AKTIF'
    }),
    [parent, setParent] = useState({
      status_akun: 'AKTIF'
    }),
    [mode, setMode] = useState(studentId ? 'existing' : 'none'),
    [parentId, setParentId] = useState(''),
    [classId, setClassId] = useState(''),
    [date, setDate] = useState(today()),
    [relation, setRelation] = useState('WALI'),
    [error, setError] = useState(''),
    [busy, setBusy] = useState(false);
  const close = async () => {
    if (!busy && (await confirm({
      title: 'Tutup formulir?',
      message: 'Isian yang belum disimpan akan dibuang.',
      accept: 'Tutup Formulir'
    }))) onClose();
  };
  async function submit(e) {
    e.preventDefault();
    if (lock.current) return;
    lock.current = true;
    setBusy(true);
    setError('');
    try {
      if (!studentId) {
        const missing = metadata.siswa.fields.find(f => !f.nullable && !student[f.name] && student[f.name] !== false);
        if (missing || !student.kata_sandi) {
          setStep(0);
          throw Error('Lengkapi ' + (missing?.label || 'kata sandi awal siswa') + '.');
        }
      }
      if (mode === 'new') {
        const missing = metadata.orang_tua.fields.find(f => !f.nullable && !parent[f.name]);
        if (missing || !parent.kata_sandi) {
          setStep(2);
          throw Error('Lengkapi ' + (missing?.label || 'kata sandi awal') + ' orang tua.');
        }
      }
      if (mode === 'existing' && !parentId) {
        setStep(2);
        throw Error('Pilih akun orang tua terlebih dahulu.');
      }
      if (studentId && mode === 'none') throw Error('Pilih akun orang tua atau buat akun baru.');
      const link = mode === 'none' ? null : {
        ...(mode === 'new' ? {
          data: normalize(parent)
        } : {
          id_orang_tua: Number(parentId)
        }),
        jenis_hubungan: relation,
        tanggal_mulai: date
      };
      await apiRequest('/admin/workflows/' + (studentId ? 'parent-link' : 'student'), {
        method: 'POST',
        body: studentId ? {
          id_siswa: studentId,
          orang_tua: link
        } : {
          siswa: normalize(student),
          ...(classId ? {
            kelas: {
              id_kelas: Number(classId),
              tanggal_mulai: date
            }
          } : {}),
          ...(link ? {
            orang_tua: link
          } : {})
        }
      });
      onSaved('Data dan keterkaitannya berhasil disimpan.');
    } catch (e) {
      setError(e.message);
    } finally {
      lock.current = false;
      setBusy(false);
    }
  }
  return <section className="card admin-editor-page"><div className="card-heading"><div><span className="eyebrow">PENGELOLAAN TERINTEGRASI</span><h2>{studentId ? 'Hubungkan Orang Tua' : 'Tambah Siswa'}</h2></div><Button onClick={close} disabled={busy}>Tutup</Button></div>{!studentId && <div className="admin-steps">{['Identitas & akun', 'Kelas', 'Orang tua', 'Tinjau'].map((s, i) => <Button key={s} disabled={busy} className={step === i ? 'selected' : ''} onClick={() => setStep(i)}>{i + 1}. {s}</Button>)}</div>}<form onSubmit={submit}><fieldset disabled={busy} className="mg-form-fields">{step === 0 && <Fields spec={metadata.siswa} values={student} setValues={setStudent} />} {step === 1 && <div className="admin-form-section"><h3>Kelas awal</h3><p>Boleh dilewati dan dilengkapi dari detail siswa atau kelas.</p><RelationField field={{
            ref: 'kelas',
            label: 'Kelas'
          }} value={classId} onChange={setClassId} /></div>}{step === 2 && <div className="admin-form-section"><h3>Orang tua / wali</h3><p>Jika orang tua sudah memiliki akun untuk anak lain, gunakan akun yang sama.</p><div className="admin-tabs">{[...(!studentId ? [['none', 'Nanti saja']] : []), ['existing', 'Pilih akun'], ['new', 'Buat akun baru']].map(([key, label]) => <Button key={key} className={mode === key ? 'selected' : ''} onClick={() => setMode(key)}>{label}</Button>)}</div>{mode === 'existing' && <RelationField field={{
            ref: 'orang_tua',
            label: 'Orang tua'
          }} value={parentId} onChange={setParentId} />} {mode === 'new' && <Fields spec={metadata.orang_tua} values={parent} setValues={setParent} />} {mode !== 'none' && <label className="admin-field">Hubungan<select value={relation} onChange={e => setRelation(e.target.value)}><option value="AYAH">Ayah</option><option value="IBU">Ibu</option><option value="WALI">Wali</option></select></label>}</div>}{step === 3 && <div className="admin-review"><Icon name="check" size={28} /><h3>Periksa sebelum menyimpan</h3><dl><dt>Siswa</dt><dd>{student.nama || 'Belum diisi'}</dd><dt>Identitas akun</dt><dd>{student.identitas_login || 'Belum diisi'}</dd><dt>Kelas</dt><dd>{classId ? 'Kelas dipilih' : 'Dilengkapi nanti'}</dd><dt>Orang tua</dt><dd>{mode === 'new' ? parent.nama : mode === 'existing' ? 'Menggunakan akun yang ada' : 'Dilengkapi nanti'}</dd></dl><p>Seluruh bagian disimpan dalam satu transaksi. Jika gagal, tidak ada akun atau hubungan setengah jadi.</p></div>}{(step === 1 || step === 2 || step === 3) && <label className="admin-field">Tanggal mulai kelas / hubungan<input type="date" value={date} onChange={e => setDate(e.target.value)} /></label>}</fieldset>{error && <p className="form-error" role="alert">{error}</p>}<div className="form-actions"><Button onClick={close} disabled={busy}>Batal</Button>{!studentId && step < 3 ? <Button className="primary" disabled={busy} onClick={() => setStep(step + 1)}>Lanjut</Button> : <Button className="primary" type="submit" disabled={busy}>{busy ? 'Menyimpan…' : 'Simpan Semua'}</Button>}</div></form></section>;
}
export function BadgeForm({
  catalog,
  semesters,
  existing,
  onSaved,
  onClose
}) {
  const confirm = useConfirm(),
    lock = useRef(false),
    next = existing?.relations.find(g => g.resource === 'versi_badge')?.rows ?? [];
  const [step, setStep] = useState(0),
    [badge, setBadge] = useState({
      nama: existing?.row.nama || '',
      deskripsi: existing?.row.deskripsi || '',
      ikon: existing?.row.ikon || 'medal',
      status: 'AKTIF'
    }),
    [semester, setSemester] = useState(semesters.find(s => existing ? s.tanggal_mulai > today() : s.tanggal_mulai <= today() && s.tanggal_selesai >= today())?.id || ''),
    [end, setEnd] = useState(''),
    [levels, setLevels] = useState([{
      nama: 'Perunggu',
      sumber_data: 'PRESENSI_SEKOLAH',
      cara_hitung: 'AKUMULASI',
      target: 10,
      jenis_presensi: 'PAGI',
      cakupan_perhitungan: 'SEMESTER',
      id_ekstrakurikuler: null
    }]),
    [error, setError] = useState(''),
    [busy, setBusy] = useState(false);
  const patch = (i, data) => setLevels(rows => rows.map((r, n) => n === i ? {
    ...r,
    ...data
  } : r));
  const close = async () => {
    if (!busy && (await confirm({
      title: 'Tutup rancangan badge?',
      message: 'Perubahan yang belum disimpan akan dibuang.',
      accept: 'Tutup Rancangan'
    }))) onClose();
  };
  async function submit(e) {
    e.preventDefault();
    if (lock.current) return;
    lock.current = true;
    setBusy(true);
    setError('');
    try {
      if (!badge.nama.trim()) {
        setStep(0);
        throw Error('Nama badge wajib diisi.');
      }
      if (!semester) {
        setStep(1);
        throw Error('Pilih semester mulai. Buat semester mendatang pada Kelas & Akademik bila diperlukan.');
      }
      if (levels.some(l => !l.nama.trim() || !Number.isSafeInteger(Number(l.target)) || Number(l.target) < 1)) {
        setStep(1);
        throw Error('Lengkapi nama level dan target bilangan bulat minimal 1.');
      }
      await apiRequest('/admin/workflows/badge', {
        method: 'POST',
        body: {
          ...(existing ? {
            id_badge: existing.row.id
          } : {
            badge: normalize(badge)
          }),
          versi: {
            nomor_versi: Math.max(0, ...next.map(v => v.nomor_versi)) + 1,
            id_semester_mulai: Number(semester),
            id_semester_selesai: end ? Number(end) : null,
            status: 'AKTIF'
          },
          levels: levels.map(l => ({
            ...l,
            target: Number(l.target),
            jenis_presensi: l.sumber_data === 'PRESENSI_SEKOLAH' ? l.jenis_presensi : null,
            status_kehadiran_yang_dihitung: l.sumber_data.startsWith('PRESENSI_') ? 'HADIR' : null,
            id_ekstrakurikuler: ['PRESENSI_SEKOLAH', 'PELANGGARAN'].includes(l.sumber_data) ? null : l.id_ekstrakurikuler ? Number(l.id_ekstrakurikuler) : null
          }))
        }
      });
      onSaved('Badge beserta aturan dan level berhasil disimpan.');
    } catch (e) {
      setError(e.message);
    } finally {
      lock.current = false;
      setBusy(false);
    }
  }
  return <section className="card admin-editor-page"><div className="card-heading"><div><span className="eyebrow">BADGE OTOMATIS</span><h2>{existing ? 'Versi Aturan Baru' : 'Buat Badge'}</h2></div><Button onClick={close} disabled={busy}>Tutup</Button></div><div className="admin-steps">{['Identitas & ikon', 'Aturan & level', 'Tinjau'].map((label, i) => <Button key={label} className={step === i ? 'selected' : ''} disabled={busy} onClick={() => setStep(i)}>{i + 1}. {label}</Button>)}</div><form onSubmit={submit}><fieldset disabled={busy} className="mg-form-fields">{step === 0 && <><label className="admin-field">Nama badge<input disabled={!!existing} value={badge.nama} onChange={e => setBadge({
              ...badge,
              nama: e.target.value
            })} /></label><label className="admin-field">Deskripsi<textarea disabled={!!existing} value={badge.deskripsi} onChange={e => setBadge({
              ...badge,
              deskripsi: e.target.value
            })} /></label><p>Pilih ikon yang akan ditampilkan pada aplikasi siswa.</p><div className="admin-icon-picker">{catalog.icons.map(icon => <button type="button" key={icon} disabled={!!existing} aria-label={`Ikon ${icon}`} aria-pressed={badge.ikon === icon} className={badge.ikon === icon ? 'selected' : ''} onClick={() => setBadge({
              ...badge,
              ikon: icon
            })}><Icon name={icon} size={25} /><small>{icon}</small></button>)}</div></>}{step === 1 && <><div className="admin-form-grid"><label className="admin-field">Mulai semester<select value={semester} onChange={e => setSemester(e.target.value)}><option value="">Pilih semester</option>{semesters.filter(s => !existing || s.tanggal_mulai > today()).map(s => <option key={s.id} value={s.id}>{s.nama} · {s.tahun_ajaran?.nama || s.tanggal_mulai}</option>)}</select></label><label className="admin-field">Sampai semester (opsional)<select value={end} onChange={e => setEnd(e.target.value)}><option value="">Terus berlaku</option>{semesters.map(s => <option key={s.id} value={s.id}>{s.nama} · {s.tahun_ajaran?.nama || s.tanggal_mulai}</option>)}</select></label></div><p className="muted">{existing ? 'Aturan baru mulai semester mendatang. Rentang versi sebelumnya disesuaikan dalam transaksi yang sama.' : 'Semester berjalan menghitung data sejak awal semester. Aturan yang sudah berlaku dilindungi dari perubahan.'}</p>{levels.map((l, i) => {
            const source = catalog.sources.find(s => s.code === l.sumber_data);
            return <section className="admin-level" key={i}><div className="card-heading"><h3>Level {i + 1}</h3>{levels.length > 1 && <Button onClick={() => setLevels(rows => rows.filter((_, n) => n !== i))}>Hapus level</Button>}</div><div className="admin-form-grid"><label className="admin-field">Nama level<input value={l.nama} onChange={e => patch(i, {
                    nama: e.target.value
                  })} /></label><label className="admin-field">Data yang dihitung<select value={l.sumber_data} onChange={e => {
                    const s = catalog.sources.find(s => s.code === e.target.value);
                    patch(i, {
                      sumber_data: s.code,
                      cara_hitung: s.methods[0],
                      jenis_presensi: s.code === 'PRESENSI_SEKOLAH' ? 'PAGI' : null,
                      id_ekstrakurikuler: null
                    });
                  }}>{catalog.sources.map(s => <option key={s.code} value={s.code}>{s.label}</option>)}</select></label><label className="admin-field">Cara hitung<select value={l.cara_hitung} onChange={e => patch(i, {
                    cara_hitung: e.target.value,
                    ...(e.target.value === 'PERSENTASE' ? {
                      cakupan_perhitungan: 'SEMESTER'
                    } : {})
                  })}>{source.methods.map(m => <option key={m} value={m}>{{
                        AKUMULASI: 'Akumulasi',
                        BERUNTUN: 'Beruntun',
                        PERSENTASE: 'Persentase (dinilai setelah semester)',
                        HARI_TANPA_PELANGGARAN: 'Hari penuh tanpa pelanggaran'
                      }[m]}</option>)}</select></label><label className="admin-field">Target ({l.cara_hitung === 'PERSENTASE' ? '%' : source.unit})<input type="number" min="1" max={l.cara_hitung === 'PERSENTASE' ? 100 : undefined} value={l.target} onChange={e => patch(i, {
                    target: e.target.value
                  })} /></label>{l.sumber_data === 'PRESENSI_SEKOLAH' && <label className="admin-field">Jenis presensi<select value={l.jenis_presensi} onChange={e => patch(i, {
                    jenis_presensi: e.target.value
                  })}><option value="PAGI">Pagi</option><option value="ZUHUR">Zuhur</option></select></label>}<label className="admin-field">Cakupan<select value={l.cakupan_perhitungan} onChange={e => patch(i, {
                    cakupan_perhitungan: e.target.value
                  })}><option value="SEMESTER">Per semester</option>{l.cara_hitung !== 'PERSENTASE' && <option value="MASA_BERLAKU_VERSI">Selama versi berlaku</option>}</select></label></div>{!['PRESENSI_SEKOLAH', 'PELANGGARAN'].includes(l.sumber_data) && <div className="admin-field"><label>Filter ekskul (kosong = semua)</label><RelationField field={{
                  ref: 'ekskul',
                  label: 'Ekstrakurikuler'
                }} value={l.id_ekstrakurikuler} onChange={v => patch(i, {
                  id_ekstrakurikuler: v
                })} /></div>}{l.sumber_data === 'PELANGGARAN' && <p className="admin-info">Pelanggaran terverifikasi memutus rangkaian pada tanggal kejadian. Laporan menunggu verifikasi membuat progres sementara. Pencapaian sah sebelumnya tetap tersimpan.</p>}</section>;
          })}<Button disabled={levels.length >= 20} onClick={() => setLevels(rows => [...rows, {
            ...rows.at(-1),
            nama: 'Level ' + (rows.length + 1),
            target: Number(rows.at(-1).target) + 10
          }])}>+ Tambah Level</Button></>}{step === 2 && <div className="admin-review"><span className="admin-badge-preview"><Icon name={badge.ikon} size={48} /></span><h3>{badge.nama || 'Nama badge'}</h3><p>{badge.deskripsi}</p>{levels.map((l, i) => <div key={i} className="admin-preview-level"><strong>{l.nama}</strong><span>{catalog.sources.find(s => s.code === l.sumber_data)?.label} · target {l.target}{l.cara_hitung === 'PERSENTASE' ? '%' : ''}</span></div>)}<p>Satu syarat per level. Pencapaian dihitung otomatis; tidak ada pemberian badge manual.</p></div>}</fieldset>{error && <p className="form-error" role="alert">{error}</p>}<div className="form-actions"><Button onClick={close} disabled={busy}>Batal</Button>{step < 2 ? <Button className="primary" onClick={() => setStep(step + 1)}>Lanjut</Button> : <Button className="primary" type="submit" disabled={busy}>{busy ? 'Menyimpan…' : 'Simpan Badge'}</Button>}</div></form></section>;
}
