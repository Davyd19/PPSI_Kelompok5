import { useCallback, useEffect, useRef, useState } from 'react';
import { Navigate, useNavigate, useParams, useLocation } from 'react-router-dom';
import { apiRequest } from '../../api/client';
import Icon from '../../components/Icon';
import PortalShell from '../../components/PortalShell';
import ReportEvidence from '../../components/ReportEvidence';
import KesiswaanOverview from './KesiswaanOverview';
import { ManagementProvider, IconAction, Notice, StatusBadge, RowActions, LoadingState } from '../../components/ManagementUi';
import { Field, Area, Rows, Students, WorkForm, UploadField } from './KesiswaanForms';
import KesiswaanDetail from './KesiswaanDetail';
import './kesiswaan-integrated.css';
const base = '/kesiswaan';
const sections = {
  dashboard: ['Dashboard', 'dashboard'],
  students: ['Pusat siswa', 'users'],
  reports: ['Laporan pelanggaran', 'file'],
  proposals: ['Peninjauan usulan', 'shield'],
  categories: ['Kategori & aturan', 'shield'],
  achievements: ['Prestasi siswa', 'badge'],
  attendance: ['Rekap & laporan', 'calendar']
};
const sectionInfo = {
  dashboard: ['Dashboard Kesiswaan & Kedisiplinan', 'Pantau laporan pelanggaran dan rekap kehadiran SMAN 12 Padang.'],
  students: ['Pusat Siswa', 'Telusuri kehadiran, laporan, pendampingan yang diizinkan, dan prestasi siswa.'],
  reports: ['Laporan Pelanggaran', 'Catat kejadian dan periksa laporan yang masuk.'],
  categories: ['Kategori Pelanggaran', 'Kelola kategori dan versi aturan penanganan.'],
  proposals: ['Peninjauan Usulan', 'Tinjau usulan eskalasi dan rujukan yang diajukan.'],
  achievements: ['Pencatatan Prestasi', 'Kelola prestasi individu dan tim beserta bukti pendukungnya.'],
  attendance: ['Rekap & Laporan', 'Tinjau dan unduh kehadiran atau pelanggaran dengan filter yang sama.']
};
// Halaman yang punya kolom pencarian beserta petunjuk isiannya.
const searchInfo = {
  students: 'Nama siswa atau NISN',
  reports: 'Nama siswa, NISN, kategori, atau pelapor',
  attendance: 'Nama siswa atau NISN',
  proposals: 'Ringkasan atau nomor usulan, mis. #12',
  achievements: 'Judul, tim, tingkat, hasil, atau nama peserta'
};
const labels = {
  AKTIF: 'Aktif',
  NONAKTIF: 'Nonaktif',
  USULAN_ESKALASI: 'Usulan eskalasi',
  USULAN_RUJUKAN: 'Usulan rujukan',
  MENUNGGU: 'Menunggu',
  TERVERIFIKASI: 'Terverifikasi',
  DITOLAK: 'Ditolak',
  DISETUJUI: 'Disetujui',
  PERLU_REVISI: 'Perlu revisi',
  HADIR: 'Hadir',
  TERLAMBAT: 'Terlambat',
  IZIN: 'Izin',
  SAKIT: 'Sakit',
  ALFA: 'Alfa',
  PENGECUALIAN_SAH: 'Pengecualian sah',
  PENGECUALIAN_SAH_ZUHUR: 'Pengecualian sah Zuhur',
  BELUM_DIISI: 'Belum diisi'
};
const wib = value => value ? new Intl.DateTimeFormat('id-ID', {
  timeZone: 'Asia/Jakarta',
  dateStyle: 'medium',
  timeStyle: 'short'
}).format(new Date(value)) : '—';
const shortDate = value => value || '—';
const label = value => labels[value] || String(value ?? '—').replaceAll('_', ' ');
const status = value => <StatusBadge value={value}>{label(value)}</StatusBadge>;
function KesiswaanWorkspace({
  profile,
  onLogout
}) {
  const {
    section,
    id: detailId
  } = useParams();
  const location = useLocation();
  const initialQuery = new URLSearchParams(location.search);
  const navigate = useNavigate();
  const leaveGuard = useRef(null);
  const [messageError, setMessageError] = useState(false);
  const closeNotice = useCallback(() => setMessage(''), []);
  const [data, setData] = useState(null),
    [lookups, setLookups] = useState({
      classes: [],
      categories: []
    });
  const [error, setError] = useState(''),
    [message, setMessage] = useState(''),
    [retry, setRetry] = useState(0);
  const [modal, setModal] = useState(null),
    [filter, setFilter] = useState(() => ({
      mulai: initialQuery.get('mulai') || '',
      sampai: initialQuery.get('sampai') || '',
      kelas: initialQuery.get('kelas') || '',
      status: initialQuery.get('status') || ''
    })),
    [page, setPage] = useState(() => Number(initialQuery.get('page')) || 1);
  const [meta, setMeta] = useState(null);
  const [categorySearch, setCategorySearch] = useState('');
  const [categoryStatus, setCategoryStatus] = useState('');
  const [search, setSearch] = useState(initialQuery.get('q') || ''),
    [q, setQ] = useState(initialQuery.get('q') || ''),
    [proposalStatus, setProposalStatus] = useState(initialQuery.get('status') || '');
  // Tunda pencarian ke server sampai pengguna berhenti mengetik.
  useEffect(() => {
    const next = search.trim();
    if (next === q) return;
    const timer = setTimeout(() => {
      setQ(next);
      setPage(1);
    }, 350);
    return () => clearTimeout(timer);
  }, [search, q]);
  const filtered = ['dashboard', 'reports', 'attendance', 'students', 'achievements'].includes(section);
  const searchable = Boolean(searchInfo[section]);
  const activeFilter = {
    ...filter,
    status: ['dashboard', 'students'].includes(section) ? '' : filter.status
  };
  const [reportTab, setReportTab] = useState(initialQuery.get('tab') === 'reports' ? 'reports' : 'attendance');
  const endpoint = section === 'attendance' ? reportTab : section;
  const qs = new URLSearchParams([...(filtered ? Object.entries(activeFilter).filter(([, v]) => v) : []), ...(searchable && q ? [['q', q]] : []), ...(section === 'proposals' && proposalStatus ? [['status', proposalStatus]] : []), ['page', String(page)]]).toString();
  const query = qs;
  const requestKey = `${endpoint}?${query}&revision=${retry}`;
  useEffect(() => {
    if (!detailId) {
      const params = new URLSearchParams(query);
      if (section === 'attendance') params.set('tab', reportTab);
      const next = params.toString();
      if (location.search.slice(1) !== next) navigate({
        pathname: location.pathname,
        search: next
      }, {
        replace: true
      });
    }
  }, [detailId, query, reportTab, section, location.pathname, location.search, navigate]);
  function openDetail(kind, row) {
    const params = new URLSearchParams(query);
    params.set('back', location.pathname + location.search);
    navigate(`${base}/${kind}/${row.id}?${params}`);
    setModal(null);
  }
  function backFromDetail() {
    const back = new URLSearchParams(location.search).get('back');
    navigate(back?.startsWith(base + '/') ? back : `${base}/${section}?${query}`);
    setModal(null);
  }
  const studentLink = (id, name) => <button type="button" className="ks-link" onClick={() => openDetail('students', {
    id
  })}>{name}</button>;
  const [loaded, setLoaded] = useState('');
  const [detailError, setDetailError] = useState('');
  useEffect(() => {
    if (!sections[section]) return;
    const controller = new AbortController();
    apiRequest(`${base}/${endpoint}?${query}`, {
      signal: controller.signal
    }).then(result => {
      setData(result.data);
      setMeta(result.meta);
      setError('');
      setLoaded(requestKey);
    }).catch(e => {
      if (e.name !== 'AbortError') {
        setError(e.message);
        setLoaded(requestKey);
      }
    });
    return () => controller.abort();
  }, [section, endpoint, query, requestKey]);
  useEffect(() => {
    const controller = new AbortController();
    apiRequest(`${base}/lookups`, {
      signal: controller.signal
    }).then(({
      data
    }) => setLookups(data)).catch(e => {
      if (e.name !== 'AbortError') {
        setMessageError(true);
        setMessage(e.message);
      }
    });
    return () => controller.abort();
  }, [retry]);
  useEffect(() => {
    if (!detailId || !['reports', 'proposals'].includes(section)) return;
    setModal(null);
    setDetailError('');
    const controller = new AbortController();
    apiRequest(`${base}/${section}/${detailId}`, {
      signal: controller.signal
    }).then(({
      data
    }) => {
      setModal({
        kind: section === 'reports' ? 'report' : 'proposal',
        row: data,
        routed: true
      });
    }).catch(e => {
      if (e.name !== 'AbortError') {
        setDetailError(e.message);
      }
    });
    return () => controller.abort();
  }, [section, detailId, retry]);
  useEffect(() => {
    setModal(null);
    setDetailError('');
  }, [section, detailId]);
  function resetFilters() {
    setPage(1);
    setFilter({
      mulai: '',
      sampai: '',
      kelas: '',
      status: ''
    });
    setSearch('');
    setQ('');
    setProposalStatus('');
  }
  function clearSearch() {
    setSearch('');
    setQ('');
    setProposalStatus('');
    setPage(1);
  }
  const searchBox = searchable && <Field title="Cari" type="search" value={search} placeholder={searchInfo[section]} onChange={e => setSearch(e.target.value)} aria-label={`Cari ${sectionInfo[section][0].toLowerCase()}`} />;
  function changed(key, value) {
    setPage(1);
    setFilter(f => ({
      ...f,
      [key]: value
    }));
  }
  function complete(text) {
    if (modal?.routed) backFromDetail();
    setModal(null);
    setMessageError(false);
    setMessage(text);
    setRetry(n => n + 1);
  }
  async function download(path, name) {
    try {
      const blob = await apiRequest(base + path, {
        responseType: 'blob'
      });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = name;
      a.click();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
    } catch (e) {
      setMessageError(true);
      setMessage(e.message);
    }
  }
  const post = (path, body, method = 'POST') => apiRequest(base + path, {
    method,
    body
  });
  const uploadReport = (id, file) => apiRequest(`${base}/reports/${id}/bukti`, {
    method: 'POST',
    body: file,
    headers: {
      'Content-Type': file.type,
      'X-Filename': encodeURIComponent(file.name)
    }
  });
  const upload = (id, file) => apiRequest(`${base}/achievements/${id}/attachments`, {
    method: 'POST',
    body: file,
    headers: {
      'Content-Type': file.type,
      'X-Filename': encodeURIComponent(file.name)
    }
  });
  async function save(form) {
    const body = Object.fromEntries(form),
      row = modal.row;
    let savedMessage = 'Perubahan tersimpan.';
    switch (modal.kind) {
      case 'createReport':
        body.waktu_kejadian += '+07:00';
        {
          const file = form.get('file');
          delete body.file;
          if (file?.size > 5 * 1024 * 1024) throw new Error('Lampiran maksimal 5 MB.');
          const {
            data: report
          } = await post('/reports', body);
          if (file?.size) {
            try {
              await uploadReport(report.id, file);
            } catch (e) {
              setModal({
                kind: 'reportAttachment',
                row: report,
                file
              });
              setMessageError(true);
              setMessage('Laporan tersimpan. Unggah ulang bukti pada laporan yang sama: ' + e.message);
              setRetry(n => n + 1);
              return;
            }
          }
        }
        break;
      case 'report':
        await post(`/reports/${row.id}/verify`, body);
        break;
      case 'category':
        await post(row ? `/categories/${row.id}` : '/categories', body, row ? 'PUT' : 'POST');
        break;
      case 'version':
        await post(`/categories/${row.id}/versions`, body);
        break;
      case 'proposal':
        await post(`/proposals/${row.id}/decision`, body);
        break;
      case 'achievement':
        {
          const file = form.get('file');
          delete body.file;
          body.peserta = form.getAll('peserta');
          if (file?.size > 5 * 1024 * 1024) throw new Error('Lampiran maksimal 5 MB.');
          const result = await post(row ? `/achievements/${row.id}` : '/achievements', body, row ? 'PUT' : 'POST');
          const achievement = result.data;
          if (result.meta?.badge_recalculation === 'pending') savedMessage = 'Prestasi tersimpan; pembaruan badge akan dilanjutkan otomatis.';
          if (file?.size) {
            try {
              await upload(achievement.id, file);
            } catch (e) {
              setModal({
                kind: 'attachment',
                row: achievement,
                file
              });
              setRetry(n => n + 1);
              setMessageError(true);
              setMessage('Prestasi tersimpan. Unggahan belum berhasil: ' + e.message);
              return;
            }
          }
          break;
        }
      case 'cancel':
        {
          const result = await post(`/achievements/${row.id}/cancel`, body);
          if (result.meta?.badge_recalculation === 'pending') savedMessage = 'Prestasi dibatalkan; pembaruan badge akan dilanjutkan otomatis.';
          break;
        }
      case 'editVersion':
        await post(`/categories/${row.id_kategori_pelanggaran}/versions/${row.id}`, body, 'PUT');
        break;
      case 'reportAttachment':
        {
          const file = form.get('file');
          if (!file?.size) throw new Error('Pilih berkas.');
          await uploadReport(row.id, file);
          break;
        }
      case 'attachment':
        {
          const file = form.get('file');
          if (!file?.size || file.size > 5 * 1024 * 1024) throw new Error('Pilih berkas maksimal 5 MB.');
          await upload(row.id, file);
          break;
        }
    }
    complete(savedMessage);
  }
  if (!sections[section]) return <Navigate to={`${base}/dashboard`} replace />;
  const allRows = loaded === requestKey && !error && Array.isArray(data) ? data : [];
  const rows = section === 'categories' ? allRows.filter(row => (!categoryStatus || row.status === categoryStatus) && [row.nama, row.deskripsi].some(value => value?.toLowerCase().includes(categorySearch.trim().toLowerCase()))) : allRows;
  const dialog = modal?.row;
  const fullPage = ['report', 'proposal', 'achievement', 'createReport'].includes(modal?.kind);
  const integratedDetail = detailId && ['students', 'categories', 'achievements'].includes(section);
  const readOnly = modal?.kind === 'report' && dialog.status_verifikasi !== 'MENUNGGU' || modal?.kind === 'proposal' && dialog.status_usulan !== 'MENUNGGU';
  const titles = {
    createReport: 'Catat Pelanggaran',
    report: 'Verifikasi Laporan Pelanggaran',
    category: dialog ? 'Ubah Kategori' : 'Tambah Kategori',
    version: 'Tambah Versi Aturan',
    proposal: dialog?.jenis?.includes('RUJUK') ? 'Peninjauan Usulan Rujukan' : 'Peninjauan Kasus Eskalasi',
    achievement: dialog ? 'Ubah Prestasi Siswa' : 'Catat Prestasi Siswa',
    attachment: 'Unggah Bukti Prestasi',
    reportAttachment: 'Unggah Bukti Laporan',
    cancel: 'Batalkan Prestasi',
    editVersion: 'Ubah Versi Mendatang'
  };
  const actions = {
    report: 'Simpan pemeriksaan',
    proposal: 'Simpan keputusan',
    achievement: 'Simpan prestasi',
    attachment: 'Unggah bukti',
    cancel: 'Batalkan prestasi',
    reportAttachment: 'Unggah bukti',
    editVersion: 'Simpan versi'
  };
  const [heading, description] = sectionInfo[section];
  function closeForm() {
    if (modal?.returnForm) {
      setModal(modal.returnForm);
      return;
    }
    if (modal?.routed) backFromDetail();
    setModal(null);
  }
  async function changeSection() {
    if (leaveGuard.current && !(await leaveGuard.current())) return false;
    setPage(1);
    setFilter(current => ({
      ...current,
      status: ''
    }));
    setSearch('');
    setQ('');
    setProposalStatus('');
    setCategorySearch('');
    setCategoryStatus('');
    setMessage('');
    closeForm();
    return true;
  }
  return <PortalShell className="management-ui portal" tone="kesiswaan" base={base} label="Manajemen Kesiswaan" sections={sections} profile={profile} roleLabel="Kesiswaan" onLogout={async () => {
    if (!leaveGuard.current || (await leaveGuard.current())) onLogout();
  }} onBeforeNavigate={async key => {
    if (await changeSection()) navigate(`${base}/${key}`);
  }}>
      {(fullPage || Boolean(detailId)) && message && <div className="ks-content"><Notice message={message} error={messageError} onClose={closeNotice} /></div>}
      <div className="ks-content" hidden={fullPage || Boolean(detailId)}>
        {section === 'attendance' && <nav className="ksi-tabs" aria-label="Jenis laporan">{[['attendance', 'Kehadiran'], ['reports', 'Pelanggaran']].map(([value, title]) => <button key={value} aria-pressed={reportTab === value} onClick={() => {
          setReportTab(value);
          setPage(1);
          setFilter(f => ({
            ...f,
            status: ''
          }));
        }}>{title}</button>)}</nav>}
        <div className="ks-heading">
          <div><span className="ks-eyebrow">Manajemen kesiswaan</span><h1>{heading}</h1><p>{description}</p></div>
          <div className="ks-actions">
            {['dashboard', 'reports', 'attendance'].includes(section) && <button onClick={() => download('/' + (section === 'dashboard' ? 'attendance' : endpoint) + '.csv?' + qs, section === 'reports' ? 'pelanggaran.csv' : 'presensi.csv')}><Icon name="download" size={16} /> Unduh CSV</button>}
            {['dashboard', 'reports'].includes(section) && <button className="ks-primary" onClick={() => setModal({
            kind: 'createReport'
          })}>＋ Catat Pelanggaran</button>}
            {section === 'categories' && <button className="ks-primary" onClick={() => setModal({
            kind: 'category'
          })}>＋ Tambah Kategori</button>}
            {section === 'achievements' && <button className="ks-primary" onClick={() => setModal({
            kind: 'achievement'
          })}>＋ Catat Prestasi</button>}
          </div>
        </div>
        {filtered && <section className="ks-filters ks-panel" aria-label="Filter data">
          <div className="ks-panel-heading"><h2>{section === 'dashboard' ? 'Periode dan Kelas' : 'Filter Data'}</h2><IconAction label="Reset filter" onClick={resetFilters}/><IconAction label="Muat ulang data" onClick={()=>setRetry(n=>n+1)}/></div>
          <div className="ks-filter-fields">
            {section !== 'dashboard' && <div className="ks-search-field">{searchBox}</div>}
            {section !== 'students' && <Field title="Mulai" type="date" value={filter.mulai} onChange={e => changed('mulai', e.target.value)} />}
            {section !== 'students' && <Field title="Sampai" type="date" value={filter.sampai} onChange={e => changed('sampai', e.target.value)} />}
            <Field title="Kelas"><select value={filter.kelas} onChange={e => changed('kelas', e.target.value)}><option value="">Semua kelas</option>
              {lookups.classes.map(c => <option key={c.id} value={c.id}>{c.nama}</option>)}</select></Field>
            {!['dashboard', 'students'].includes(section) && <Field title="Status"><select value={filter.status} onChange={e => changed('status', e.target.value)}><option value="">Semua status</option>
              {(section === 'achievements' ? ['AKTIF', 'DIBATALKAN', 'SEMUA'] : endpoint === 'reports' ? ['MENUNGGU', 'TERVERIFIKASI', 'DITOLAK'] : ['HADIR', 'TERLAMBAT', 'IZIN', 'SAKIT', 'ALFA', 'PENGECUALIAN_SAH', 'PENGECUALIAN_SAH_ZUHUR', 'BELUM_DIISI']).map(s => <option key={s} value={s}>{label(s)}</option>)}</select></Field>}
          </div>
          {section !== 'students' && !filter.mulai && !filter.sampai && <small>Periode awal 30 hari terakhir</small>}
        </section>}
        {['proposals', 'achievements'].includes(section) && <section className="ks-filters ks-panel" aria-label="Cari data">
          <div className="ks-panel-heading"><h2>Cari Data</h2>{(search || proposalStatus) && <IconAction label="Reset pencarian" onClick={clearSearch}/>}</div>
          <div className="ks-filter-fields">
            <div className="ks-search-field">{searchBox}</div>
            {section === 'proposals' && <Field title="Status"><select value={proposalStatus} onChange={e => {
              setPage(1);
              setProposalStatus(e.target.value);
            }}>
              <option value="">Semua status</option>{['MENUNGGU', 'DISETUJUI', 'DITOLAK', 'PERLU_REVISI'].map(s => <option key={s} value={s}>{label(s)}</option>)}</select></Field>}
          </div>
        </section>}
        {section === 'categories' && <section className="ks-filters ks-panel" aria-label="Filter kategori"><div className="ks-filter-fields">
          <Field title="Cari kategori" type="search" placeholder="Nama atau deskripsi" value={categorySearch} onChange={event => setCategorySearch(event.target.value)} />
          <Field title="Status"><select value={categoryStatus} onChange={event => setCategoryStatus(event.target.value)}>
            <option value="">Semua status</option><option value="AKTIF">Aktif</option><option value="NONAKTIF">Nonaktif</option>
          </select></Field>
        </div></section>}

    <Notice message={message} error={messageError} onClose={closeNotice} />
    {loaded !== requestKey ? <LoadingState /> : error ? <p className="ks-error" role="alert">{error} <button onClick={() => setRetry(n => n + 1)}>Coba lagi</button></p> : <>
      {section === 'dashboard' && <KesiswaanOverview data={data} formatTime={wib} renderStatus={status} renderRows={props => <Rows {...props} />} onReview={row => openDetail('reports', row)} onViewReports={() => navigate(base + '/reports')} onNavigate={kind => navigate(`${base}/${kind}?${query}`)} onProposal={row => openDetail('proposals', row)} studentLink={studentLink} query={query} />}
      {(section === 'reports' || section === 'attendance' && reportTab === 'reports') && <section className="ks-panel ks-table-panel"><div className="ks-panel-heading"><h2>Daftar Laporan</h2></div><Rows filtered={Boolean(q || proposalStatus)} onReset={clearSearch} headers={['Siswa', 'Kategori', 'Waktu', 'Status', 'Aksi']} items={rows} onOpen={r => openDetail('reports', r)} render={r => <>
        <td>{studentLink(r.id_siswa, r.siswa)}<small>{r.kelas}</small></td><td>{r.kategori}</td><td>{wib(r.waktu_kejadian)}</td><td>{status(r.status_verifikasi)}</td>
        <td><button onClick={() => openDetail('reports', r)}>Detail</button></td></>} /></section>}
      {section === 'students' && <section className="ks-panel ks-table-panel"><Rows headers={['Siswa', 'NISN', 'Kelas saat ini', 'Aksi']} items={rows} onOpen={r => openDetail('students', r)} render={r => <><td>{studentLink(r.id, r.nama)}</td><td>{r.nisn}</td><td>{r.kelas || 'Belum ditempatkan'}</td><td><button onClick={() => openDetail('students', r)}>Lihat profil</button></td></>} /></section>}
      {section === 'categories' && <section className="ks-panel ks-table-panel">
        <div className="ks-panel-heading"><h2>Daftar Kategori <span className="ks-chip">{rows.length} hasil</span></h2></div><Rows filtered={Boolean(categorySearch.trim() || categoryStatus)} onReset={() => {
            setCategorySearch('');
            setCategoryStatus('');
          }} headers={['Kategori', 'Status', 'Versi aturan', 'Aksi']} items={rows} onOpen={r => openDetail('categories', r)} render={r => <>
        <td><button className="ks-link" onClick={() => openDetail('categories', r)}>{r.nama}</button><small>{r.deskripsi}</small></td><td>{status(r.status)}</td><td>{r.aturan_id_kategori_pelanggaran.map(v => <details key={v.id}><summary>Versi {v.nomor_versi} · {v.berlaku_mulai} – {v.berlaku_sampai || 'seterusnya'}</summary><p>{v.ketentuan}</p></details>)}</td>
        <td><RowActions><button onClick={() => setModal({
                  kind: 'category',
                  row: r
                })}><Icon name="edit" size={15} />Edit</button><button onClick={() => setModal({
                  kind: 'version',
                  row: r
                })}>Versi baru</button></RowActions></td></>} /></section>}
      {section === 'proposals' && <section className="ks-panel ks-table-panel"><div className="ks-panel-heading"><h2>Daftar Usulan</h2></div><Rows filtered={Boolean(q || proposalStatus)} onReset={clearSearch} headers={['Usulan', 'Ringkasan yang diizinkan', 'Waktu', 'Status', 'Aksi']} items={rows} onOpen={r => openDetail('proposals', r)} render={r => <>
        <td>{(r.penanganan_siswa?.siswa || r.laporan_pelanggaran?.siswa) && studentLink((r.penanganan_siswa?.siswa || r.laporan_pelanggaran?.siswa).id, (r.penanganan_siswa?.siswa || r.laporan_pelanggaran?.siswa).nama)}<small>{label(r.jenis)} #{r.id}</small></td><td>{r.ringkasan_diizinkan || r.penanganan_siswa?.ringkasan_diizinkan || '—'}</td><td>{wib(r.waktu)}</td><td>{status(r.status_usulan)}</td>
        <td><button onClick={() => openDetail('proposals', r)}>{r.status_usulan === 'MENUNGGU' ? 'Tinjau' : 'Detail'}</button></td></>} /></section>}
      {section === 'attendance' && reportTab === 'attendance' && <section className="ks-panel ks-table-panel"><div className="ks-panel-heading"><h2>Pratinjau Data Presensi</h2></div><Rows filtered={Boolean(q || proposalStatus)} onReset={clearSearch} headers={['Tanggal', 'Sesi', 'Siswa', 'Kelas', 'Status']} items={rows} render={r => <>
        <td>{shortDate(r.tanggal)}</td><td>{label(r.jenis_sesi)}</td><td>{studentLink(r.id_siswa, r.siswa)}</td><td>{r.kelas}</td><td>{status(r.status_kehadiran)}</td></>} /></section>}
      {section === 'achievements' && <section className="ks-panel ks-table-panel"><div className="ks-panel-heading"><h2>Daftar Prestasi Siswa</h2></div><Rows filtered={Boolean(q || proposalStatus)} onReset={clearSearch} headers={['Prestasi', 'Peserta', 'Tanggal', 'Hasil', 'Bukti']} items={rows} onOpen={r => openDetail('achievements', r)} render={r => <>
        <td><button className="ks-link" onClick={() => openDetail('achievements', r)}>{r.judul}</button><small>{r.nama_tim || r.tingkat_prestasi}</small></td><td>{r.peserta_id_portofolio.map(p => <span key={p.id_siswa}>{studentLink(p.id_siswa, p.siswa?.nama)} </span>)}</td>
        <td>{shortDate(r.tanggal)}</td><td>{r.hasil_prestasi}<small>{status(r.status_catatan)}</small></td><td>{r.lampiran_id_portofolio.map(f => <button key={f.id} onClick={() => download(`/attachments/${f.id}`, f.nama_berkas)}>{f.nama_berkas}</button>)}
        {r.id_periode_ekstrakurikuler == null && r.status_catatan === 'AKTIF' && <IconAction label="Unggah bukti prestasi" onClick={()=>setModal({kind:'attachment',row:r})}/>}</td></>} /></section>}
      {meta && meta.page_size && <div className="ks-pagination"><button disabled={page <= 1} onClick={() => setPage(p => p - 1)}>Sebelumnya</button><span>Halaman {page} · {meta.total} data</span><button disabled={page * meta.page_size >= meta.total} onClick={() => setPage(p => p + 1)}>Berikutnya</button></div>}
    </>}
    </div>
    {detailId && ['reports', 'proposals'].includes(section) && !modal && <div className="ks-content"><button onClick={backFromDetail}>Kembali</button>{detailError ? <><Notice message={detailError} error onClose={() => setDetailError('')} /><button onClick={() => setRetry(n => n + 1)}>Coba lagi</button></> : <LoadingState />}</div>}
    {integratedDetail && !fullPage && <KesiswaanDetail key={`${section}-${detailId}-${retry}`} section={section} id={detailId} query={new URLSearchParams([...new URLSearchParams(location.search)].filter(([key]) => !['back', 'detailTab', 'status', 'page', 'q'].includes(key))).toString()} back={backFromDetail} open={openDetail} download={download} onChange={() => setRetry(n => n + 1)} onForm={(kind, row, seed) => setModal({
      kind,
      row,
      seed
    })} />}
    {modal && <WorkForm key={modal.kind + '-' + (modal.row?.id || 'new')} kind={modal.kind} registerGuard={leaveGuard} title={titles[modal.kind]} close={closeForm} save={save} fullPage={fullPage} readOnly={readOnly} action={actions[modal.kind]} initialFile={modal.file}>
      {modal.kind === 'createReport' && <><Students initial={modal.seed ? [modal.seed] : []} /><Field title="Kategori"><select name="id_kategori_pelanggaran" required><option value="">Pilih kategori</option>
        {lookups.categories.filter(c => c.status === 'AKTIF').map(c => <option key={c.id} value={c.id}>{c.nama}</option>)}</select></Field>
        <Field title="Waktu kejadian (WIB)" name="waktu_kejadian" type="datetime-local" required /><Field title="Tempat kejadian" name="tempat_kejadian" maxLength={191} /><Area name="uraian" title="Uraian" required /><UploadField /></>}
      {modal.kind === 'report' && <>
        <section className="ks-panel ks-form-panel">
          <div className="ks-panel-heading"><h2>Identitas Siswa</h2>{status(dialog.status_verifikasi)}</div>
          <dl className="ks-detail-grid"><div><dt>Nama</dt><dd>{studentLink(dialog.id_siswa, dialog.siswa)}</dd></div><div><dt>Kelas saat kejadian</dt><dd>{dialog.kelas || '—'}</dd></div><div><dt>Kelas sekarang</dt><dd>{dialog.kelas_sekarang?.nama || '—'}</dd></div>
            <div><dt>Pelapor</dt><dd>{dialog.pelapor}</dd></div><div><dt>Waktu kejadian</dt><dd>{wib(dialog.waktu_kejadian)} WIB</dd></div></dl>
        </section>
        <section className="ks-panel ks-form-panel"><h2>{dialog.kategori}</h2>
          <p>Versi aturan {dialog.nomor_versi} · {dialog.aturan?.berlaku_mulai} – {dialog.aturan?.berlaku_sampai || 'seterusnya'}</p><p>{dialog.aturan?.ketentuan}</p><div className="ks-report-text">{dialog.uraian}</div>
        </section>
        <ReportEvidence id={dialog.id} />
        {dialog.status_verifikasi === 'MENUNGGU' && Number(dialog.id_guru_pelapor) === Number(profile.id) && <button type="button" onClick={() => setModal({
          kind: 'reportAttachment',
          returnForm: modal,
          row: dialog
        })}>Tambah bukti laporan</button>}{dialog.handling && <section className="ks-panel"><h2>Penanganan terkait</h2><p>{dialog.handling.ringkasan_diizinkan || 'Ringkasan belum dibagikan.'}</p><button type="button" onClick={() => openDetail('students', {
            id: dialog.id_siswa
          })}>Lihat pendampingan siswa</button></section>}
        <section className="ks-panel ks-form-panel"><h2>Catatan Pemeriksaan</h2>
          {readOnly ? <p>{dialog.hasil_verifikasi || '—'} · {dialog.pemeriksa || '—'}</p> : <><Field title="Keputusan"><select name="status_verifikasi"><option value="TERVERIFIKASI">Verifikasi</option><option value="DITOLAK">Tolak</option></select></Field>
              <Area name="catatan" title="Catatan pemeriksaan" required /></>}
        </section>
      </>}

      {modal.kind === 'category' && <><Field title="Nama kategori" name="nama" defaultValue={dialog?.nama} required maxLength={191} /><Area name="deskripsi" title="Deskripsi" defaultValue={dialog?.deskripsi || ''} />
        <Field title="Status"><select name="status" defaultValue={dialog?.status || 'AKTIF'}><option value="AKTIF">Aktif</option><option value="NONAKTIF">Nonaktif</option></select></Field>{!dialog && <><Area name="ketentuan" title="Ketentuan awal" required /><Field name="berlaku_mulai" title="Berlaku mulai" type="date" required /><Field name="berlaku_sampai" title="Berlaku sampai" type="date" /></>}</>}
      {['version', 'editVersion'].includes(modal.kind) && <><p>{dialog.nama}</p><Area name="ketentuan" title="Ketentuan" required defaultValue={dialog?.ketentuan || ''} /><Field title="Berlaku mulai" name="berlaku_mulai" type="date" defaultValue={dialog?.berlaku_mulai} required /><Field title="Berlaku sampai" name="berlaku_sampai" type="date" defaultValue={dialog?.berlaku_sampai || ''} /></>}
      {modal.kind === 'proposal' && <>
        <section className="ks-panel"><h2>{studentLink(dialog.student?.id, dialog.student?.nama)}</h2><p>Pengusul: {dialog.proposer?.nama || '—'} · {dialog.kelas_sekarang?.nama || 'Kelas belum tersedia'}</p>{dialog.report && <button type="button" onClick={() => openDetail('reports', dialog.report)}>Laporan asal #{dialog.report.id}</button>}{dialog.related_reports?.map(r => <button type="button" key={r.id} onClick={() => openDetail('reports', r)}>Laporan #{r.id}</button>)}</section>
        <section className="ks-panel"><h2>Riwayat yang diizinkan</h2>{dialog.history?.map(r => <article className="ksi-history" key={r.id}><strong>{label(r.jenis)} · {wib(r.waktu)}</strong><p>{r.ringkasan_diizinkan || r.hasil_keputusan || 'Usulan tercatat'}</p>{r.alasan_keputusan && <p>Alasan: {r.alasan_keputusan}</p>}{r.arahan_tindak_lanjut && <p>Arahan: {r.arahan_tindak_lanjut}</p>}</article>)}</section>
        <section className="ks-panel ks-form-panel">
          <div className="ks-panel-heading"><h2>Ringkasan Usulan #{dialog.id}</h2>{status(dialog.status_usulan)}</div>
          <dl className="ks-detail-grid"><div><dt>Jenis usulan</dt><dd>{label(dialog.jenis)}</dd></div>
            <div><dt>Diajukan</dt><dd>{wib(dialog.waktu)} WIB</dd></div></dl>
          <div className="ks-report-text">{dialog.ringkasan_diizinkan || dialog.penanganan_siswa?.ringkasan_diizinkan || 'Ringkasan belum tersedia.'}</div>
        </section>
        {dialog.ringkasan_diizinkan && dialog.penanganan_siswa?.ringkasan_diizinkan && dialog.ringkasan_diizinkan !== dialog.penanganan_siswa.ringkasan_diizinkan && <section className="ks-panel ks-form-panel"><h2>Ringkasan Penanganan</h2><p>{dialog.penanganan_siswa.ringkasan_diizinkan}</p></section>}
        {!readOnly && <section className="ks-panel ks-form-panel"><h2>Keputusan dan Tindak Lanjut</h2>
          <fieldset className="ks-decisions"><legend>Keputusan</legend>
            {[['SETUJUI', 'Setujui'], ['TOLAK', 'Tolak'], ['MINTA_REVISI', 'Minta Revisi']].map(([value, title]) => <label key={value}><input type="radio" name="keputusan" value={value} required />{title}</label>)}
          </fieldset>
          <Area name="alasan" title="Alasan" required /><Area name="arahan" title="Arahan tindak lanjut" required />
        </section>}
      </>}
      {modal.kind === 'achievement' && <>
        <section className="ks-panel ks-form-panel"><h2>Peserta Prestasi</h2><Students multiple initial={dialog?.peserta_id_portofolio?.map(p => p.siswa) || (modal.seed ? [modal.seed] : [])} /></section>
        <section className="ks-panel ks-form-panel"><h2>Informasi Prestasi</h2>
          <Field title="Judul" name="judul" defaultValue={dialog?.judul || ''} required maxLength={191} />
          <div className="ks-form-columns">
            <Field title="Tanggal" name="tanggal" defaultValue={dialog?.tanggal || ''} type="date" required />
            <Field title="Nama tim jika peserta lebih dari satu" name="nama_tim" defaultValue={dialog?.nama_tim || ''} />
            <Field title="Tingkat" name="tingkat_prestasi" defaultValue={dialog?.tingkat_prestasi || ''} required />
            <Field title="Hasil" name="hasil_prestasi" defaultValue={dialog?.hasil_prestasi || ''} required />
          </div>
          <Area name="deskripsi" title="Deskripsi" defaultValue={dialog?.deskripsi || ''} />
        </section>
      </>}
      {modal.kind === 'cancel' && <><p>Pembatalan mempertahankan riwayat, peserta, dan berkas. Prestasi tidak lagi dihitung sebagai pencapaian aktif.</p><Area name="alasan_tindakan" title="Alasan pembatalan" required /></>}
      {modal.kind === 'attachment' && dialog.judul && <p>{dialog.judul}</p>}
      {['achievement', 'attachment', 'reportAttachment'].includes(modal.kind) && <UploadField required={modal.kind !== 'achievement'} initialFile={modal.file} />}
    </WorkForm>}

  </PortalShell>;
}
export default function KesiswaanPage(props) {
  return <ManagementProvider><KesiswaanWorkspace {...props} /></ManagementProvider>;
}
