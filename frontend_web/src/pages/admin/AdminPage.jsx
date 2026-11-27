import { useCallback, useEffect, useRef, useState } from 'react';
import { Link, useNavigate, useParams, useSearchParams } from 'react-router-dom';
import PortalShell from '../../components/PortalShell';
import Button from '../../components/Button';
import Icon from '../../components/Icon';
import { ManagementProvider, IconAction, Notice, StatusBadge, RowActions, LoadingState, EmptyState, Modal } from '../../components/ManagementUi';
import { useConfirm } from '../../hooks/useConfirm';
import { apiRequest } from '../../api/client';
import { Editor, RelationField } from './AdminForms';
import { StudentForm, BadgeForm } from './CompositeForms';
import { today } from '../../utils/calendar';
import '../../styles/admin.css';
import '../../styles/portal.css';
import './admin-integrated.css';
const sections = {
  dashboard: ['Beranda', 'dashboard'],
  master: ['Data Master', 'users'],
  peran: ['Peran & Tugas Guru', 'shield'],
  akademik: ['Kelas & Akademik', 'calendar'],
  ekskul: ['Ekstrakurikuler', 'activity'],
  badge: ['Badge', 'medal']
};
const tabs = {
  master: [['siswa', 'Siswa'], ['guru', 'Guru'], ['orang_tua', 'Orang Tua']],
  peran: [['guru', 'Guru & penugasan']],
  akademik: [['kelas', 'Kelas']],
  ekskul: [['ekskul', 'Kegiatan']],
  badge: [['badge', 'Katalog badge']]
};
const columns = {
  siswa: ['nama', 'nisn', 'status_siswa', 'status_akun'],
  guru: ['nama', 'peran_utama', 'tugas_wali', 'tugas_pembina', 'status_akun'],
  orang_tua: ['nama', 'telepon', 'status_akun'],
  kelas: ['nama', 'tingkat', 'status'],
  ekskul: ['nama', 'status'],
  badge: ['ikon', 'nama', 'status'],
  riwayat_kelas: ['siswa', 'kelas', 'tanggal_mulai', 'tanggal_selesai'],
  hubungan: ['siswa', 'orang_tua', 'jenis_hubungan', 'tanggal_mulai', 'tanggal_selesai'],
  wali: ['guru', 'kelas', 'tanggal_mulai', 'tanggal_selesai'],
  pembina: ['guru', 'periode_ekstrakurikuler', 'tanggal_mulai', 'tanggal_selesai'],
  periode_ekskul: ['tahun_ajaran', 'status_kegiatan', 'status_pendaftaran'],
  versi_badge: ['nomor_versi', 'semester_mulai', 'semester_selesai', 'status'],
  level: ['nama', 'sumber_data', 'cara_hitung', 'target'],
  tahun: ['nama', 'tanggal_mulai', 'tanggal_selesai', 'aktif'],
  semester: ['nama', 'tahun_ajaran', 'tanggal_mulai', 'tanggal_selesai']
};
const labels = {
  nama: 'Nama',
  nisn: 'NISN',
  status_siswa: 'Status siswa',
  status_akun: 'Akun',
  peran_utama: 'Peran utama',
  tugas_wali: 'Kelas binaan',
  tugas_pembina: 'Ekskul binaan',
  telepon: 'Telepon',
  tingkat: 'Tingkat',
  status: 'Status',
  siswa: 'Siswa',
  kelas: 'Kelas',
  guru: 'Guru',
  tanggal_mulai: 'Mulai',
  tanggal_selesai: 'Sampai',
  orang_tua: 'Orang tua',
  jenis_hubungan: 'Hubungan',
  periode_ekstrakurikuler: 'Periode ekskul',
  tahun_ajaran: 'Tahun ajaran',
  nomor_versi: 'Versi',
  semester_mulai: 'Semester mulai',
  semester_selesai: 'Semester akhir',
  sumber_data: 'Sumber',
  cara_hitung: 'Perhitungan',
  target: 'Target',
  aktif: 'Aktif',
  ikon: 'Ikon',
  status_kegiatan: 'Kegiatan',
  status_pendaftaran: 'Pendaftaran'
};
const workspaceKeys = ['siswa', 'guru', 'orang_tua', 'kelas', 'ekskul', 'periode_ekskul', 'badge', 'versi_badge'];
const temporal = ['riwayat_kelas', 'wali', 'pembina', 'hubungan'];
const pretty = v => v == null || v === '' ? '—' : typeof v === 'boolean' ? v ? 'Ya' : 'Tidak' : typeof v === 'object' ? v.ekstrakurikuler ? `${v.ekstrakurikuler.nama} · ${v.tahun_ajaran?.nama || ''}` : v.nama ?? (v.nomor_versi ? 'Versi ' + v.nomor_versi : 'Data #' + v.id) : /^[A-Z_]+$/.test(String(v)) ? String(v).replaceAll('_', ' ').toLowerCase().replace(/^./, s => s.toUpperCase()) : String(v);
const titleOf = row => row.nama || row.identitas_login || (row.ekstrakurikuler ? `${row.ekstrakurikuler.nama} · ${row.tahun_ajaran?.nama || ''}` : row.nomor_versi ? `Versi ${row.nomor_versi} · ${row.badge?.nama || 'Badge'}` : 'Data #' + row.id);
function Cell({
  name,
  value
}) {
  if (name === 'ikon') return <Icon name={value || 'medal'} size={23} />;
  if (name.startsWith('status') || name === 'aktif') return <StatusBadge value={name === 'aktif' ? value ? 'AKTIF' : 'NONAKTIF' : value} />;
  return <>{pretty(value)}</>;
}
function DataTable({
  resource,
  rows,
  onOpen,
  onEdit,
  onDelete,
  onEnd,
  onReplace,
  readOnly = false
}) {
  const fields = columns[resource] || ['nama'];
  return <div className="table-scroll admin-table" tabIndex={0} role="region" aria-label="Daftar data"><table><thead><tr>{fields.map(f => <th key={f}>{labels[f] || f}</th>)}<th>Aksi</th></tr></thead><tbody>{!rows.length ? <tr><td colSpan={fields.length + 1}><EmptyState /></td></tr> : rows.map(row => <tr key={row.id} onDoubleClick={e => {
          if (!e.target.closest('button,a,input,select')) onOpen(resource, row);
        }}>{fields.map((f, i) => <td key={f}>{workspaceKeys.includes(f) && row[f]?.id || f === 'periode_ekstrakurikuler' && row[f]?.id || f === 'nama' || i === 0 && f !== 'ikon' ? <button type="button" className="admin-name" onClick={() => onOpen(row[f]?.id && (workspaceKeys.includes(f) || f === 'periode_ekstrakurikuler') ? f === 'periode_ekstrakurikuler' ? 'periode_ekskul' : f : resource, row[f]?.id && (workspaceKeys.includes(f) || f === 'periode_ekstrakurikuler') ? row[f] : row)}><Cell name={f} value={row[f]} /></button> : <Cell name={f} value={row[f]} />}</td>)}<td><RowActions><Button onClick={() => onOpen(resource, row)}>Lihat detail</Button>{!readOnly && <Button onClick={() => onEdit(resource, row)}><Icon name="edit" size={15} />Ubah</Button>}{!readOnly && temporal.includes(resource) && <Button onClick={() => onEnd(resource, row)}>Akhiri</Button>}{!readOnly && ['riwayat_kelas', 'wali', 'pembina'].includes(resource) && <Button onClick={() => onReplace(resource, row)}>Ganti</Button>}{!readOnly && <Button className="danger-text" onClick={() => onDelete(resource, row)}><Icon name="trash" size={15} />Hapus</Button>}</RowActions></td></tr>)}</tbody></table></div>;
}
function Pager({
  page,
  totalPages,
  onPage,
  total
}) {
  return <div className="table-footer"><span>{total} data · halaman {page} dari {Math.max(1, totalPages || 1)}</span><div><Button disabled={page <= 1} onClick={() => onPage(page - 1)}>Sebelumnya</Button><Button disabled={page >= Math.max(1, totalPages || 1)} onClick={() => onPage(page + 1)}>Berikutnya</Button></div></div>;
}
function Dashboard({
  data,
  onOpen,
  onSection
}) {
  const max = Math.max(1, ...data.distribution.map(r => Number(r.total)));
  return <><div className="admin-kpis">{[['siswa', 'Siswa aktif', 'users', 'master'], ['guru', 'Guru & tenaga sekolah', 'user', 'peran'], ['kelas', 'Kelas tahun ajaran', 'school', 'akademik'], ['ekskul', 'Ekstrakurikuler', 'activity', 'ekskul']].map(([key, label, icon, section]) => <button className="card admin-kpi" key={key} onClick={() => onSection(section)}><span className="admin-kpi-icon"><Icon name={icon} /></span><span>{label}<strong>{data.counts[key] || 0}</strong></span><Icon name="arrow" size={17} /></button>)}</div><div className="admin-two-columns"><section className="card"><div className="card-heading"><div><h2>Persebaran siswa</h2><p className="muted">Anggota kelas aktif pada tahun ajaran terpilih</p></div><Icon name="chart" /></div>{data.distribution.length ? <div className="admin-bars">{data.distribution.map(r => <button key={r.id} className="admin-chart-row" onClick={() => onOpen('kelas', r)}><span>{r.nama}</span><i><b style={{
                width: `${Number(r.total) / max * 100}%`
              }} /></i><strong>{r.total}</strong></button>)}</div> : <EmptyState />}</section><section className="card"><div className="card-heading"><h2>Akun & penugasan</h2><Icon name="shield" /></div><div className="admin-account-summary">{data.accounts.map(r => <div key={r.status_akun}><StatusBadge value={r.status_akun} /><strong>{r.total}</strong></div>)}</div><h3>Penugasan aktif</h3>{data.assignments.map(r => <div className="admin-summary-row" key={r.label}><span>{r.label}</span><strong>{r.total}</strong></div>)}</section></div><div className="admin-two-columns">{[['Siswa tanpa kelas aktif', data.missingStudents, 'siswa'], ['Kelas tanpa wali kelas', data.missingClasses, 'kelas']].map(([title, items, key]) => <section className="card" key={key}><div className="card-heading"><div><h2>{title}</h2><p className="muted">Kelengkapan data · maksimal 20 ditampilkan</p></div><Icon name="info" /></div>{items.length ? <div className="admin-completeness">{items.map(r => <Button key={r.id} onClick={() => onOpen(key, r)}>{r.nama}<Icon name="arrow" size={15} /></Button>)}</div> : <p className="admin-info">Data pada bagian ini sudah lengkap.</p>}</section>)}</div><section className="card"><div className="card-heading"><h2>Aktivitas administrasi terakhir</h2><Icon name="clock" /></div>{data.activity.length ? <div className="admin-timeline">{data.activity.map(r => <div key={r.id}><span className="admin-timeline-dot" /><div><strong>{pretty(r.jenis_tindakan)} · {pretty(r.nama_tabel)}</strong><small>{r.pelaku || 'Admin'} · {new Intl.DateTimeFormat('id-ID', {
                timeZone: 'Asia/Jakarta',
                dateStyle: 'medium',
                timeStyle: 'short'
              }).format(new Date(r.waktu))}</small></div></div>)}</div> : <EmptyState />}</section></>;
}
function ActionForm({
  action,
  onSaved,
  onClose
}) {
  const confirm = useConfirm(),
    lock = useRef(false);
  const [value, setValue] = useState(''),
    [date, setDate] = useState(today()),
    [busy, setBusy] = useState(false),
    [error, setError] = useState('');
  async function save(e) {
    e.preventDefault();
    if (lock.current) return;
    if (!(await confirm({
      title: action.kind === 'reset' ? 'Reset kata sandi?' : 'Simpan pergantian?',
      subject: titleOf(action.row),
      message: action.kind === 'reset' ? 'Sesi akun sebelumnya akan dicabut.' : 'Riwayat lama diakhiri sehari sebelum tanggal pergantian.',
      accept: 'Simpan'
    }))) return;
    lock.current = true;
    setBusy(true);
    try {
      await apiRequest(action.kind === 'reset' ? `/admin/accounts/${action.resource}/${action.row.id}/reset-password` : `/admin/${action.resource}/${action.row.id}/replace`, {
        method: 'POST',
        body: action.kind === 'reset' ? {
          kata_sandi: value
        } : {
          [action.resource === 'riwayat_kelas' ? 'id_kelas' : 'id_guru']: Number(value),
          tanggal_mulai: date
        }
      });
      onSaved('Perubahan berhasil disimpan.');
    } catch (e) {
      setError(e.message);
    } finally {
      lock.current = false;
      setBusy(false);
    }
  }
  return <Modal busy={busy} title={action.kind === 'reset' ? 'Reset kata sandi' : 'Pergantian dengan riwayat'} onClose={() => {
    if (!busy) onClose();
  }}><form onSubmit={save}>{action.kind === 'reset' ? <label className="admin-field">Kata sandi baru<input type="password" autoComplete="new-password" minLength={10} maxLength={128} required value={value} onChange={e => setValue(e.target.value)} /></label> : <><RelationField field={{
          ref: action.resource === 'riwayat_kelas' ? 'kelas' : 'guru',
          label: 'Pengganti',
          lookupGroup: action.resource === 'riwayat_kelas' ? undefined : 'teachers'
        }} value={value} onChange={setValue} /><label className="admin-field">Tanggal mulai<input type="date" required value={date} onChange={e => setDate(e.target.value)} /></label></>}{error && <p className="form-error" role="alert">{error}</p>}<div className="form-actions"><Button disabled={busy} onClick={onClose}>Batal</Button><Button type="submit" className="primary" disabled={busy}>Simpan</Button></div></form></Modal>;
}
function Workspace({
  profile,
  onLogout
}) {
  const {
      section = 'dashboard',
      entity,
      id
    } = useParams(),
    navigate = useNavigate(),
    [search, setSearch] = useSearchParams(),
    confirm = useConfirm(),
    guard = useRef(null),
    actionLock = useRef(false);
  const [metadata, setMetadata] = useState(null),
    [catalog, setCatalog] = useState(null),
    [years, setYears] = useState([]),
    [semesters, setSemesters] = useState([]),
    [data, setData] = useState(null),
    [error, setError] = useState(''),
    [loading, setLoading] = useState(true),
    [form, setForm] = useState(null),
    [action, setAction] = useState(null),
    [notice, setNotice] = useState(''),
    [noticeError, setNoticeError] = useState(false),
    [reload, setReload] = useState(0),
    [periodPanel, setPeriodPanel] = useState(false),
    [periodRows, setPeriodRows] = useState(null);
  const resources = tabs[section] || tabs.master,
    resource = resources.some(([key]) => key === search.get('tab')) ? search.get('tab') : resources[0]?.[0];
  const year = search.get('year') || years.find(y => y.aktif)?.id || years[0]?.id || '',
    semester = semesters.find(s => String(s.id) === search.get('semester') && String(s.id_tahun_ajaran) === String(year));
  const yearRow = years.find(y => String(y.id) === String(year));
  const baseAt = yearRow ? today() < yearRow.tanggal_mulai ? yearRow.tanggal_mulai : today() > yearRow.tanggal_selesai ? yearRow.tanggal_selesai : today() : today();
  const at = semester ? baseAt < semester.tanggal_mulai ? semester.tanggal_mulai : baseAt > semester.tanggal_selesai ? semester.tanggal_selesai : baseAt : baseAt;
  const history = search.get('history') === '1';
  const query = search.get('q') || '',
    page = Math.max(1, Number(search.get('page')) || 1),
    status = search.get('status') || '';
  const setParam = (key, value) => setSearch(old => {
    const next = new URLSearchParams(old);
    if (value) next.set(key, String(value));else next.delete(key);
    if (key !== 'page') next.delete('page');
    return next;
  }, {
    replace: true
  });
  useEffect(() => {
    let live = true;
    Promise.all([apiRequest('/admin/metadata'), apiRequest('/admin/badge-options'), apiRequest('/admin/tahun?limit=100'), apiRequest('/admin/semester?limit=100')]).then(([m, c, y, s]) => {
      if (live) {
        setMetadata(m.data);
        setCatalog(c.data);
        setYears(y.data);
        setSemesters(s.data.toSorted((a, b) => a.tanggal_mulai.localeCompare(b.tanggal_mulai)));
      }
    }).catch(e => {
      if (live) {
        setError(e.message);
        setLoading(false);
      }
    });
    return () => {
      live = false;
    };
  }, [reload]);
  useEffect(() => {
    if (!metadata) return;
    const controller = new AbortController();
    const timer = setTimeout(() => {
      setLoading(true);
      setError('');
      let path;
      if (entity && id) path = `/admin/${entity}/${id}/workspace${entity === 'kelas' && !history ? `?at=${at}` : ''}`;else if (section === 'dashboard') path = '/admin/overview' + (year ? '?id_tahun_ajaran=' + year : '');else path = `/admin/${resource}?limit=10&page=${page}&q=${encodeURIComponent(query)}${section === 'akademik' && year ? '&id_tahun_ajaran=' + year : ''}${status ? '&status_akun=' + status : ''}`;
      apiRequest(path, {
        signal: controller.signal
      }).then(p => {
        if (!controller.signal.aborted) setData(entity ? p.data : section === 'dashboard' ? p.data : {
          rows: p.data,
          meta: p.meta
        });
      }).catch(e => {
        if (!controller.signal.aborted) setError(e.message);
      }).finally(() => {
        if (!controller.signal.aborted) setLoading(false);
      });
    }, 180);
    return () => {
      clearTimeout(timer);
      controller.abort();
    };
  }, [metadata, section, entity, id, resource, page, query, status, year, at, history, reload]);
  const mayLeave = async () => {
    if (guard.current) return guard.current();
    if (form) return confirm({
      title: 'Tutup formulir?',
      message: 'Perubahan yang belum disimpan akan dibuang.',
      accept: 'Tutup Formulir'
    });
    return true;
  };
  const switchSection = async key => {
    if (!(await mayLeave())) return;
    setForm(null);
    setPeriodPanel(false);
    // Menu aktif mempertahankan data dan filter; detail tetap kembali ke daftar.
    if (key === section && !entity && !id) return;
    setData(null);
    navigate(`/admin/${key}${year ? '?year=' + year : ''}`);
  };
  const open = async (key, row) => {
    if (!(await mayLeave())) return;
    if (workspaceKeys.includes(key)) {
      const area = ['siswa', 'guru', 'orang_tua'].includes(key) ? section === 'peran' ? 'peran' : 'master' : key === 'kelas' ? 'akademik' : ['ekskul', 'periode_ekskul'].includes(key) ? 'ekskul' : 'badge';
      setForm(null);
      const params = new URLSearchParams(search);
      params.delete('view');
      params.delete('history');
      if (key === 'kelas' && row.id_tahun_ajaran) {
        params.set('year', String(row.id_tahun_ajaran));
        params.delete('semester');
      }
      navigate(`/admin/${area}/${key}/${row.id}?${params}`);
    } else setForm({
      kind: 'editor',
      resource: key,
      row
    });
  };
  const edit = (key, row, preset = {}) => setForm({
    kind: 'editor',
    resource: key,
    row,
    preset
  });
  const saved = message => {
    setNoticeError(false);
    setNotice(message);
    setForm(null);
    setAction(null);
    setReload(n => n + 1);
  };
  const notifyError = e => {
    setNoticeError(true);
    setNotice(e.message);
  };
  async function remove(key, row) {
    if (actionLock.current) return;
    if (!(await confirm({
      title: 'Hapus data?',
      subject: titleOf(row),
      message: 'Penghapusan permanen hanya diperbolehkan untuk data yang belum digunakan.',
      danger: true,
      accept: 'Hapus Data'
    }))) return;
    actionLock.current = true;
    try {
      await apiRequest(`/admin/${key}/${row.id}`, {
        method: 'DELETE'
      });
      if (entity === key && String(row.id) === id) navigate(`/admin/${section}?${search}`);
      saved('Data berhasil dihapus.');
    } catch (e) {
      notifyError(e);
    } finally {
      actionLock.current = false;
    }
  }
  async function end(key, row) {
    if (actionLock.current) return;
    const date = await confirm({
      title: 'Akhiri masa berlaku',
      subject: titleOf(row),
      message: 'Riwayat tetap disimpan. Pilih tanggal terakhir hubungan atau penugasan berlaku.',
      date: true,
      accept: 'Akhiri'
    });
    if (!date) return;
    actionLock.current = true;
    try {
      await apiRequest(`/admin/${key}/${row.id}`, {
        method: 'PATCH',
        body: {
          tanggal_selesai: date
        }
      });
      saved('Masa berlaku diperbarui.');
    } catch (e) {
      notifyError(e);
    } finally {
      actionLock.current = false;
    }
  }
  async function statusAccount(key, row) {
    const value = row.status_akun === 'AKTIF' ? 'NONAKTIF' : 'AKTIF';
    if (!(await confirm({
      title: pretty(value) + 'kan akun?',
      subject: row.nama,
      message: value === 'NONAKTIF' ? 'Akses dan sesi akun akan dicabut.' : 'Akun dapat login kembali sesuai kewenangannya.',
      accept: 'Simpan Status',
      danger: value === 'NONAKTIF'
    }))) return;
    try {
      await apiRequest(`/admin/${key}/${row.id}`, {
        method: 'PATCH',
        body: {
          status_akun: value
        }
      });
      saved('Status akun diperbarui.');
    } catch (e) {
      notifyError(e);
    }
  }
  const clearNotice = useCallback(() => setNotice(''), []);
  const tableProps = {
    onOpen: open,
    onEdit: edit,
    onDelete: remove,
    onEnd: end,
    onReplace: (key, row) => setAction({
      kind: 'replace',
      resource: key,
      row
    })
  };
  const root = data?.row,
    groups = data?.relations || [],
    selected = search.get('view') || (entity === 'kelas' ? 'riwayat_kelas' : entity === 'badge' ? 'versi_badge' : entity === 'versi_badge' ? 'level' : 'identitas');
  const showPeriods = async () => {
    try {
      const [y, s] = await Promise.all([apiRequest('/admin/tahun?limit=100'), apiRequest('/admin/semester?limit=100')]);
      setPeriodRows({
        tahun: y.data,
        semester: s.data
      });
      setPeriodPanel(true);
    } catch (e) {
      notifyError(e);
    }
  };
  const add = () => resource === 'siswa' ? setForm({
    kind: 'student'
  }) : resource === 'badge' ? setForm({
    kind: 'badge'
  }) : edit(resource, null, section === 'akademik' ? {
    id_tahun_ajaran: Number(year)
  } : {});
  return <PortalShell tone="admin" className="admin-workspace portal management-ui admin-integrated" base="/admin" label="Manajemen Sekolah" sections={sections} profile={profile} roleLabel="Administrator" onLogout={async () => {
    if (await mayLeave()) onLogout();
  }} onBeforeNavigate={switchSection}><div className="dashboard-main"><div className="page-heading"><div><span className="eyebrow">ADMINISTRASI SEKOLAH</span><h1>{root && !loading ? titleOf(root) : sections[section]?.[0] || 'Data Master'}</h1><p>{entity ? 'Kelola identitas dan seluruh keterkaitan dari satu tempat.' : section === 'dashboard' ? 'Data sekolah, kelengkapan administrasi, dan akses cepat.' : 'Data yang saling terhubung, dengan riwayat yang tetap tersimpan.'}</p></div><div className="heading-actions">{['dashboard', 'akademik'].includes(section) && <><label className="admin-context-select">Tahun ajaran<select aria-label="Tahun ajaran" disabled={!!form} value={year} onChange={e => setParam('year', e.target.value)}>{years.map(y => <option key={y.id} value={y.id}>{y.nama}{y.aktif ? ' · aktif' : ''}</option>)}</select></label>{section === 'akademik' && <label className="admin-context-select">Semester<select aria-label="Semester" disabled={!!form} value={semester?.id || ''} onChange={e => setParam('semester', e.target.value)}><option value="">Kondisi saat ini</option>{semesters.filter(s => String(s.id_tahun_ajaran) === String(year)).map(s => <option key={s.id} value={s.id}>{s.nama}</option>)}</select></label>}</>}{!form && !entity && section !== 'dashboard' && <Button className="primary" disabled={!metadata} onClick={add}><Icon name="plus" size={17} />Tambah {metadata?.[resource]?.label}</Button>}{!form && section === 'akademik' && <><Button onClick={showPeriods}>Kelola Periode Akademik</Button>{entity === 'kelas' && <Button onClick={() => setParam('history', history ? '' : '1')}>{history ? 'Lihat periode terpilih' : 'Riwayat lengkap'}</Button>}</>}</div></div><Notice message={notice} error={noticeError} onClose={clearNotice} />
 {form ? form.kind === 'student' || form.kind === 'parent' ? <StudentForm key={form.kind} metadata={metadata} studentId={form.studentId} onClose={() => setForm(null)} onSaved={saved} /> : form.kind === 'badge' ? <BadgeForm key={form.existing?.row.id || 'new'} catalog={catalog} semesters={semesters} existing={form.existing} onClose={() => setForm(null)} onSaved={saved} /> : <Editor key={form.resource + '-' + (form.row?.id || 'new')} resource={form.resource} spec={metadata[form.resource]} catalog={catalog} row={form.row} preset={form.preset} onSaved={saved} onClose={() => setForm(null)} registerGuard={guard} /> : <>{loading ? <LoadingState /> : error ? <section className="card admin-error"><h2>Data belum dapat ditampilkan</h2><p role="alert">{error}</p><Button onClick={() => setReload(n => n + 1)}>Coba lagi</Button></section> : data && section === 'dashboard' && !entity ? <><div className="admin-shortcuts">{[['Tambah siswa', () => setForm({
              kind: 'student'
            }), 'users'], ['Tambah guru', () => edit('guru', null), 'user'], ['Kelola kelas', () => switchSection('akademik'), 'school'], ['Buat badge', () => setForm({
              kind: 'badge'
            }), 'medal']].map(([label, click, icon]) => <Button key={label} onClick={click}><Icon name={icon} />{label}</Button>)}</div><Dashboard data={data} onOpen={open} onSection={switchSection} /></> : data && root ? <>
 <nav className="admin-breadcrumb"><Link to={`/admin/${section}?${search}`}>{sections[section]?.[0]}</Link>{entity === 'versi_badge' && <Link to={`/admin/badge/badge/${root.id_badge}`}>Badge induk</Link>}<span>{titleOf(root)}</span></nav><section className="card admin-profile-head"><span className="admin-profile-mark"><Icon name={entity === 'badge' || entity === 'versi_badge' ? root.ikon || 'medal' : ['siswa', 'guru', 'orang_tua'].includes(entity) ? 'user' : 'school'} size={32} /></span><div><h2>{titleOf(root)}</h2><p>{root.identitas_login || metadata?.[entity]?.label}</p>{root.status_akun && <StatusBadge value={root.status_akun} />}</div><div className="admin-profile-actions">{!(entity === 'versi_badge' && data.locked) && <Button onClick={() => edit(entity, root)}><Icon name="edit" size={16} />Ubah identitas</Button>}{['siswa', 'guru', 'orang_tua'].includes(entity) && <><Button onClick={() => setAction({
                  kind: 'reset',
                  resource: entity,
                  row: root
                })}>Reset sandi</Button><Button onClick={() => statusAccount(entity, root)}>{root.status_akun === 'AKTIF' ? 'Nonaktifkan' : 'Aktifkan'}</Button></>}{entity === 'badge' && <Button className="primary" onClick={() => setForm({
                kind: 'badge',
                existing: data
              })}>+ Versi Aturan Baru</Button>}</div></section><div className="admin-tabs" role="tablist"><Button role="tab" aria-selected={selected === 'identitas'} className={selected === 'identitas' ? 'selected' : ''} onClick={() => setParam('view', 'identitas')}>Identitas</Button>{['siswa', 'guru', 'orang_tua'].includes(entity) && <Button role="tab" aria-selected={selected === 'akun'} className={selected === 'akun' ? 'selected' : ''} onClick={() => setParam('view', 'akun')}>Akun</Button>}{groups.map(g => <Button role="tab" aria-selected={selected === g.resource} className={selected === g.resource ? 'selected' : ''} key={g.resource} onClick={() => setParam('view', g.resource)}>{g.label} <small>{g.total}</small></Button>)}</div>
 {selected === 'identitas' ? <section className="card"><div className="card-heading"><h2>Informasi {metadata?.[entity]?.label}</h2><Button className="danger-text" onClick={() => remove(entity, root)}>Hapus jika belum digunakan</Button></div><dl className="admin-info-grid">{metadata?.[entity]?.fields.filter(f => !f.name.startsWith('id_')).map(f => <div key={f.name}><dt>{f.label}</dt><dd><Cell name={f.name} value={root[f.name]} /></dd></div>)}{entity === 'guru' && <div><dt>Peran utama</dt><dd>{root.peran_utama?.nama}</dd></div>}</dl>{entity === 'guru' && <p className="admin-info">Satu peran utama per akun. Wali Kelas dan Pembina merupakan penugasan tambahan; atur melalui tab terkait.</p>}{entity === 'versi_badge' && data.locked && <p className="admin-info">Aturan yang berlaku atau sudah digunakan dilindungi. Buat versi baru melalui badge induk untuk semester mendatang.</p>}</section> : selected === 'akun' ? <section className="card"><h2>Akun & akses</h2><dl className="admin-info-grid"><div><dt>Identitas akun</dt><dd>{root.identitas_login}</dd></div><div><dt>Status</dt><dd><StatusBadge value={root.status_akun} /></dd></div><div><dt>Peran utama</dt><dd>{root.peran_utama?.nama || metadata[entity].label}</dd></div></dl><div className="form-actions"><Button onClick={() => edit(entity, root)}>Ubah akun</Button><Button onClick={() => setAction({
                kind: 'reset',
                resource: entity,
                row: root
              })}>Reset sandi</Button><Button onClick={() => statusAccount(entity, root)}>{root.status_akun === 'AKTIF' ? 'Nonaktifkan' : 'Aktifkan'}</Button></div></section> : groups.filter(g => g.resource === selected).map(g => <section className="card" key={g.resource}><div className="card-heading"><div><h2>{g.label}</h2><p className="muted">Perubahan di sini juga terlihat pada data terkait.</p></div>{!(entity === 'versi_badge' && data.locked) && g.resource !== 'versi_badge' && <Button className="primary" onClick={() => g.resource === 'hubungan' && entity === 'siswa' ? setForm({
                kind: 'parent',
                studentId: root.id
              }) : edit(g.resource, null, {
                [g.field]: root.id,
                ...(['riwayat_kelas', 'wali', 'pembina', 'hubungan'].includes(g.resource) ? {
                  tanggal_mulai: at
                } : {})
              })}>+ {g.label}</Button>}{g.resource === 'versi_badge' && <Button className="primary" onClick={() => setForm({
                kind: 'badge',
                existing: data
              })}>+ Versi Baru</Button>}</div><DataTable {...tableProps} resource={g.resource} rows={g.rows} readOnly={entity === 'versi_badge' && data.locked} /><Pager total={g.total} page={g.page} totalPages={g.totalPages} onPage={async page => {
              try {
                const p = await apiRequest(`/admin/${entity}/${id}/workspace?group=${g.resource}&page=${page}${entity === 'kelas' && !history ? '&at=' + at : ''}`);
                setData(p.data);
              } catch (e) {
                notifyError(e);
              }
            }} /></section>)}</> : data && <>
 <div className="admin-tabs" role="tablist">{resources.map(([key, label]) => <Button role="tab" aria-selected={resource === key} key={key} className={resource === key ? 'selected' : ''} onClick={() => setParam('tab', key)}>{label}</Button>)}</div><section className="card"><div className="admin-list-tools"><div className="admin-search"><Icon name="search" size={18} /><input aria-label="Cari data" placeholder="Cari nama atau identitas…" value={query} onChange={e => setParam('q', e.target.value)} /></div>{['siswa', 'guru', 'orang_tua'].includes(resource) && <select aria-label="Status akun" value={status} onChange={e => setParam('status', e.target.value)}><option value="">Semua akun</option><option value="AKTIF">Aktif</option><option value="NONAKTIF">Nonaktif</option></select>}<IconAction label="Muat ulang data" onClick={()=>setReload(n=>n+1)}/></div>{resource === 'badge' ? <div className="admin-badge-grid">{data.rows.length ? data.rows.map(row => <button key={row.id} className="admin-badge-card" onClick={() => open('badge', row)}><span className="admin-badge-preview"><Icon name={row.ikon || 'medal'} size={38} /></span><StatusBadge value={row.status} /><h3>{row.nama}</h3><p>{row.deskripsi || 'Kelola ikon, aturan dan level badge otomatis.'}</p><span>Kelola badge <Icon name="arrow" size={15} /></span></button>) : <EmptyState />}</div> : <DataTable {...tableProps} resource={resource} rows={data.rows} />}<Pager page={page} total={data.meta?.total || 0} totalPages={data.meta?.totalPages} onPage={p => setParam('page', p)} /></section></>}</>}
 {periodPanel && periodRows && <Modal drawer title="Periode akademik" onClose={() => setPeriodPanel(false)}>{['tahun', 'semester'].map(key => <section className="admin-period-section" key={key}><div className="card-heading"><h2>{key === 'tahun' ? 'Tahun ajaran' : 'Semester'}</h2><Button onClick={() => {
              setPeriodPanel(false);
              edit(key, null, key === 'semester' ? {
                id_tahun_ajaran: Number(year)
              } : {});
            }}>Tambah</Button></div><DataTable {...tableProps} resource={key} rows={periodRows[key]} onOpen={(k, row) => {
            setPeriodPanel(false);
            edit(k, row);
          }} onEdit={(k, row) => {
            setPeriodPanel(false);
            edit(k, row);
          }} /></section>)}</Modal>}{action && <ActionForm key={action.resource + '-' + action.row.id} action={action} onClose={() => setAction(null)} onSaved={saved} />}<footer>SIM Kesiswaan · SMAN 12 Padang · Data tersimpan di database</footer></div></PortalShell>;
}
export default function AdminPage(props) {
  return <ManagementProvider><Workspace {...props} /></ManagementProvider>;
}
