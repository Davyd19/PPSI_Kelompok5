import { useCallback, useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { apiRequest } from '../../api/client';
import Button from '../../components/Button';
import Icon from '../../components/Icon';
import { Card, Dialog, Feedback, Identity, Stat } from '../../components/Ui';
import '../../styles/admin.css';
const sections = {
  master: {
    title: 'Data Master',
    description: 'Kelola identitas dan akun warga sekolah.',
    tabs: [['siswa', 'Siswa'], ['guru', 'Guru'], ['orang_tua', 'Orang Tua']]
  },
  peran: {
    title: 'Peran Guru',
    description: 'Guru memiliki akses dasar. Peran tambahan mengikuti masa berlaku.',
    tabs: [['guru_peran', 'Penetapan Peran'], ['peran', 'Daftar Peran Sistem']]
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
    description: 'Atur badge otomatis dan satu syarat per level. Perhitungan otomatis dikembangkan pada tahap berikutnya.',
    tabs: [['badge', 'Badge'], ['versi_badge', 'Versi Aturan'], ['level', 'Level & Syarat']]
  },
  penugasan: {
    title: 'Penugasan',
    description: 'Kelola penugasan guru serta data dasar kegiatan ekstrakurikuler.',
    tabs: [['wali', 'Wali Kelas'], ['pembina', 'Pembina Ekskul'], ['ekskul', 'Ekstrakurikuler'], ['periode_ekskul', 'Periode Ekskul']]
  }
};
const menu = [['dashboard', 'Beranda', 'dashboard'], ['master', 'Data Master', 'users'], ['akun', 'Akun Pengguna', 'user'], ['peran', 'Peran Guru', 'shield'], ['hubungan', 'Orang Tua–Anak', 'users'], ['akademik', 'Kelas & Tahun Ajaran', 'calendar'], ['badge', 'Konfigurasi Badge', 'badge'], ['penugasan', 'Penugasan', 'file']];
const pretty = v => v == null || v === '' ? '—' : typeof v === 'boolean' ? v ? 'Ya' : 'Tidak' : String(v).replaceAll('_', ' ');
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
      apiRequest(`/admin/lookups/${field.ref}?q=${encodeURIComponent(search)}&page=${page}&limit=20`, {
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
  }, [field.ref, search, page]);
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
    }).catch(() => {});
    return () => {
      active = false;
    };
  }, [value, field.ref]);
  const choices = selected && !rows.some(r => String(r.id) === String(selected.id)) ? [selected, ...rows] : rows;
  return <div className="relation-input"><input aria-label={`Cari ${field.label}`} placeholder="Cari pilihan…" value={search} onChange={e => {
      setSearch(e.target.value);
      setPage(1);
    }} /><select aria-label={field.label} value={value ?? ''} onChange={e => onChange(e.target.value)}><option value="">{field.nullable ? 'Tidak dipilih' : 'Pilih data'}</option>{choices.map(r => <option key={r.id} value={r.id}>{r.label} · #{r.id}</option>)}</select><div className="lookup-pager"><Button disabled={page === 1} onClick={() => setPage(p => p - 1)}>Sebelumnya</Button><small>{page} · {total} pilihan</small><Button disabled={page * 20 >= total} onClick={() => setPage(p => p + 1)}>Berikutnya</Button></div>{error && <small role="alert">{error}</small>}</div>;
}
function Editor({
  spec,
  row,
  accountOnly,
  resource,
  onSaved,
  onClose
}) {
  const fields = accountOnly ? spec.fields.filter(f => ['identitas_login', 'status_akun'].includes(f.name)) : spec.fields;
  const [values, setValues] = useState(() => Object.fromEntries(fields.map(f => [f.name, f.type === 'datetime' ? dateInput(row?.[f.name]) : row?.[f.name] ?? (f.type === 'boolean' ? false : '')]))),
    [password, setPassword] = useState(''),
    [error, setError] = useState(''),
    [errors, setErrors] = useState({}),
    [busy, setBusy] = useState(false);
  const full = fields.length > 7;
  const close = () => {
    if (busy) return;
    if (Object.values(values).some(v => v !== '' && v !== false) && !window.confirm('Tutup formulir? Perubahan yang belum disimpan akan hilang.')) return;
    onClose();
  };
  async function submit(e) {
    e.preventDefault();
    setBusy(true);
    setError('');
    setErrors({});
    try {
      const body = {};
      for (const f of fields) {
        let v = values[f.name];
        if (v === '' || v == null) v = null;else if (f.type === 'datetime') v = new Date(`${v}:00+07:00`).toISOString();else if (f.type === 'id' || f.type === 'integer') v = Number(v);
        body[f.name] = v;
      }
      if (!row && ['guru', 'siswa', 'orang_tua'].includes(resource)) body.kata_sandi = password;
      if (row && ['versi_badge', 'level', ...temporal].includes(resource)) for (const k of Object.keys(body)) if (String(body[k] ?? '') === String(row[k] ?? '')) delete body[k];
      if (row && Object.keys(body).length === 0) {
        onClose();
        return;
      }
      if (resource === 'tahun' && body.aktif === true && (!row || row.aktif !== true) && !window.confirm('Jadikan tahun ajaran ini aktif? Tahun ajaran aktif sebelumnya akan dinonaktifkan.')) return;
      if (row && ['status_akun', 'status', 'status_kegiatan', 'aktif'].some(k => k in body && body[k] !== row[k]) && !window.confirm('Konfirmasi perubahan status data ini? Akses dan penggunaan mengikuti status terbaru.')) return;
      await apiRequest(`/admin/${resource}${row ? `/${row.id}` : ''}`, {
        method: row ? 'PATCH' : 'POST',
        body
      });
      onSaved(row ? 'Perubahan berhasil disimpan.' : 'Data berhasil ditambahkan.');
    } catch (e) {
      setError(e.message);
      setErrors(e.details || {});
    } finally {
      setBusy(false);
    }
  }
  const content = <form onSubmit={submit} noValidate><p className="muted">{row ? `Mengubah data #${row.id}.` : 'Lengkapi informasi berikut.'} Tanda * wajib diisi. Waktu menggunakan WIB.</p><div className="admin-form-grid">{fields.map(f => <div className={`admin-field ${f.type === 'text' ? 'span-full' : ''}`} key={f.name}><label htmlFor={`field-${f.name}`}>{f.label}{!f.nullable ? ' *' : ''}</label>{f.ref ? <RelationField field={f} value={values[f.name]} onChange={v => setValues(s => ({
          ...s,
          [f.name]: v
        }))} /> : f.options ? <select id={`field-${f.name}`} value={values[f.name]} onChange={e => setValues(s => ({
          ...s,
          [f.name]: e.target.value
        }))}><option value="">{f.nullable ? 'Tidak dipilih' : 'Pilih'}</option>{f.options.map(v => <option key={v} value={v}>{pretty(v)}</option>)}</select> : f.type === 'boolean' ? <select id={`field-${f.name}`} value={String(values[f.name])} onChange={e => setValues(s => ({
          ...s,
          [f.name]: e.target.value === 'true'
        }))}><option value="true">Ya</option><option value="false">Tidak</option></select> : f.type === 'text' ? <textarea id={`field-${f.name}`} value={values[f.name]} rows={4} onChange={e => setValues(s => ({
          ...s,
          [f.name]: e.target.value
        }))} /> : <input id={`field-${f.name}`} type={f.type === 'date' ? 'date' : f.type === 'datetime' ? 'datetime-local' : f.type === 'integer' ? 'number' : f.name === 'email' ? 'email' : 'text'} value={values[f.name]} onChange={e => setValues(s => ({
          ...s,
          [f.name]: e.target.value
        }))} />} {errors[f.name] && <small className="form-error">{errors[f.name]}</small>}</div>)}{!row && ['guru', 'siswa', 'orang_tua'].includes(resource) && <div className="admin-field"><label htmlFor="initial-password">Kata sandi awal *</label><input id="initial-password" autoComplete="new-password" type="password" value={password} onChange={e => setPassword(e.target.value)} /><small>10–128 karakter. Sampaikan kepada pemilik akun secara pribadi.</small></div>}</div>{error && <p role="alert" className="form-error">{error}</p>}<div className="form-actions"><Button disabled={busy} onClick={close}>Batal</Button><Button className="primary" type="submit" disabled={busy}>{busy ? 'Menyimpan…' : 'Simpan'}</Button></div></form>;
  if (full) return <section className="card admin-editor-page"><div className="card-heading"><h2>{row ? 'Ubah' : 'Tambah'} {spec.label}</h2><Button disabled={busy} onClick={close}>Kembali ke daftar</Button></div>{content}</section>;
  return <Dialog title={`${row ? 'Ubah' : 'Tambah'} ${spec.label}`} onClose={close}>{content}</Dialog>;
}
export default function AdminPage({
  profile,
  onLogout
}) {
  const {
      section = 'dashboard'
    } = useParams(),
    navigate = useNavigate();
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
    [drawer, setDrawer] = useState(false),
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
        if (section === 'dashboard') setSummary(p.data);else {
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
  function switchSection(key) {
    setLoading(true);
    setRows([]);
    setDrawer(false);
    setTab(null);
    setEditor(null);
    setPage(1);
    setQuery('');
    setFilter('');
    setNotice('');
    navigate(`/admin/${key}`);
  }
  function saved(message) {
    setEditor(null);
    setReset(null);
    setPassword('');
    setNotice(message);
    setReload(n => n + 1);
  }
  async function remove(row) {
    if (!window.confirm('Hapus permanen data ini? Hanya data yang belum digunakan yang dapat dihapus.')) return;
    setActionBusy(true);
    try {
      await apiRequest(`/admin/${resource}/${row.id}`, {
        method: 'DELETE'
      });
      if (rows.length === 1 && page > 1) setPage(n => n - 1);
      saved('Data berhasil dihapus.');
    } catch (e) {
      setNotice(e.message);
    } finally {
      setActionBusy(false);
    }
  }
  async function end(row) {
    const date = window.prompt('Tanggal akhir masa berlaku (YYYY-MM-DD), inklusif:', '');
    if (date === null) return;
    if (!date || !window.confirm(`Akhiri masa berlaku pada ${date}? Akses mengikuti masa berlaku tersebut.`)) return;
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
      setNotice(e.message);
    } finally {
      setActionBusy(false);
    }
  }
  async function resetPassword(e) {
    e.preventDefault();
    if (!window.confirm('Reset kata sandi akun ini? Sesi sebelumnya akan tidak berlaku.')) return;
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
      setActionBusy(false);
    }
  }
  async function replaceAssignment(e) {
    e.preventDefault();
    if (!window.confirm('Simpan pergantian? Masa lama berakhir sehari sebelum tanggal mulai yang baru.')) return;
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
      setActionBusy(false);
    }
  }
  const columns = spec ? spec.fields.filter(f => !['text', 'datetime'].includes(f.type)).slice(0, 5) : [];
  const filterOptions = isAccounts ? ['guru', 'siswa', 'orang_tua'] : spec?.fields.find(f => ['status_akun', 'status', 'tingkat'].includes(f.name))?.options || [];
  const title = config?.title || 'Dashboard Admin';
  return <div className="workspace role-admin admin-workspace"><aside className={`sidebar ${drawer ? 'drawer-open' : ''}`}><Identity /><div className="sidebar-profile"><strong>{profile.name}</strong><small>Administrator</small></div><small className="nav-caption">MANAJEMEN SEKOLAH</small><nav aria-label="Menu Admin">{menu.map(([key, label, icon]) => <Button key={key} className={`nav-item ${section === key ? 'active' : ''}`} onClick={() => switchSection(key)}><Icon name={icon} /><span>{label}</span></Button>)}</nav><div className="sidebar-bottom"><Button className="nav-item" onClick={() => setPanel('Panduan')}><Icon name="help" />Panduan</Button><Button className="nav-item" onClick={onLogout}><Icon name="logout" />Keluar</Button></div></aside>{drawer && <button className="drawer-scrim" aria-label="Tutup menu" onClick={() => setDrawer(false)} />}
 <div className="workspace-body"><header className="topbar"><div><Button className="drawer-toggle" onClick={() => setDrawer(v => !v)} aria-label="Buka menu">☰</Button><span className="tag green">SMAN 12 Padang</span><span className="tag">Administrator</span></div><Button className="avatar-button" aria-label="Profil" onClick={() => setPanel('Profil')}><Icon name="user" /></Button></header><main className="dashboard-main"><div className="page-heading"><div><span className="eyebrow">PORTAL ADMINISTRASI</span><h1>{title}</h1><p>{config?.description || 'Ringkasan data sekolah yang tersimpan di database.'}</p></div>{config && !isAccounts && !spec?.readOnly && <Button className="primary" disabled={!spec} onClick={() => {
            setEditor({
              row: null,
              resource
            });
            setNotice('');
          }}>+ Tambah {spec?.label}</Button>}</div>
 {config && <div className="admin-tabs" role="tablist">{config.tabs.map(([key, label]) => <Button role="tab" aria-selected={resource === key} key={key} className={resource === key ? 'selected' : ''} onClick={() => {
            setLoading(true);
            setRows([]);
            setTab(key);
            setPage(1);
            setFilter('');
            setQuery('');
            setEditor(null);
            setNotice('');
          }}>{label}</Button>)}</div>}
 {notice && <div className="admin-notice" role="status">{notice}<Button aria-label="Tutup pesan" onClick={() => setNotice('')}>×</Button></div>}
 {editor ? <Editor key={`${editor.resource}-${editor.row?.id || 'new'}`} resource={editor.resource} spec={metadata[editor.resource]} row={editor.row} accountOnly={editor.accountOnly} onSaved={saved} onClose={() => setEditor(null)} /> : loading || error ? <Feedback loading={loading} error={error} onRetry={() => setReload(n => n + 1)} /> : section === 'dashboard' ? <><div className="stats four">{[['siswa', 'Siswa'], ['guru', 'Guru'], ['orang_tua', 'Orang Tua'], ['kelas', 'Kelas']].map(([k, label]) => <Stat key={k} label={label} value={summary?.counts[k] ?? 0} detail="Data tersimpan" icon="users" />)}</div><Card title="Mulai mengelola data" subtitle={summary?.schoolYear ? `Tahun ajaran aktif ${summary.schoolYear.nama}` : 'Tahun ajaran aktif belum ditetapkan'}><div className="admin-shortcuts">{menu.slice(1).map(([key, label, icon]) => <Button key={key} onClick={() => switchSection(key)}><Icon name={icon} />{label}<span>→</span></Button>)}</div></Card><Card title="Data operasional"><p>Presensi, penanganan siswa, dan perhitungan badge otomatis dikembangkan melalui modul terkait. Grafik operasional belum tersedia.</p></Card></> : <Card title={isAccounts ? 'Daftar akun' : spec?.label} subtitle={`${meta.total} data tersimpan`}><div className="admin-toolbar"><input aria-label="Cari data" placeholder="Cari nama atau identitas…" value={query} onChange={e => {
              setQuery(e.target.value);
              setPage(1);
            }} />{filterOptions.length > 0 && <select aria-label="Filter data" value={filter} onChange={e => {
              setFilter(e.target.value);
              setPage(1);
            }}><option value="">Semua</option>{filterOptions.map(v => <option key={v} value={v}>{pretty(v)}</option>)}</select>}<Button onClick={() => setReload(n => n + 1)}>Muat ulang</Button></div><div className="table-scroll admin-table"><table><thead><tr><th>ID</th>{isAccounts ? <><th>Nama</th><th>Jenis</th><th>Identitas login</th><th>Status</th></> : columns.map(f => <th key={f.name}>{f.label}</th>)}<th>Aksi</th></tr></thead><tbody>{rows.length === 0 ? <tr><td colSpan={isAccounts ? 6 : columns.length + 2}><div className="admin-empty"><Icon name="file" /><strong>Belum ada data</strong><p>{query || filter ? 'Ubah pencarian atau filter untuk melihat hasil lainnya.' : 'Tambahkan data melalui tombol di atas.'}</p></div></td></tr> : rows.map(row => <tr key={`${row.kind || resource}-${row.id}`}><td>#{row.id}</td>{isAccounts ? <><td>{row.nama}</td><td>{pretty(row.kind)}</td><td>{row.identitas_login}</td><td><span className={`admin-status ${row.status_akun === 'AKTIF' ? 'positive' : ''}`}>{row.status_akun}</span></td></> : columns.map(f => <td key={f.name}>{f.ref ? row[f.name.slice(3)]?.nama || `${f.label} #${row[f.name]}` : f.name.includes('status') ? <span className={`admin-status ${row[f.name] === 'AKTIF' ? 'positive' : ''}`}>{pretty(row[f.name])}</span> : pretty(row[f.name])}</td>)}<td><div className="row-actions"><Button onClick={() => setDetails({
                        row,
                        spec: isAccounts ? metadata[row.kind] : spec
                      })}>Detail</Button>{!spec?.readOnly && <Button onClick={() => setEditor({
                        row,
                        resource: isAccounts ? row.kind : resource,
                        accountOnly: isAccounts
                      })}>Ubah</Button>}{isAccounts ? <Button onClick={() => {
                        setReset(row);
                        setPassword('');
                        setActionError('');
                      }}>Reset sandi</Button> : !spec?.readOnly && <>{['riwayat_kelas', 'wali', 'pembina'].includes(resource) && <Button onClick={() => {
                          setReplacement(row);
                          setReplacementDate('');
                          setReplacementTarget('');
                          setActionError('');
                        }}>{resource === 'riwayat_kelas' ? 'Pindah kelas' : 'Ganti guru'}</Button>}{temporal.includes(resource) && <Button disabled={actionBusy} onClick={() => end(row)}>Akhiri</Button>}<Button className="danger-text" disabled={actionBusy} onClick={() => remove(row)}>Hapus</Button></>}</div></td></tr>)}</tbody></table></div><div className="table-footer"><span>Halaman {page} dari {Math.max(1, meta.totalPages || 1)}</span><div><Button disabled={page === 1} onClick={() => setPage(n => n - 1)}>Sebelumnya</Button><Button disabled={page * 10 >= meta.total} onClick={() => setPage(n => n + 1)}>Berikutnya</Button></div></div></Card>}
 <footer>SIM Kesiswaan · Data Admin tersimpan di database · Waktu Indonesia Barat</footer></main></div>
 {details && <Dialog title={`Detail ${details.spec.label}`} onClose={closeDetails}><dl className="admin-details"><dt>ID</dt><dd>#{details.row.id}</dd>{details.spec.fields.map(f => <div key={f.name}><dt>{f.label}</dt><dd>{f.type === 'datetime' && details.row[f.name] ? dateTime(details.row[f.name]) : f.ref ? details.row[f.name.slice(3)]?.nama || pretty(details.row[f.name]) : pretty(details.row[f.name])}</dd></div>)}</dl></Dialog>}
 {replacement && <Dialog title={resource === 'riwayat_kelas' ? 'Pindah kelas siswa' : 'Pergantian guru'} onClose={() => {
      if (!actionBusy) setReplacement(null);
    }}><form onSubmit={replaceAssignment}><p>Masa lama akan diakhiri dan riwayat baru dibuat dalam satu transaksi.</p><RelationField field={{
          ref: resource === 'riwayat_kelas' ? 'kelas' : 'guru',
          label: resource === 'riwayat_kelas' ? 'Kelas baru' : 'Guru pengganti',
          nullable: false
        }} value={replacementTarget} onChange={setReplacementTarget} /><label htmlFor="replacement-date">Tanggal mulai baru</label><input id="replacement-date" type="date" value={replacementDate} onChange={e => setReplacementDate(e.target.value)} />{actionError && <p className="form-error" role="alert">{actionError}</p>}<div className="form-actions"><Button disabled={actionBusy} onClick={() => setReplacement(null)}>Batal</Button><Button className="primary" type="submit" disabled={actionBusy}>Simpan pergantian</Button></div></form></Dialog>}
 {reset && <Dialog title={`Reset kata sandi — ${reset.nama}`} onClose={() => {
      if (!actionBusy) {
        setReset(null);
        setPassword('');
      }
    }}><form onSubmit={resetPassword}><label htmlFor="reset-password">Kata sandi baru (10–128 karakter)</label><input id="reset-password" type="password" autoComplete="new-password" value={password} onChange={e => setPassword(e.target.value)} />{actionError && <p className="form-error" role="alert">{actionError}</p>}<div className="form-actions"><Button disabled={actionBusy} onClick={() => {
            setReset(null);
            setPassword('');
          }}>Batal</Button><Button type="submit" className="primary" disabled={actionBusy}>Reset kata sandi</Button></div></form></Dialog>}
 {panel && <Dialog title={panel} onClose={closePanel}>{panel === 'Profil' ? <><p><strong>{profile.name}</strong><br />Administrator<br />{profile.identitas_login}</p><Button onClick={onLogout}>Keluar</Button></> : <p>Mulai dari Data Master, kemudian tahun ajaran, semester, kelas, hubungan keluarga, dan penugasan. Data yang sudah berlaku diakhiri masa berlakunya agar riwayat tetap tersimpan. Konfigurasi badge tidak memberikan badge secara manual.</p>}</Dialog>}
 </div>;
}
