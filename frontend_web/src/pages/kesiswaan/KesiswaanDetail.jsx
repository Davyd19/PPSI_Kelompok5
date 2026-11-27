import { useEffect, useState } from 'react';
import { apiRequest } from '../../api/client';
import { useConfirm } from '../../hooks/useConfirm';
import { Notice, LoadingState, StatusBadge, EmptyState } from '../../components/ManagementUi';
import { Rows } from './KesiswaanForms';
const base = '/kesiswaan';
const label = v => String(v ?? '—').replaceAll('_', ' ');
const time = v => v ? new Intl.DateTimeFormat('id-ID', {
  dateStyle: 'medium',
  timeStyle: 'short',
  timeZone: 'Asia/Jakarta'
}).format(new Date(v)) : '—';
function Facts({
  items
}) {
  return <dl className="ks-detail-grid">{items.map(([title, value]) => <div key={title}><dt>{title}</dt><dd>{value || '—'}</dd></div>)}</dl>;
}
function History({
  rows = []
}) {
  return rows.length ? <div>{rows.map(r => <article className="ksi-history" key={r.id}><strong>{label(r.jenis || r.jenis_tindakan)}</strong><small>{time(r.waktu)}</small><p>{r.ringkasan_diizinkan || r.hasil_keputusan || r.alasan || 'Perubahan tercatat.'}</p>{r.alasan_keputusan && <p>Alasan: {r.alasan_keputusan}</p>}{r.arahan_tindak_lanjut && <p>Arahan: {r.arahan_tindak_lanjut}</p>}</article>)}</div> : <p className="ks-empty">Belum ada riwayat yang dapat ditampilkan.</p>;
}
export default function KesiswaanDetail({
  section,
  id,
  query,
  back,
  open,
  download,
  onForm,
  onChange
}) {
  const [loaded, setLoaded] = useState(null),
    [error, setError] = useState(''),
    [retry, setRetry] = useState(0),
    [busy, setBusy] = useState(false);
  const [tab, setTab] = useState(new URLSearchParams(window.location.search).get('detailTab') || 'summary');
  const confirm = useConfirm();
  useEffect(() => {
    const controller = new AbortController();
    apiRequest(`${base}/${section}/${id}?${query}`, {
      signal: controller.signal
    }).then(({
      data
    }) => {
      setLoaded(data);
      setError('');
    }).catch(e => {
      if (e.name !== 'AbortError') setError(e.message);
    });
    return () => controller.abort();
  }, [section, id, query, retry]);
  async function remove(path, title, message) {
    if (busy || !(await confirm({
      title,
      message,
      danger: true,
      accept: 'Hapus data'
    }))) return;
    setBusy(true);
    setError('');
    try {
      await apiRequest(base + path, {
        method: 'DELETE'
      });
      if (path === `/categories/${id}`) {
        back();
        onChange();
      } else {
        setRetry(n => n + 1);
        onChange();
      }
    } catch (e) {
      setError(e.message);
    } finally {
      setBusy(false);
    }
  }
  const studentLink = (studentId, name) => <button className="ks-link" onClick={() => open('students', {
    id: studentId
  })}>{name}</button>;
  if (!loaded) return <div className="ks-content"><button onClick={back}>Kembali</button>{error ? <Notice message={error} error onClose={() => setError('')} /> : <LoadingState />}{error && <button onClick={() => setRetry(n => n + 1)}>Coba lagi</button>}</div>;
  const data = loaded;
  function changeTab(value) {
    setTab(value);
    const url = new URL(window.location.href);
    url.searchParams.set('detailTab', value);
    window.history.replaceState(window.history.state, '', url.pathname + url.search);
  }
  return <div className="ks-content ksi-detail"><button className="ks-link ks-back" onClick={back}>← Kembali</button><Notice message={error} error onClose={() => setError('')} />
 {section === 'students' && <>
  <header className="ksi-hero"><div className="ksi-avatar">{data.siswa.nama.slice(0, 2).toUpperCase()}</div><div><span className="ks-eyebrow">Profil siswa</span><h1>{data.siswa.nama}</h1><p>NISN {data.siswa.nisn} · {data.kelas_sekarang?.nama || 'Belum memiliki kelas aktif'}</p></div><div className="ks-actions"><button onClick={() => onForm('createReport', null, data.siswa)}>Catat pelanggaran</button><button className="ks-primary" onClick={() => onForm('achievement', null, data.siswa)}>Catat prestasi</button></div></header>
  <nav className="ksi-tabs" aria-label="Bagian profil siswa">{[['summary', 'Ringkasan'], ['attendance', 'Kehadiran'], ['reports', 'Pelanggaran'], ['handling', 'Penanganan yang Diizinkan'], ['achievements', 'Prestasi']].map(([value, title]) => <button key={value} aria-pressed={tab === value} onClick={() => changeTab(value)}>{title}</button>)}</nav>
  <section className="ks-panel"><div className="ks-panel-heading"><h2>{{
              summary: 'Ringkasan siswa',
              attendance: 'Riwayat kehadiran',
              reports: 'Laporan pelanggaran',
              handling: 'Pendampingan yang dibagikan',
              achievements: 'Prestasi aktif'
            }[tab] || 'Ringkasan siswa'}</h2><span className="ks-chip">{data.periode.mulai} – {data.periode.sampai}</span></div>
  {tab === 'summary' && <><Facts items={[["Nama", data.siswa.nama], ["NISN", data.siswa.nisn], ["NIS", data.siswa.nis], ["Kelas sekarang", data.kelas_sekarang?.nama], ["Tahun ajaran", data.kelas_sekarang?.tahun_ajaran], ["Status siswa", label(data.siswa.status_siswa)]]} /><div className="ksi-metrics">{[['Laporan', data.reports.length, 'reports'], ['Presensi tercatat', data.attendance.filter(r => r.status_kehadiran !== 'BELUM_DIISI').length, 'attendance'], ['Prestasi', data.achievements.length, 'achievements'], ['Pendampingan', data.handling.length, 'handling']].map(([title, value, target]) => <button key={target} onClick={() => changeTab(target)}><strong>{value}</strong><span>{title}</span></button>)}</div></>}
  {tab === 'reports' && <Rows items={data.reports} headers={['Kategori', 'Kelas saat kejadian', 'Waktu', 'Status', 'Aksi']} onOpen={r => open('reports', r)} render={r => <><td>{r.kategori}</td><td>{r.kelas || '—'}</td><td>{time(r.waktu_kejadian)}</td><td><StatusBadge value={r.status_verifikasi}>{label(r.status_verifikasi)}</StatusBadge></td><td><button onClick={() => open('reports', r)}>Detail laporan</button></td></>} />}
  {tab === 'attendance' && <Rows items={data.attendance} headers={['Tanggal', 'Sesi', 'Kelas saat sesi', 'Status']} render={r => <><td>{r.tanggal}</td><td>{r.jenis_sesi}</td><td>{r.kelas}</td><td><StatusBadge value={r.status_kehadiran}>{label(r.status_kehadiran)}</StatusBadge></td></>} />}
  {tab === 'handling' && (data.handling.length ? data.handling.map(h => <article className="ksi-history" key={h.id}><h3>Pendampingan #{h.id}</h3><p>{label(h.status)} · Dibuka {h.tanggal_dibuka}</p><p>{h.ringkasan_diizinkan || 'Ringkasan belum dibagikan.'}</p><History rows={h.riwayat} /></article>) : <EmptyState />)}
  {tab === 'achievements' && <Rows items={data.achievements} headers={['Prestasi', 'Tanggal', 'Hasil', 'Sumber', 'Aksi']} onOpen={r => open('achievements', r)} render={r => <><td>{r.judul}</td><td>{r.tanggal}</td><td>{r.hasil_prestasi}</td><td>{r.id_periode_ekstrakurikuler ? 'Ekstrakurikuler' : 'Sekolah / non-ekskul'}</td><td><button onClick={() => open('achievements', r)}>Detail prestasi</button></td></>} />}
  </section>
 </>}
 {section === 'categories' && <>
  <header className="ksi-hero"><div><span className="ks-eyebrow">Kategori & aturan</span><h1>{data.nama}</h1><p>{data.deskripsi || 'Kelola identitas dan riwayat ketentuan dalam satu halaman.'}</p></div><StatusBadge value={data.status}>{label(data.status)}</StatusBadge><div className="ks-actions"><button onClick={() => onForm('category', data)}>Ubah kategori</button><button className="ks-primary" onClick={() => onForm('version', data)}>Versi baru</button><button className="ksi-danger" disabled={busy} onClick={() => remove(`/categories/${id}`, 'Hapus kategori?', `Kategori ${data.nama} beserta versi yang belum berlaku akan dihapus. Aturan berlaku/riwayat laporan tidak dapat dihapus.`)}>Hapus</button></div></header>
  <section className="ks-panel"><h2>Versi aturan</h2><div className="ksi-rule-grid">{data.versions.map(v => <article className="ksi-rule" key={v.id}><div className="ks-panel-heading"><h3>Versi {v.nomor_versi}</h3><span className="ks-chip">{v.editable ? 'Terjadwal · dapat diubah' : 'Terkunci / historis'}</span></div><p>{v.berlaku_mulai} – {v.berlaku_sampai || 'seterusnya'}</p><p className="ks-report-text">{v.ketentuan}</p>{v.editable && <div className="ks-actions"><button onClick={() => onForm('editVersion', v)}>Ubah versi</button><button disabled={busy} className="ksi-danger" onClick={() => remove(`/categories/${id}/versions/${v.id}`, 'Hapus versi terjadwal?', `Versi ${v.nomor_versi} yang belum berlaku dan belum digunakan akan dihapus.`)}>Hapus versi</button></div>}</article>)}</div></section>
  <section className="ks-panel"><h2>Laporan terkait pada periode terpilih</h2><Rows items={data.reports} headers={['Siswa', 'Waktu', 'Versi', 'Status', 'Aksi']} render={r => <><td>{studentLink(r.id_siswa, r.siswa)}</td><td>{time(r.waktu_kejadian)}</td><td>{r.nomor_versi}</td><td>{label(r.status_verifikasi)}</td><td><button onClick={() => open('reports', r)}>Detail</button></td></>} /></section>
 </>}
 {section === 'achievements' && <>
  <header className="ksi-hero"><div><span className="ks-eyebrow">Prestasi siswa</span><h1>{data.judul}</h1><p>{data.id_periode_ekstrakurikuler ? 'Dikelola Pembina Ekstrakurikuler · baca saja' : 'Prestasi sekolah / non-ekstrakurikuler'}</p></div><StatusBadge value={data.status_catatan}>{label(data.status_catatan)}</StatusBadge>{data.editable && <div className="ks-actions"><button className="ks-primary" onClick={() => onForm('achievement', data)}>Ubah prestasi</button><button onClick={() => onForm('attachment', data)}>Tambah bukti</button><button className="ksi-danger" onClick={() => onForm('cancel', data)}>Batalkan prestasi</button></div>}</header>
  <section className="ks-panel"><Facts items={[["Tanggal", data.tanggal], ["Tingkat", data.tingkat_prestasi], ["Hasil", data.hasil_prestasi], ["Tim", data.nama_tim]]} /><p className="ks-report-text">{data.deskripsi || '—'}</p><h2>Peserta</h2><div className="ksi-participants">{data.peserta_id_portofolio.map(p => <span key={p.id_siswa}>{studentLink(p.id_siswa, p.siswa?.nama)}<small>{p.siswa?.nisn}</small></span>)}</div></section>
  <section className="ks-panel"><h2>Bukti pendukung</h2>{data.lampiran_id_portofolio.length ? data.lampiran_id_portofolio.map(f => <button className="ksi-file" key={f.id} onClick={() => download(`/attachments/${f.id}`, f.nama_berkas)}>{f.nama_berkas}<small>{f.jenis_berkas}</small></button>) : <p>Belum ada lampiran.</p>}</section>
  <section className="ks-panel"><h2>Riwayat perubahan</h2><History rows={data.history} /></section>
 </>}
 </div>;
}
