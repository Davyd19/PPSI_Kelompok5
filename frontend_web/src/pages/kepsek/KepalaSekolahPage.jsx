import { useCallback, useEffect, useState } from 'react';
import { Navigate, useParams } from 'react-router-dom';
import { apiRequest } from '../../api/client';
import Icon from '../../components/Icon';
import PortalShell from '../../components/PortalShell';
import './kepsek.css';

const base = '/kepala-sekolah';
const sections = {
  dashboard: ['Ringkasan eksekutif', 'dashboard'], kasus: ['Kasus & penanganan', 'shield'],
  ekskul: ['Ekstrakurikuler', 'activity'], laporan: ['Laporan sekolah', 'chart'],
};
const sectionInfo = {
  dashboard: ['Ringkasan Eksekutif', 'Gambaran kehadiran, kasus, dan kegiatan siswa pada periode terpilih.'],
  kasus: ['Kasus & Penanganan', 'Jumlah dan status penanganan. Isi konseling dan identitas siswa tidak ditampilkan.'],
  ekskul: ['Ekstrakurikuler', 'Keanggotaan, pertemuan, kehadiran, dan prestasi kegiatan tahun ajaran aktif.'],
  laporan: ['Laporan Sekolah', 'Unduh ringkasan agregat untuk rapat atau arsip pimpinan.'],
};
const endpoints = { dashboard: 'dashboard', laporan: 'dashboard', kasus: 'kasus', ekskul: 'ekskul' };
const palette = ['navy', 'teal', 'amber', 'green', 'heather', 'brick'];
const paletteHex = { navy: '#26476f', teal: '#2b7c86', amber: '#b3842f', green: '#3f7f5f', heather: '#77679a', brick: '#b0584f' };
const caseTone = { TERBUKA: 'brick', DALAM_PENANGANAN: 'amber', SELESAI: 'green', DITUTUP: 'navy' };
const caseLabels = { TERBUKA: 'Terbuka', DALAM_PENANGANAN: 'Dalam penanganan', SELESAI: 'Selesai', DITUTUP: 'Ditutup' };
const levelLabels = { SEKOLAH: 'Sekolah', KOTA: 'Kota/Kabupaten', KABUPATEN: 'Kota/Kabupaten', PROVINSI: 'Provinsi', NASIONAL: 'Nasional', INTERNASIONAL: 'Internasional' };

const percent = v => v == null ? '–' : `${String(v).replace('.', ',')}%`;
const iso = d => d.toISOString().slice(0, 10);
const shortDate = s => new Date(`${s}T00:00:00`).toLocaleDateString('id-ID', { day: 'numeric', month: 'short' });
const longDate = s => new Date(`${s}T00:00:00`).toLocaleDateString('id-ID', { day: 'numeric', month: 'long', year: 'numeric' });
const rangeOf = days => { const e = new Date(), s = new Date(e - (days - 1) * 86400000); return { mulai: iso(s), sampai: iso(e) }; };

// Data disimpan bersama path asalnya agar bagian baru tidak pernah dirender dengan data milik bagian lain.
function useData(path) {
  const [state, setState] = useState({ path: null, error: '', data: null });
  const [attempt, setAttempt] = useState(0);
  useEffect(() => {
    const c = new AbortController();
    apiRequest(path, { signal: c.signal }).then(r => setState({ path, error: '', data: r.data }))
      .catch(e => { if (!c.signal.aborted) setState({ path, error: e.message, data: null }); });
    return () => c.abort();
  }, [path, attempt]);
  const current = state.path === path;
  return { loading: !current, error: current ? state.error : '', data: current ? state.data : null,
    retry: () => { setState(s => ({ ...s, path: null })); setAttempt(n => n + 1); } };
}

function Panel({ title, note, aside, className = '', children }) {
  return <section className={`ks-panel kp-panel ${className}`}>
    <div className="ks-panel-heading"><div><h2>{title}</h2>{note && <p>{note}</p>}</div>{aside}</div>
    {children}
  </section>;
}
const Empty = ({ children }) => <p className="ks-empty kp-empty">{children}</p>;
function Metric({ label, value, detail, icon, meter }) {
  return <article>
    <span>{label}</span><span className="ks-stat-icon"><Icon name={icon} size={18}/></span>
    <strong>{value}</strong>
    {meter != null && <div className="kp-meter" aria-hidden="true"><span style={{ width: `${Math.min(100, meter)}%` }}/></div>}
    <small>{detail}</small>
  </article>;
}
function Rows({ rows, label, value, render, offset = 0 }) {
  if (!rows.length) return <Empty>Belum ada data pada periode ini.</Empty>;
  const top = Math.max(1, ...rows.map(r => r[value]));
  return <ul className="kp-rows">{rows.map((r, i) => <li key={r[label]} className={`c-${r.tone ?? palette[(i + offset) % palette.length]}`}>
    <div><span>{r[label]}</span><b>{render ? render(r) : r[value]}</b></div>
    <div className="kp-track"><span style={{ width: `${r[value] / top * 100}%` }}/></div>
  </li>)}</ul>;
}
function Columns({ points }) {
  if (!points.length) return <Empty>Belum ada sesi presensi yang ditutup pada periode ini.</Empty>;
  return <div className="kp-columns" role="img" aria-label={points.map(p => `${shortDate(p.tanggal)} ${percent(p.persen)}`).join(', ')}>
    <div className="kp-plot">
      {[100, 75, 50, 25].map(g => <span key={g} className="kp-gridline" style={{ bottom: `${g}%` }}><em>{g}%</em></span>)}
      {points.map(p => <div key={p.tanggal} className={`kp-col ${p.persen != null && p.persen < 85 ? 'low' : ''}`} title={`${longDate(p.tanggal)}: ${percent(p.persen)}`}>
        <span style={{ height: `${p.persen ?? 0}%` }}/><small>{shortDate(p.tanggal)}</small></div>)}
    </div>
  </div>;
}
function Donut({ segments, total, caption }) {
  const sum = segments.reduce((s, x) => s + x.value, 0) || 1;
  let offset = 0;
  return <svg className="kp-donut" viewBox="0 0 120 120" role="img" aria-label={segments.map(s => `${s.label}: ${s.value}`).join(', ')}>
    <circle cx="60" cy="60" r="46" className="kp-donut-track"/>
    {segments.map(s => { const len = s.value / sum * 289.03; const el = <circle key={s.label} cx="60" cy="60" r="46" stroke={s.color}
      strokeDasharray={`${Math.max(0, len - 2)} ${289.03 - Math.max(0, len - 2)}`} strokeDashoffset={-offset} transform="rotate(-90 60 60)"/>; offset += len; return el; })}
    <text x="60" y="58" className="kp-donut-value">{total}</text><text x="60" y="74" className="kp-donut-caption">{caption}</text>
  </svg>;
}

function Overview({ data }) {
  const k = data.kehadiran, e = data.ekskul;
  const trend = k.tren.slice(-14);
  const recorded = trend.filter(t => t.persen != null);
  const average = recorded.length ? Math.round(recorded.reduce((s, t) => s + t.persen, 0) / recorded.length * 10) / 10 : null;
  const clubs = e.per_kegiatan.map((c, i) => ({ label: c.nama, value: c.anggota, color: paletteHex[palette[i % palette.length]] }));
  const reports = data.pelanggaran.laporan;
  return <>
    <section className="ks-cards" aria-label="Ringkasan utama">
      <Metric label="Kehadiran hari ini" value={percent(k.hari_ini.persen)} meter={k.hari_ini.persen} icon="calendar"
        detail={k.hari_ini.total ? `${k.hari_ini.hadir} dari ${k.hari_ini.total} catatan hadir` : 'Belum ada sesi presensi ditutup hari ini'}/>
      <Metric label="Kasus aktif" value={data.kasus.aktif} icon="shield" detail={`${data.kasus.selesai} kasus sudah selesai atau ditutup`}/>
      <Metric label="Prestasi periode ini" value={e.prestasi.total} icon="badge" detail="Pencapaian individu dan tim"/>
      <Metric label="Partisipasi ekskul" value={percent(e.persen_partisipasi)} meter={e.persen_partisipasi} icon="activity"
        detail={`${e.siswa_unik} dari ${e.total_siswa} siswa aktif ikut kegiatan`}/>
    </section>
    <div className="kp-grid">
      <Panel title="Tren kehadiran harian" note="Hingga 14 hari terakhir yang memiliki sesi presensi ditutup"
        aside={average != null && <span className="kp-pill c-teal">Rata-rata {percent(average)}</span>}>
        <Columns points={trend}/>
        {trend.length > 0 && <p className="kp-foot"><i className="kp-dot c-brick"/>Kolom merah bata menandai kehadiran di bawah 85%.</p>}
      </Panel>
      <Panel title="Partisipasi ekstrakurikuler" note="Anggota aktif per kegiatan">
        {clubs.length ? <div className="kp-donut-wrap"><Donut segments={clubs} total={e.siswa_unik} caption="siswa unik"/>
          <ul className="kp-legend">{clubs.map(c => <li key={c.label}><i style={{ background: c.color }}/>{c.label}<b>{c.value}</b></li>)}</ul></div>
          : <Empty>Belum ada keanggotaan aktif.</Empty>}
      </Panel>
      <Panel title="Pelanggaran terverifikasi" note="Per kategori; identitas siswa tidak ditampilkan">
        <Rows rows={data.pelanggaran.per_kategori} label="kategori" value="total"/>
        <div className="kp-pills">
          <span className="kp-pill c-green">{reports.TERVERIFIKASI ?? 0} terverifikasi</span>
          <span className="kp-pill c-amber">{reports.MENUNGGU ?? 0} menunggu</span>
          <span className="kp-pill c-heather">{reports.DITOLAK ?? 0} ditolak</span>
        </div>
      </Panel>
      <Panel title="Prestasi per tingkat" note="Periode terpilih">
        <Rows rows={e.prestasi.per_tingkat.map(r => ({ ...r, nama: levelLabels[r.tingkat] ?? r.tingkat }))} label="nama" value="total" offset={2}/>
      </Panel>
    </div>
  </>;
}

function Cases({ data }) {
  const [term, setTerm] = useState('');
  const categories = data.per_kategori.map((r, i) => ({ ...r, tone: palette[i % palette.length] })).filter(r => matches(r.kategori, term));
  const total = data.per_status.reduce((s, r) => s + r.total, 0);
  const age = data.usia_kasus_aktif;
  const ages = [['Sampai 7 hari', age.sampai_7_hari, 'green'], ['8–30 hari', age.dari_8_30_hari, 'amber'], ['Lebih dari 30 hari', age.lebih_30_hari, 'brick']];
  const ageTotal = ages.reduce((s, [, v]) => s + v, 0);
  return <div className="kp-grid">
    <Panel title="Status penanganan" note="Seluruh kasus yang tercatat" aside={<span className="kp-pill c-navy">{total} kasus</span>}>
      {data.per_status.length ? <div className="kp-tiles">{data.per_status.map(r => <div key={r.status} className={`kp-tile c-${caseTone[r.status] ?? 'heather'}`}>
        <b>{r.total}</b><span>{caseLabels[r.status] ?? r.status}</span></div>)}</div> : <Empty>Belum ada kasus tercatat.</Empty>}
    </Panel>
    <Panel title="Usia kasus aktif" note="Dihitung sejak tanggal kasus dibuka">
      <div className={`kp-stacked ${ageTotal ? '' : 'empty'}`}>{ages.filter(([, v]) => v).map(([l, v, tone]) =>
        <span key={l} className={`c-${tone}`} style={{ flexGrow: v }} title={`${l}: ${v}`}/>)}</div>
      <ul className="kp-legend">{ages.map(([l, v, tone]) => <li key={l}><i className={`c-${tone}`}/>{l}<b>{v}</b></li>)}</ul>
      {age.lebih_30_hari > 0 && <p className="kp-callout">{age.lebih_30_hari} kasus sudah lebih dari 30 hari. Pertimbangkan meminta pembaruan dari Guru BK.</p>}
    </Panel>
    <Panel title="Kategori pelanggaran" note="Laporan terverifikasi pada periode terpilih" className="kp-wide"
      aside={data.per_kategori.length > 0 && <SearchInput value={term} onChange={setTerm} label="Cari kategori pelanggaran" placeholder="Cari kategori…"/>}>
      {term && !categories.length ? <Empty>Tidak ada kategori yang cocok dengan “{term.trim()}”.</Empty>
        : <Rows rows={categories} label="kategori" value="total" render={r => <>{r.total} laporan <em>· {r.berjalan} berjalan</em></>}/>}
    </Panel>
  </div>;
}

// Kolom cari kecil untuk menyaring daftar yang sudah dimuat (tanpa permintaan ke server).
function SearchInput({ value, onChange, label, placeholder }) {
  return <label className="kp-search"><input type="search" value={value} onChange={e => onChange(e.target.value)}
    aria-label={label} placeholder={placeholder}/></label>;
}
const matches = (text, term) => String(text ?? '').toLowerCase().includes(term.trim().toLowerCase());

function Clubs({ data }) {
  const [term, setTerm] = useState('');
  const rows = data.kegiatan.map((c, i) => ({ ...c, tone: palette[i % palette.length] })).filter(c => matches(c.nama, term));
  return <section className="ks-panel ks-table-panel">
    <div className="ks-panel-heading"><div><h2>Ringkasan kegiatan</h2><p>{longDate(data.periode.mulai)} – {longDate(data.periode.sampai)}</p></div>
      <div className="kp-search"><SearchInput value={term} onChange={setTerm} label="Cari kegiatan" placeholder="Cari kegiatan…"/>
        <span className="ks-chip">{term ? `${rows.length} dari ${data.kegiatan.length}` : data.kegiatan.length} kegiatan</span></div></div>
    <div className="ks-table-scroll"><table><thead><tr><th>Kegiatan</th><th>Anggota / kapasitas</th><th>Pertemuan</th><th>Kehadiran</th><th>Prestasi</th></tr></thead>
      <tbody>{rows.map(c => <tr key={c.nama}>
        <td><strong className="kp-club"><i className={`kp-dot c-${c.tone}`}/>{c.nama}</strong></td>
        <td><span className="kp-num">{c.anggota}{c.kapasitas ? ` / ${c.kapasitas}` : ''}</span>
          {c.kapasitas ? <div className="kp-meter small"><span style={{ width: `${Math.min(100, c.anggota / c.kapasitas * 100)}%` }}/></div> : null}</td>
        <td className="kp-num">{c.pertemuan}</td>
        <td><span className={`ks-status ${c.persen_hadir != null && c.persen_hadir < 85 ? 'ks-danger' : ''}`}>{percent(c.persen_hadir)}</span></td>
        <td className="kp-num">{c.prestasi}</td></tr>)}</tbody></table></div>
    {!data.kegiatan.length ? <p className="ks-empty">Belum ada kegiatan pada tahun ajaran aktif.</p>
      : !rows.length && <p className="ks-empty">Tidak ada kegiatan yang cocok dengan “{term.trim()}”.</p>}
  </section>;
}

function Report({ data, onDownload }) {
  const items = [['calendar', 'Kehadiran', 'Persentase hari ini dan jumlah per status kehadiran.'], ['shield', 'Pelanggaran & kasus', 'Laporan terverifikasi per kategori serta kasus aktif dan selesai.'],
    ['activity', 'Ekstrakurikuler', 'Siswa unik, persentase partisipasi, dan anggota per kegiatan.'], ['badge', 'Prestasi', 'Jumlah prestasi dan sebarannya per tingkat.']];
  return <Panel title="Isi ringkasan eksekutif" note={`${longDate(data.periode.mulai)} – ${longDate(data.periode.sampai)} · hanya angka agregat, tanpa data pribadi`}
    aside={<button className="ks-primary" onClick={onDownload}><Icon name="download" size={16}/> Unduh CSV</button>}>
    <ul className="kp-report">{items.map(([icon, t, d], i) => <li key={t} className={`c-${palette[i]}`}><i><Icon name={icon} size={18}/></i><div><b>{t}</b><span>{d}</span></div></li>)}</ul>
  </Panel>;
}

export default function KepalaSekolahPage({ profile, onLogout }) {
  const { section } = useParams();
  const [range, setRange] = useState(() => rangeOf(30));
  const [notice, setNotice] = useState('');
  const query = `?mulai=${range.mulai}&sampai=${range.sampai}`;
  const valid = Boolean(sections[section]);
  const { loading, error, data, retry } = useData(`${base}/${endpoints[section] ?? 'dashboard'}${query}`);
  const invalid = range.mulai > range.sampai;
  const preset = [7, 30, 90].find(d => { const r = rangeOf(d); return r.mulai === range.mulai && r.sampai === range.sampai; });
  const download = useCallback(async () => {
    setNotice('');
    try {
      const blob = await apiRequest(`${base}/laporan.csv${query}`, { responseType: 'blob' });
      const url = URL.createObjectURL(blob), a = document.createElement('a');
      a.href = url; a.download = `ringkasan-eksekutif-${range.mulai}_${range.sampai}.csv`; a.click(); URL.revokeObjectURL(url);
    } catch (e) { setNotice(e.message); }
  }, [query, range]);
  useEffect(() => {
    const previous = document.title;
    document.title = 'Kepala Sekolah · SIM Kesiswaan';
    return () => { document.title = previous; };
  }, []);
  if (!valid) return <Navigate to={`${base}/dashboard`} replace/>;
  const [heading, description] = sectionInfo[section];
  return <PortalShell tone="kepsek" base={base} label="Portal Pimpinan" sections={sections} profile={profile} roleLabel="Kepala Sekolah"
    onLogout={onLogout} onNavigate={() => setNotice('')}>
    <div className="ks-content">
      <div className="ks-heading">
        <div><span className="ks-eyebrow">Laporan pimpinan · hanya baca</span><h1>{heading}</h1><p>{description}</p></div>
        <div className="kp-filter">
          <div className="kp-presets" role="group" aria-label="Periode cepat">{[7, 30, 90].map(d =>
            <button key={d} className={preset === d ? 'on' : ''} aria-pressed={preset === d} onClick={() => setRange(rangeOf(d))}>{d} hari</button>)}</div>
          <label className="ks-field">Dari<input type="date" value={range.mulai} max={range.sampai} onChange={e => setRange(r => ({ ...r, mulai: e.target.value }))}/></label>
          <label className="ks-field">Sampai<input type="date" value={range.sampai} min={range.mulai} onChange={e => setRange(r => ({ ...r, sampai: e.target.value }))}/></label>
          {section !== 'laporan' && <button onClick={download} disabled={invalid}><Icon name="download" size={16}/> Unduh CSV</button>}
        </div>
      </div>
      {notice && <p className="ks-error" role="alert">{notice}</p>}
      {invalid ? <p className="ks-error" role="alert">Tanggal awal tidak boleh setelah tanggal akhir.</p>
        : error ? <div className="ks-error" role="alert">{error} <button className="ks-link" onClick={retry}>Coba lagi</button></div>
        : loading || !data ? <p className="ks-message" role="status">Memuat informasi…</p>
        : section === 'kasus' ? <Cases data={data}/> : section === 'ekskul' ? <Clubs data={data}/>
        : section === 'laporan' ? <Report data={data} onDownload={download}/>
        : <Overview data={data}/>}
    </div>
  </PortalShell>;
}
