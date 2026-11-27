import { useCallback, useEffect, useRef, useState } from 'react';
import { useConfirm } from '../../hooks/useConfirm';
import { apiRequest } from '../../api/client';
import Button from '../../components/Button';
import Icon from '../../components/Icon';
import { badgeIconCodes } from '../../utils/badge-icons';
import { Modal as Dialog } from '../../components/ManagementUi';
import { sameValues } from '../../utils/management';
const pretty = v => v == null || v === '' ? '—' : typeof v === 'boolean' ? v ? 'Ya' : 'Tidak' : (/^[A-Z][A-Z_]*$/.test(String(v)) ? String(v).toLowerCase().replace(/^./, c => c.toUpperCase()) : String(v)).replaceAll('_', ' ');
const temporal = ['guru_peran', 'hubungan', 'riwayat_kelas', 'wali', 'pembina'];
function dateInput(v) {
  if (!v) return '';
  const d = new Date(v);
  return new Date(d.getTime() + 7 * 3600000).toISOString().slice(0, 16);
}
export function RelationField({
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
    }).catch(() => {});
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
function fullEditor(spec, row, accountOnly) {
  if (accountOnly) return false;
  return spec.fields.length + (!row && ['Guru', 'Siswa', 'OrangTua'].includes(spec.name) ? 1 : 0) > 7;
}
export function Editor({
  spec,
  catalog,
  preset = {},
  row,
  accountOnly,
  resource,
  onSaved,
  registerGuard,
  onClose
}) {
  const fields = accountOnly ? spec.fields.filter(f => ['identitas_login', 'status_akun', 'id_peran_utama'].includes(f.name)) : spec.fields;
  const [values, setValues] = useState(() => Object.fromEntries(fields.map(f => [f.name, f.type === 'datetime' ? dateInput(row?.[f.name]) : row?.[f.name] ?? preset[f.name] ?? (f.type === 'boolean' ? false : '')]))),
    [password, setPassword] = useState(''),
    [error, setError] = useState(''),
    [errors, setErrors] = useState({}),
    [busy, setBusy] = useState(false);
  const confirm = useConfirm();
  const submitLock = useRef(false);
  const [initialValues] = useState(() => ({
    ...values
  }));
  const full = fullEditor(spec, row, accountOnly);
  const groupOf = field => ['identitas_login', 'status_akun', 'id_peran_utama'].includes(field.name) ? 'Akun dan Akses' : ['email', 'telepon'].includes(field.name) ? 'Informasi Kontak' : field.ref ? 'Keterkaitan Data' : ['date', 'datetime'].includes(field.type) ? 'Periode dan Masa Berlaku' : 'Informasi Utama';
  const fieldGroups = full ? ['Informasi Utama', 'Akun dan Akses', 'Informasi Kontak', 'Keterkaitan Data', 'Periode dan Masa Berlaku'].map(name => [name, fields.filter(field => groupOf(field) === name)]).filter(([, items]) => items.length) : [['Informasi', fields]];
  const dirty = !sameValues(initialValues, values) || password !== '';
  const mayLeave = useCallback(async () => {
    if (busy) return false;
    if (dirty && !(await confirm({
      title: 'Buang perubahan?',
      message: 'Perubahan pada formulir ini belum disimpan.',
      accept: 'Buang Perubahan',
      danger: true
    }))) return false;
    return true;
  }, [busy, dirty, confirm]);
  useEffect(() => {
    registerGuard.current = mayLeave;
    return () => {
      registerGuard.current = null;
    };
  }, [registerGuard, mayLeave]);
  const close = async () => {
    if (await mayLeave()) onClose();
  };
  function updateOption(field, value) {
    setValues(previous => {
      const next = {
        ...previous,
        [field]: value
      };
      if (resource === 'level' && field === 'sumber_data') {
        next.cara_hitung = catalog.sources.find(s => s.code === value).methods[0];
        next.jenis_presensi = value === 'PRESENSI_SEKOLAH' ? 'PAGI' : null;
        next.status_kehadiran_yang_dihitung = value.startsWith('PRESENSI_') ? 'HADIR' : null;
        next.id_ekstrakurikuler = null;
      }
      if (field === 'cara_hitung' && value === 'PERSENTASE') next.cakupan_perhitungan = 'SEMESTER';
      return next;
    });
  }
  async function submit(e) {
    e.preventDefault();
    if (submitLock.current) return;
    submitLock.current = true;
    setBusy(true);
    setError('');
    setErrors({});
    try {
      const body = {};
      for (const f of fields) {
        let v = values[f.name];
        if (resource === 'level' && (f.name === 'jenis_presensi' && values.sumber_data !== 'PRESENSI_SEKOLAH' || f.name === 'status_kehadiran_yang_dihitung' && !String(values.sumber_data).startsWith('PRESENSI_') || f.name === 'id_ekstrakurikuler' && ['PRESENSI_SEKOLAH', 'PELANGGARAN'].includes(values.sumber_data))) v = null;
        if (v === '' || v == null) v = null;else if (f.type === 'datetime') v = new Date(`${v}:00+07:00`).toISOString();else if (f.type === 'id' || f.type === 'integer') v = Number(v);
        body[f.name] = v;
      }
      if (!row && ['guru', 'siswa', 'orang_tua'].includes(resource)) body.kata_sandi = password;
      if (row && ['versi_badge', 'level', ...temporal].includes(resource)) for (const k of Object.keys(body)) if (String(body[k] ?? '') === String(row[k] ?? '')) delete body[k];
      const impacts = [];
      if (resource === 'guru' && row && Number(body.id_peran_utama) !== Number(row.id_peran_utama)) {
        impacts.push('Peran utama berubah dan seluruh sesi akun dicabut. Tugas Guru yang masih aktif harus diakhiri dahulu.');
      }
      if (row && Object.keys(body).length === 0) {
        onClose();
        return;
      }
      if (resource === 'tahun' && body.aktif === true && (!row || row.aktif !== true)) impacts.push('Tahun ajaran ini menjadi aktif dan tahun ajaran sebelumnya dinonaktifkan.');
      if (row && ['status_akun', 'status', 'status_kegiatan', 'aktif'].some(k => k in body && body[k] !== row[k])) impacts.push('Status data berubah. Akses dan penggunaan mengikuti status terbaru.');
      if (impacts.length && !(await confirm({
        title: 'Simpan perubahan penting?',
        message: 'Periksa dampak perubahan sebelum melanjutkan.',
        subject: values.nama || row?.nama || spec.label,
        details: impacts,
        accept: 'Simpan Perubahan'
      }))) return;
      await apiRequest(`/admin/${resource}${row ? `/${row.id}` : ''}`, {
        method: row ? 'PATCH' : 'POST',
        body
      });
      onSaved(row ? 'Perubahan berhasil disimpan.' : 'Data berhasil ditambahkan.');
    } catch (e) {
      setError(e.message);
      setErrors(e.details || {});
    } finally {
      submitLock.current = false;
      setBusy(false);
    }
  }
  const content = <form onSubmit={submit} noValidate aria-busy={busy}><fieldset className="mg-form-fields" disabled={busy}><p className="muted">{row ? `Mengubah data #${row.id}.` : 'Lengkapi informasi berikut.'} Tanda * wajib diisi. Waktu menggunakan WIB.</p><div className="mg-form-sections">{fieldGroups.map(([groupTitle, groupFields]) => <section className="mg-form-section" key={groupTitle}>{full && <h3>{groupTitle}</h3>}<div className="admin-form-grid">{groupFields.filter(f => resource !== 'level' || (f.name !== 'jenis_presensi' || values.sumber_data === 'PRESENSI_SEKOLAH') && (f.name !== 'status_kehadiran_yang_dihitung' || String(values.sumber_data).startsWith('PRESENSI_')) && (f.name !== 'id_ekstrakurikuler' || !['PRESENSI_SEKOLAH', 'PELANGGARAN'].includes(values.sumber_data))).map(f => <div className={`admin-field ${f.type === 'text' ? 'span-full' : ''}`} key={f.name} data-invalid={Boolean(errors[f.name])}><label htmlFor={`field-${f.name}`}>{f.label}{!f.nullable ? ' *' : ''}</label>{f.name === 'ikon' ? <div className="admin-icon-picker">{badgeIconCodes.map(code => <button key={code} type="button" className={values.ikon === code ? 'selected' : ''} aria-label={'Ikon ' + code} aria-pressed={values.ikon === code} onClick={() => setValues(v => ({
                  ...v,
                  ikon: code
                }))}><Icon name={code} size={24} /><small>{code}</small></button>)}</div> : f.ref ? <fieldset className="admin-pinned-field" disabled={Object.hasOwn(preset, f.name)}><RelationField field={{
                  ...f,
                  lookupGroup: f.ref === 'guru' ? 'teachers' : undefined
                }} value={values[f.name] ?? ''} onChange={v => setValues(s => ({
                  ...s,
                  [f.name]: v
                }))} /></fieldset> : f.options ? <select id={`field-${f.name}`} value={values[f.name] ?? ''} onChange={e => updateOption(f.name, e.target.value)}><option value="">{f.nullable ? 'Tidak dipilih' : 'Pilih'}</option>{f.options.filter(v => (f.name !== 'status_kehadiran_yang_dihitung' || v !== 'TERLAMBAT' || values[f.name] === v) && (resource !== 'level' || f.name !== 'cara_hitung' || catalog.sources.find(s => s.code === values.sumber_data)?.methods.includes(v)) && (f.name !== 'cakupan_perhitungan' || values.cara_hitung !== 'PERSENTASE' || v === 'SEMESTER')).map(v => <option key={v} value={v}>{pretty(v)}</option>)}</select> : f.type === 'boolean' ? <select id={`field-${f.name}`} value={String(values[f.name])} onChange={e => setValues(s => ({
                ...s,
                [f.name]: e.target.value === 'true'
              }))}><option value="true">Ya</option><option value="false">Tidak</option></select> : f.type === 'text' ? <textarea id={`field-${f.name}`} value={values[f.name]} rows={4} onChange={e => setValues(s => ({
                ...s,
                [f.name]: e.target.value
              }))} /> : <input id={`field-${f.name}`} type={f.type === 'date' ? 'date' : f.type === 'datetime' ? 'datetime-local' : f.type === 'integer' ? 'number' : f.name === 'email' ? 'email' : 'text'} value={values[f.name] ?? ''} onChange={e => setValues(s => ({
                ...s,
                [f.name]: e.target.value
              }))} />} {errors[f.name] && <small className="form-error">{errors[f.name]}</small>}</div>)}</div></section>)}{!row && ['guru', 'siswa', 'orang_tua'].includes(resource) && <div className="admin-field"><label htmlFor="initial-password">Kata sandi awal *</label><input id="initial-password" autoComplete="new-password" type="password" value={password} onChange={e => setPassword(e.target.value)} /><small>10–128 karakter. Sampaikan kepada pemilik akun secara pribadi.</small></div>}</div></fieldset>{error && <p role="alert" className="form-error">{error}</p>}<div className="form-actions"><Button disabled={busy} onClick={close}>Batal</Button><Button className="primary" type="submit" disabled={busy}>{busy ? 'Menyimpan…' : 'Simpan'}</Button></div></form>;
  if (full) return <section className="card admin-editor-page"><div className="card-heading"><h2>{row ? 'Ubah' : 'Tambah'} {spec.label}</h2><Button disabled={busy} onClick={close}>Kembali ke daftar</Button></div>{content}</section>;
  return <Dialog title={`${row ? 'Ubah' : 'Tambah'} ${spec.label}`} busy={busy} onClose={close}>{content}</Dialog>;
}
