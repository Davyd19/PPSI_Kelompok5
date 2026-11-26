import PortalShell from '../../components/PortalShell';
import { useConfirm } from '../../hooks/useConfirm';
import { useCallback, useEffect, useRef, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { apiRequest } from '../../api/client';
import Button from '../../components/Button';
import Icon from '../../components/Icon';
import { Card, Feedback, Stat } from '../../components/Ui';
import { ManagementProvider, Modal as Dialog, Notice, StatusBadge, RowActions, LoadingState, EmptyState } from '../../components/ManagementUi';
import { sameValues } from '../../utils/management';
import '../../styles/admin.css';
import '../../styles/portal.css';
const sections = {
  master: {
    title: 'Data Master',
    description: 'Kelola identitas dan akun warga sekolah.',
    tabs: [['siswa', 'Siswa'], ['guru', 'Guru'], ['orang_tua', 'Orang Tua']]
  },
  peran: {
    title: 'Peran Guru',
    description: 'Tetapkan peran utama akun dan tugas tambahan Guru BK.',
    tabs: [['guru', 'Peran Utama Akun'], ['peran', 'Daftar Peran Sistem']]
  },
  hubungan: {
    title: 'Hubungan Orang Tua–Anak',
    description: 'Hubungan keluarga menentukan akses informasi anak.',
    tabs: [['hubungan', 'Hubungan Keluarga']]
  },
  akun: {
    title: 'Akun Pengguna',
    description: 'Kelola identitas login, status akun, dan reset kata sandi.',
    tabs: [['accounts', 'Semua Akun']]
  },
  akademik: {
    title: 'Kelas & Tahun Ajaran',
    description: 'Kelola periode akademik dan riwayat kelas siswa.',
    tabs: [['tahun', 'Tahun Ajaran'], ['semester', 'Semester'], ['kelas', 'Kelas'], ['riwayat_kelas', 'Anggota & Riwayat Kelas']]
  },
  badge: {
    title: 'Konfigurasi Badge',
    description: 'Atur badge otomatis dan satu syarat per level. Pencapaian dihitung otomatis dari presensi.',
    tabs: [['badge', 'Badge'], ['versi_badge', 'Versi Aturan'], ['level', 'Level & Syarat']]
  },
  penugasan: {
    title: 'Penugasan',
    description: 'Kelola penugasan guru serta data dasar kegiatan ekstrakurikuler.',
    tabs: [['wali', 'Wali Kelas'], ['pembina', 'Pembina Ekskul'], ['ekskul', 'Ekstrakurikuler'], ['periode_ekskul', 'Periode Ekskul']]
  }
};
const menu = [['dashboard', 'Beranda', 'dashboard'], ['master', 'Data Master', 'users'], ['akun', 'Akun Pengguna', 'user'], ['peran', 'Peran Guru', 'shield'], ['hubungan', 'Orang Tua–Anak', 'users'], ['akademik', 'Kelas & Tahun Ajaran', 'calendar'], ['badge', 'Konfigurasi Badge', 'badge'], ['penugasan', 'Penugasan', 'file']];
const pretty = v => v == null || v === '' ? '—' : typeof v === 'boolean' ? v ? 'Ya' : 'Tidak' : (/^[A-Z][A-Z_]*$/.test(String(v)) ? String(v).toLowerCase().replace(/^./, c => c.toUpperCase()) : String(v)).replaceAll('_', ' ');
const dateTime = v => new Intl.DateTimeFormat('id-ID', {
  timeZone: 'Asia/Jakarta',
  dateStyle: 'medium',
  timeStyle: 'short'
}).format(new Date(v));
const temporal = ['guru_peran', 'hubungan', 'riwayat_kelas', 'wali', 'pembina'];
function dateInput(v) {
  if (!v) return '';
  const d = new Date(v);
  return new Date(d.getTime() + 7 * 3600000).toISOString().slice(0, 16);
}
function RelationField({
  field,
  value,
  onChange
}) {
  const [search, setSearch] = useState(''),
    [page, setPage] = useState(1),
    [rows, setRows] = useState([]),
    [selected, setSelected] = useState(null),
    [total, setTotal] = useState(0),
    [error, setError] = useState('');
  useEffect(() => {
    const c = new AbortController();
    const timer = setTimeout(() => {
      apiRequest(`/admin/lookups/${field.ref}?group=${field.lookupGroup || ''}&q=${encodeURIComponent(search)}&page=${page}&limit=20`, {
        signal: c.signal
      }).then(p => {
        setRows(p.data);
        setTotal(p.meta.total);
        setError('');
      }).catch(e => {
        if (!c.signal.aborted) setError(e.message);
      });
    }, 180);
    return () => {
      clearTimeout(timer);
      c.abort();
    };
  }, [field.ref, field.lookupGroup, search, page]);
  useEffect(() => {
    if (!value) {
      setSelected(null);
      return;
    }
    let active = true;
    apiRequest(`/admin/${field.ref}/${value}`).then(p => {
      if (active) setSelected({
        id: p.data.id,
        label: p.data.nama || `${field.ref} #${p.data.id}`
      });
    }).catch(() => { });
    return () => {
      active = false;
    };
  }, [value, field.ref]);
  const choices = selected && !rows.some(r => String(r.id) === String(selected.id)) ? [selected, ...rows] : rows;
  return <div className="relation-input"><input aria-label={`Cari ${field.label}`} placeholder="Cari pilihan…" value={search} onChange={e => {
    setSearch(e.target.value);
    setPage(1);
  }} /><select id={field.name ? `field-${field.name}` : undefined} aria-label={field.label} value={value ?? ''} onChange={e => onChange(e.target.value)}><option value="">{field.nullable ? 'Tidak dipilih' : 'Pilih data'}</option>{choices.map(r => <option key={r.id} value={r.id}>{r.label} · #{r.id}</option>)}</select><div className="lookup-pager"><Button disabled={page === 1} onClick={() => setPage(p => p - 1)}>Sebelumnya</Button><small>{page} · {total} pilihan</small><Button disabled={page * 20 >= total} onClick={() => setPage(p => p + 1)}>Berikutnya</Button></div>{error && <small role="alert">{error}</small>}</div>;
}
function fullEditor(spec,row,accountOnly) {
  if(accountOnly) return false;
  return spec.fields.length + (!row && ['Guru','Siswa','OrangTua'].includes(spec.name) ? 1 : 0) > 7;
}
function Editor({
  spec,
  row,
  accountOnly,
  resource,
  onSaved,
  registerGuard,
  onClose
}) {
  const fields = accountOnly ? spec.fields.filter(f => ['identitas_login', 'status_akun', 'id_peran_utama'].includes(f.name)) : spec.fields;
  const [values, setValues] = useState(() => Object.fromEntries(fields.map(f => [f.name, f.type === 'datetime' ? dateInput(row?.[f.name]) : row?.[f.name] ?? (f.type === 'boolean' ? false : '')]))),
    [password, setPassword] = useState(''),
    [error, setError] = useState(''),
    [errors, setErrors] = useState({}),
    [busy, setBusy] = useState(false);
  const confirm = useConfirm();
  const submitLock=useRef(false);
  const [initialValues] = useState(() => ({ ...values }));
  const full = fullEditor(spec,row,accountOnly);
  const groupOf = field => ['identitas_login','status_akun','id_peran_utama'].includes(field.name) ? 'Akun dan Akses' : ['email','telepon'].includes(field.name) ? 'Informasi Kontak' : field.ref ? 'Keterkaitan Data' : ['date','datetime'].includes(field.type) ? 'Periode dan Masa Berlaku' : 'Informasi Utama';
  const fieldGroups = full ? ['Informasi Utama','Akun dan Akses','Informasi Kontak','Keterkaitan Data','Periode dan Masa Berlaku'].map(name=>[name,fields.filter(field=>groupOf(field)===name)]).filter(([,items])=>items.length) : [['Informasi',fields]];
  const dirty = !sameValues(initialValues, values) || password !== '';
  const mayLeave = useCallback(async () => {
    if (busy) return false;
    if (dirty && !await confirm({title:'Buang perubahan?', message:'Perubahan pada formulir ini belum disimpan.', accept:'Buang Perubahan', danger:true})) return false;
    return true;
  }, [busy,dirty,confirm]);
  useEffect(() => {registerGuard.current=mayLeave;return()=>{registerGuard.current=null;};},[registerGuard,mayLeave]);
  const close = async () => {if(await mayLeave()) onClose();};
  async function submit(e) {
    e.preventDefault();
    if(submitLock.current) return;
    submitLock.current=true;
    setBusy(true);
    setError('');
    setErrors({});
    try {
      const body = {};
      for (const f of fields) {
        let v = values[f.name];
        if (v === '' || v == null) v = null; else if (f.type === 'datetime') v = new Date(`${v}:00+07:00`).toISOString(); else if (f.type === 'id' || f.type === 'integer') v = Number(v);
        body[f.name] = v;
      }
      if (!row && ['guru', 'siswa', 'orang_tua'].includes(resource)) body.kata_sandi = password;
      if (row && ['versi_badge', 'level', ...temporal].includes(resource)) for (const k of Object.keys(body)) if (String(body[k] ?? '') === String(row[k] ?? '')) delete body[k];
      const impacts = [];
      if (resource === 'guru' && row && Number(body.id_peran_utama) !== Number(row.id_peran_utama)) {
        impacts.push('Peran utama berubah dan seluruh sesi akun dicabut. Tugas Guru yang masih aktif harus diakhiri dahulu.');
        body.konfirmasi_peran = true;
      }
      if (row && Object.keys(body).length === 0) {
        onClose();
        return;
      }
      if (resource === 'tahun' && body.aktif === true && (!row || row.aktif !== true)) impacts.push('Tahun ajaran ini menjadi aktif dan tahun ajaran sebelumnya dinonaktifkan.');
      if (row && ['status_akun', 'status', 'status_kegiatan', 'aktif'].some(k => k in body && body[k] !== row[k])) impacts.push('Status data berubah. Akses dan penggunaan mengikuti status terbaru.');
      if (impacts.length && !await confirm({title:'Simpan perubahan penting?', message:'Periksa dampak perubahan sebelum melanjutkan.', subject:values.nama || row?.nama || spec.label, details:impacts, accept:'Simpan Perubahan'})) return;
      await apiRequest(`/admin/${resource}${row ? `/${row.id}` : ''}`, {
        method: row ? 'PATCH' : 'POST',
        body
      });
      onSaved(row ? 'Perubahan berhasil disimpan.' : 'Data berhasil ditambahkan.');
    } catch (e) {
      setError(e.message);
      setErrors(e.details || {});
    } finally {
      submitLock.current=false;
      setBusy(false);
    }
  }
  const content = <form onSubmit={submit} noValidate aria-busy={busy}><fieldset className="mg-form-fields" disabled={busy}><p className="muted">{row ? `Mengubah data #${row.id}.` : 'Lengkapi informasi berikut.'} Tanda * wajib diisi. Waktu menggunakan WIB.</p><div className="mg-form-sections">{fieldGroups.map(([groupTitle,groupFields])=><section className="mg-form-section" key={groupTitle}>{full && <h3>{groupTitle}</h3>}<div className="admin-form-grid">{groupFields.map(f => <div className={`admin-field ${f.type === 'text' ? 'span-full' : ''}`} key={f.name} data-invalid={Boolean(errors[f.name])}><label htmlFor={`field-${f.name}`}>{f.label}{!f.nullable ? ' *' : ''}</label>{f.ref ? <RelationField field={f} value={values[f.name]} onChange={v => setValues(s => ({
    ...s,
    [f.name]: v
  }))} /> : f.options ? <select id={`field-${f.name}`} value={values[f.name]} onChange={e => setValues(s => ({
    ...s,
    [f.name]: e.target.value
  }))}><option value="">{f.nullable ? 'Tidak dipilih' : 'Pilih'}</option>{f.options.filter(v => f.name !== 'status_kehadiran_yang_dihitung' || v !== 'TERLAMBAT' || values[f.name] === v).map(v => <option key={v} value={v}>{pretty(v)}</option>)}</select> : f.type === 'boolean' ? <select id={`field-${f.name}`} value={String(values[f.name])} onChange={e => setValues(s => ({
    ...s,
    [f.name]: e.target.value === 'true'
  }))}><option value="true">Ya</option><option value="false">Tidak</option></select> : f.type === 'text' ? <textarea id={`field-${f.name}`} value={values[f.name]} rows={4} onChange={e => setValues(s => ({
    ...s,
    [f.name]: e.target.value
  }))} /> : <input id={`field-${f.name}`} type={f.type === 'date' ? 'date' : f.type === 'datetime' ? 'datetime-local' : f.type === 'integer' ? 'number' : f.name === 'email' ? 'email' : 'text'} value={values[f.name]} onChange={e => setValues(s => ({
    ...s,
    [f.name]: e.target.value
  }))} />} {errors[f.name] && <small className="form-error">{errors[f.name]}</small>}</div>)}</div></section>)}{!row && ['guru', 'siswa', 'orang_tua'].includes(resource) && <div className="admin-field"><label htmlFor="initial-password">Kata sandi awal *</label><input id="initial-password" autoComplete="new-password" type="password" value={password} onChange={e => setPassword(e.target.value)} /><small>10–128 karakter. Sampaikan kepada pemilik akun secara pribadi.</small></div>}</div></fieldset>{error && <p role="alert" className="form-error">{error}</p>}<div className="form-actions"><Button disabled={busy} onClick={close}>Batal</Button><Button className="primary" type="submit" disabled={busy}>{busy ? 'Menyimpan…' : 'Simpan'}</Button></div></form>;
  if (full) return <section className="card admin-editor-page"><div className="card-heading"><h2>{row ? 'Ubah' : 'Tambah'} {spec.label}</h2><Button disabled={busy} onClick={close}>Kembali ke daftar</Button></div>{content}</section>;
  return <Dialog title={`${row ? 'Ubah' : 'Tambah'} ${spec.label}`} busy={busy} onClose={close}>{content}</Dialog>;
}
function AdminWorkspace({
  profile,
  onLogout
}) {
  const {
    section = 'dashboard'
  } = useParams(),
    navigate = useNavigate();
  const confirm = useConfirm();
  const [noticeError,setNoticeError] = useState(false);
  const editorGuard=useRef(null);
  const actionLock=useRef(false);
  const config = sections[section];
  const [tab, setTab] = useState(null),
    [metadata, setMetadata] = useState(null),
    [rows, setRows] = useState([]),
    [meta, setMeta] = useState({
      total: 0
    }),
    [summary, setSummary] = useState(null),
    [query, setQuery] = useState(''),
    [filter, setFilter] = useState(''),
    [page, setPage] = useState(1),
    [loading, setLoading] = useState(true),
    [error, setError] = useState(''),
    [reload, setReload] = useState(0),
    [editor, setEditor] = useState(null),
    [notice, setNotice] = useState(''),
    [details, setDetails] = useState(null),
    [reset, setReset] = useState(null),
    [password, setPassword] = useState(''),
    [actionError, setActionError] = useState(''),
    [actionBusy, setActionBusy] = useState(false),
    [panel, setPanel] = useState(null),
    [replacement, setReplacement] = useState(null),
    [replacementTarget, setReplacementTarget] = useState(''),
    [replacementDate, setReplacementDate] = useState('');
  const resource = config?.tabs.some(([k]) => k === tab) ? tab : config?.tabs[0][0];
  const isAccounts = resource === 'accounts';
  const spec = metadata?.[resource];
  useEffect(() => {
    apiRequest('/admin/metadata').then(p => setMetadata(p.data)).catch(e => setError(e.message));
  }, []);
  useEffect(() => {
    const c = new AbortController();
    const timer = setTimeout(() => {
      setLoading(true);
      setError('');
      const url = section === 'dashboard' ? '/admin/summary' : `/admin/${resource}?page=${page}&limit=10&q=${encodeURIComponent(query)}${filter ? `&${isAccounts ? 'kind' : spec?.fields.find(f => f.name === 'status_akun') ? 'status_akun' : spec?.fields.find(f => f.name === 'status') ? 'status' : 'tingkat'}=${filter}` : ''}`;
      apiRequest(url, {
        signal: c.signal
      }).then(p => {
        if (section === 'dashboard') setSummary(p.data); else {
          setRows(p.data);
          setMeta(p.meta);
        }
      }).catch(e => {
        if (!c.signal.aborted) setError(e.message);
      }).finally(() => {
        if (!c.signal.aborted) setLoading(false);
      });
    }, 200);
    return () => {
      clearTimeout(timer);
      c.abort();
    };
  }, [section, resource, page, query, filter, isAccounts, spec, reload]);
  const closeDetails = useCallback(() => setDetails(null), []);
  const closePanel = useCallback(() => setPanel(null), []);
  const closeNotice = useCallback(() => setNotice(''), []);
  async function switchSection(key) {
    if(editorGuard.current && !await editorGuard.current()) return;
    setLoading(true);
    setRows([]);
    setTab(null);
    setEditor(null);
    setPage(1);
    setQuery('');
    setFilter('');
    setNotice('');
    navigate(`/admin/${key}`);
  }
  function saved(message) {
    setNoticeError(false);
    setEditor(null);
    setReset(null);
    setPassword('');
    setNotice(message);
    setReload(n => n + 1);
  }
  async function closeReset() {
    if(actionBusy) return;
    if(password && !await confirm({title:'Buang kata sandi baru?',message:'Kata sandi yang Anda isi belum disimpan.',danger:true,accept:'Buang Perubahan'})) return;
    setReset(null);setPassword('');setActionError('');
  }
  async function closeReplacement() {
    if(actionBusy) return;
    if((replacementTarget || replacementDate) && !await confirm({title:'Buang pergantian?',message:'Rancangan pergantian belum disimpan. Data sebelumnya tetap berlaku.',danger:true,accept:'Buang Perubahan'})) return;
    setReplacement(null);setActionError('');
  }
  async function requestLogout() {
    if(editorGuard.current && !await editorGuard.current()) return;
    onLogout();
  }
  async function remove(row) {
    if(actionLock.current) return;
    if (!await confirm({title:'Hapus data ini?',subject:row.nama || row.identitas_login || (spec.label+' #'+row.id),message:'Data akan dihapus permanen. Tindakan ini tidak dapat dibatalkan.',details:['Hanya data yang belum digunakan yang dapat dihapus. Jika masih dirujuk, sistem akan menjelaskan alasannya.'],danger:true,accept:'Hapus Data'})) return;
    actionLock.current=true;
    setActionBusy(true);
    try {
      await apiRequest(`/admin/${resource}/${row.id}`, {
        method: 'DELETE'
      });
      if (rows.length === 1 && page > 1) setPage(n => n - 1);
      saved('Data berhasil dihapus.');
    } catch (e) {
      setNoticeError(true);
      setNotice(e.message);
    } finally {
      actionLock.current=false;
      setActionBusy(false);
    }
  }
  async function end(row) {
    if(actionLock.current) return;
    const date = await confirm({title:'Akhiri masa berlaku',subject:row.nama || spec.label+' #'+row.id,message:'Tentukan tanggal terakhir hubungan atau penugasan ini berlaku. Riwayat tetap tersimpan.',date:true,accept:'Akhiri Masa Berlaku'});
    if (!date) return;
    actionLock.current=true;
    setActionBusy(true);
    try {
      await apiRequest(`/admin/${resource}/${row.id}`, {
        method: 'PATCH',
        body: {
          tanggal_selesai: date
        }
      });
      saved('Masa berlaku berhasil diperbarui.');
    } catch (e) {
      setNoticeError(true);
      setNotice(e.message);
    } finally {
      actionLock.current=false;
      setActionBusy(false);
    }
  }
  async function resetPassword(e) {
    e.preventDefault();
    if(actionLock.current) return;
    if (!await confirm({title:'Reset kata sandi?',subject:reset.nama,message:'Kata sandi akan diganti dan sesi akun sebelumnya tidak berlaku lagi.',accept:'Reset Kata Sandi'})) return;
    actionLock.current=true;
    setActionBusy(true);
    setActionError('');
    try {
      await apiRequest(`/admin/accounts/${reset.kind}/${reset.id}/reset-password`, {
        method: 'POST',
        body: {
          kata_sandi: password
        }
      });
      saved('Kata sandi berhasil direset.');
    } catch (e) {
      setActionError(e.message);
    } finally {
      actionLock.current=false;
      setActionBusy(false);
    }
  }
  async function replaceAssignment(e) {
    e.preventDefault();
    if(actionLock.current) return;
    if (!await confirm({title:'Simpan pergantian?',subject:replacement.nama || spec.label+' #'+replacement.id,message:'Masa lama berakhir sehari sebelum tanggal mulai yang baru. Riwayat sebelumnya tetap tersimpan.',accept:'Simpan Pergantian'})) return;
    actionLock.current=true;
    setActionBusy(true);
    setActionError('');
    try {
      await apiRequest(`/admin/${resource}/${replacement.id}/replace`, {
        method: 'POST',
        body: {
          [resource === 'riwayat_kelas' ? 'id_kelas' : 'id_guru']: Number(replacementTarget),
          tanggal_mulai: replacementDate
        }
      });
      setReplacement(null);
      saved('Pergantian tersimpan beserta riwayat sebelumnya.');
    } catch (e) {
      setActionError(e.message);
    } finally {
      actionLock.current=false;
      setActionBusy(false);
    }
  }
  const listFields=spec ? spec.fields.filter(f=>!['text','datetime'].includes(f.type)) : [];
  const columns=listFields.slice(0,5);
  const statusField=listFields.find(f=>['status_akun','status','status_kegiatan','aktif'].includes(f.name));
  if(statusField && !columns.some(f=>f.name===statusField.name)) columns.splice(4,1,statusField);
  const filterOptions = isAccounts ? ['guru', 'siswa', 'orang_tua'] : spec?.fields.find(f => ['status_akun', 'status', 'tingkat'].includes(f.name))?.options || [];
  const title = config?.title || 'Dashboard Admin';
  return <PortalShell tone="admin" className="admin-workspace portal management-ui" base="/admin" label="Manajemen Sekolah" sections={Object.fromEntries(menu.map(([key,label,icon])=>[key,[label,icon]]))} profile={profile} roleLabel="Administrator" onLogout={requestLogout} onBeforeNavigate={switchSection} sideFooter={<Button onClick={()=>setPanel('Panduan')}><Icon name="help"/>Panduan</Button>}>
    <div className="dashboard-main"><div className="page-heading"><div><span className="eyebrow">PORTAL ADMINISTRASI</span><h1>{title}</h1><p>{config?.description || 'Ringkasan data sekolah yang tersimpan di database.'}</p></div>{config && !isAccounts && !spec?.readOnly && <Button className="primary" disabled={!spec} onClick={() => {
      setEditor({
        row: null,
        resource
      });
      setNotice('');
    }}>+ Tambah {spec?.label}</Button>}</div>
      {config && <div className="admin-tabs" role="tablist">{config.tabs.map(([key, label]) => <Button role="tab" aria-selected={resource === key} key={key} className={resource === key ? 'selected' : ''} onClick={async () => {
        if(editorGuard.current && !await editorGuard.current()) return;
        setLoading(true);
        setRows([]);
        setTab(key);
        setPage(1);
        setFilter('');
        setQuery('');
        setEditor(null);
        setNotice('');
      }}>{label}</Button>)}</div>}
      <Notice message={notice} error={noticeError} onClose={closeNotice}/>
      {editor && fullEditor(metadata[editor.resource],editor.row,editor.accountOnly) ? <Editor key={`${editor.resource}-${editor.row?.id || 'new'}`} resource={editor.resource} spec={metadata[editor.resource]} row={editor.row} accountOnly={editor.accountOnly} onSaved={saved} registerGuard={editorGuard} onClose={() => setEditor(null)} /> : loading ? <LoadingState/> : error ? <Feedback error={error} onRetry={() => setReload(n => n + 1)} /> : section === 'dashboard' ? <><div className="stats four">{[['siswa', 'Siswa'], ['guru', 'Guru'], ['orang_tua', 'Orang Tua'], ['kelas', 'Kelas']].map(([k, label]) => <Stat key={k} label={label} value={summary?.counts[k] ?? 0} detail="Data tersimpan" icon="users" />)}</div><Card title="Mulai mengelola data" subtitle={summary?.schoolYear ? `Tahun ajaran aktif ${summary.schoolYear.nama}` : 'Tahun ajaran aktif belum ditetapkan'}><div className="admin-shortcuts">{menu.slice(1).map(([key, label, icon]) => <Button key={key} onClick={() => switchSection(key)}><Icon name={icon} />{label}<span>→</span></Button>)}</div></Card><div className="portal-secondary-stats"><Card title="Kegiatan Ekstrakurikuler"><strong className="portal-total">{summary?.counts.ekskul ?? 0}</strong><p>Kegiatan tercatat</p></Card><Card title="Konfigurasi Badge"><strong className="portal-total">{summary?.counts.badge ?? 0}</strong><p>Badge terdaftar</p></Card></div></> : <Card title={isAccounts ? 'Daftar akun' : spec?.label} subtitle={`${meta.total} data tersimpan`}><div className="admin-toolbar"><input aria-label="Cari data" placeholder="Cari nama atau identitas…" value={query} onChange={e => {
        setQuery(e.target.value);
        setPage(1);
      }} />{filterOptions.length > 0 && <select aria-label="Filter data" value={filter} onChange={e => {
        setFilter(e.target.value);
        setPage(1);
      }}><option value="">Semua</option>{filterOptions.map(v => <option key={v} value={v}>{pretty(v)}</option>)}</select>}<Button onClick={() => setReload(n => n + 1)}>Muat ulang</Button></div><div className="table-scroll admin-table" tabIndex={0} role="region" aria-label="Daftar data Admin, geser untuk melihat kolom lainnya"><table><thead><tr><th>ID</th>{isAccounts ? <><th>Nama</th><th>Peran utama</th><th>Identitas login</th><th>Status</th></> : columns.map(f => <th key={f.name}>{f.label}</th>)}<th>Aksi</th></tr></thead><tbody>{rows.length === 0 ? <tr><td colSpan={isAccounts ? 6 : columns.length + 2}><EmptyState filtered={Boolean(query || filter)} onReset={() => {setQuery('');setFilter('');setPage(1);}}/></td></tr> : rows.map(row => <tr key={`${row.kind || resource}-${row.id}`}><td>#{row.id}</td>{isAccounts ? <><td>{row.nama}</td><td>{pretty(row.primary_role)}</td><td>{row.identitas_login}</td><td><StatusBadge value={row.status_akun}/></td></> : columns.map(f => <td key={f.name}>{f.ref ? row[f.name.slice(3)]?.nama || `${f.label} #${row[f.name]}` : f.name === 'aktif' ? <StatusBadge value={row[f.name] ? 'AKTIF' : 'NONAKTIF'}/> : f.name.includes('status') ? <StatusBadge value={row[f.name]}/> : pretty(row[f.name])}</td>)}<td><RowActions><Button onClick={() => setDetails({
        row,
        spec: isAccounts ? metadata[row.kind] : spec
      })}><Icon name="eye" size={15}/>Detail</Button>{!spec?.readOnly && <Button onClick={() => setEditor({
        row,
        resource: isAccounts ? row.kind : resource,
        accountOnly: isAccounts
      })}><Icon name="edit" size={15}/>Edit</Button>}{isAccounts && <Button onClick={() => {
        setReset(row);
        setPassword('');
        setActionError('');
      }}>Reset sandi</Button>}{!isAccounts && !spec?.readOnly && ['riwayat_kelas', 'wali', 'pembina'].includes(resource) && <Button onClick={() => {
        setReplacement(row);setReplacementDate('');setReplacementTarget('');setActionError('');
      }}>{resource === 'riwayat_kelas' ? 'Pindah kelas' : 'Ganti guru'}</Button>}{!isAccounts && !spec?.readOnly && temporal.includes(resource) && <Button disabled={actionBusy} onClick={() => end(row)}>Akhiri</Button>}{!isAccounts && !spec?.readOnly && <Button className="danger-text" disabled={actionBusy} onClick={() => remove(row)}><Icon name="trash" size={15}/>Hapus</Button>}</RowActions></td></tr>)}</tbody></table></div><div className="table-footer"><span>Halaman {page} dari {Math.max(1, meta.totalPages || 1)}</span><div><Button disabled={page === 1} onClick={() => setPage(n => n - 1)}>Sebelumnya</Button><Button disabled={page * 10 >= meta.total} onClick={() => setPage(n => n + 1)}>Berikutnya</Button></div></div></Card>}
      <footer>SIM Kesiswaan · Data Admin tersimpan di database · Waktu Indonesia Barat</footer></div>
    {editor && !fullEditor(metadata[editor.resource],editor.row,editor.accountOnly) && <Editor key={`${editor.resource}-${editor.row?.id || 'new'}`} resource={editor.resource} spec={metadata[editor.resource]} row={editor.row} accountOnly={editor.accountOnly} onSaved={saved} registerGuard={editorGuard} onClose={() => setEditor(null)}/>}
    {details && <Dialog drawer title={`Detail ${details.spec.label}`} onClose={closeDetails}><dl className="admin-details"><div><dt>ID</dt><dd>#{details.row.id}</dd></div>{details.spec.fields.map(f => <div key={f.name}><dt>{f.label}</dt><dd>{f.type === 'datetime' && details.row[f.name] ? dateTime(details.row[f.name]) : f.ref ? details.row[f.name.slice(3)]?.nama || pretty(details.row[f.name]) : pretty(details.row[f.name])}</dd></div>)}</dl></Dialog>}
    {replacement && <Dialog busy={actionBusy} title={resource === 'riwayat_kelas' ? 'Pindah kelas siswa' : 'Pergantian guru'} onClose={closeReplacement}><form onSubmit={replaceAssignment}><p>Masa lama akan diakhiri dan riwayat baru dibuat dalam satu transaksi.</p><RelationField field={{
      ref: resource === 'riwayat_kelas' ? 'kelas' : 'guru',
      lookupGroup: resource === 'riwayat_kelas' ? undefined : 'teachers',
      label: resource === 'riwayat_kelas' ? 'Kelas baru' : 'Guru pengganti',
      nullable: false
    }} value={replacementTarget} onChange={setReplacementTarget} /><label htmlFor="replacement-date">Tanggal mulai baru</label><input id="replacement-date" type="date" required value={replacementDate} onChange={e => setReplacementDate(e.target.value)} />{actionError && <p className="form-error" role="alert">{actionError}</p>}<div className="form-actions"><Button disabled={actionBusy} onClick={closeReplacement}>Batal</Button><Button className="primary" type="submit" disabled={actionBusy}>Simpan pergantian</Button></div></form></Dialog>}
    {reset && <Dialog busy={actionBusy} title={`Reset kata sandi — ${reset.nama}`} onClose={closeReset}><form onSubmit={resetPassword}><label htmlFor="reset-password">Kata sandi baru (10–128 karakter)</label><input id="reset-password" required minLength={10} maxLength={128} type="password" autoComplete="new-password" value={password} onChange={e => setPassword(e.target.value)} />{actionError && <p className="form-error" role="alert">{actionError}</p>}<div className="form-actions"><Button disabled={actionBusy} onClick={closeReset}>Batal</Button><Button type="submit" className="primary" disabled={actionBusy}>Reset kata sandi</Button></div></form></Dialog>}
    {panel && <Dialog title={panel} onClose={closePanel}>{panel === 'Profil' ? <><p><strong>{profile.name}</strong><br />Administrator<br />{profile.identitas_login}</p><Button onClick={requestLogout}>Keluar</Button></> : <p>Mulai dari Data Master, kemudian tahun ajaran, semester, kelas, hubungan keluarga, dan penugasan. Data yang sudah berlaku diakhiri masa berlakunya agar riwayat tetap tersimpan. Konfigurasi badge tidak memberikan badge secara manual.</p>}</Dialog>}
  </PortalShell>;
}

export default function AdminPage(props) { return <ManagementProvider><AdminWorkspace {...props}/></ManagementProvider>; }
