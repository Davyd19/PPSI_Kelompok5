import { Children,cloneElement,isValidElement,Fragment,createContext, useCallback, useContext, useEffect, useRef, useState } from 'react';
import { apiRequest } from '../../api/client';
import Icon from '../../components/Icon';
import { Modal, EmptyState, RowActions } from '../../components/ManagementUi';
import { useConfirm } from '../../hooks/useConfirm';
import { formSnapshot } from '../../utils/management';
const base = '/kesiswaan';
const label = value => String(value ?? '—').replaceAll('_', ' ');
const FieldErrors = createContext({});
function Field({
  name,
  title,
  children,
  type = 'text',
  ...props
}) {
  const errors = useContext(FieldErrors);
  const error = errors[name || children?.props?.name];
  const required = props.required || children?.props?.required;
  return <label className="ks-field" data-invalid={Boolean(error)}><span>{title}{required && <span className="mg-required"> *</span>}</span>{children || (type==='search'?<span className="ks-search-control"><Icon name="search" size={17}/><input name={name} type={type} aria-invalid={Boolean(error)} {...props}/></span>:<input name={name} type={type} aria-invalid={Boolean(error)} {...props}/>)}{error && <small role="alert" className="mg-field-error">{error}</small>}</label>;
}
function Area({
  name,
  title,
  required = false,
  defaultValue = ''
}) {
  return <Field title={title}><textarea name={name} required={required} defaultValue={defaultValue} rows={3} /></Field>;
}
function Rows({
  headers,
  items,
  render,
  filtered = false,
  onReset,
  onOpen
}) {
  function renderCells(row){
    const result=render(row);
    if(headers.at(-1)!=='Aksi')return result;
    const cells=Children.toArray(isValidElement(result)&&result.type===Fragment?result.props.children:result);
    const last=cells.at(-1);if(!isValidElement(last))return result;
    const children=Children.toArray(last.props.children);
    if(children.length===1&&isValidElement(children[0])&&children[0].type===RowActions)return result;
    cells[cells.length-1]=cloneElement(last,{children:<RowActions>{last.props.children}</RowActions>});
    return cells;
  }
  return items.length ? <div className="ks-table-scroll" tabIndex={0} role="region" aria-label="Tabel hasil"><table><thead><tr>{headers.map(h => <th key={h}>{h}</th>)}</tr></thead>
    <tbody>{items.map((row, i) => <tr onDoubleClick={event=>{if(!event.target.closest('button,a,input,select,summary'))onOpen?.(row);}} key={row.id ?? `${row.id_sesi}-${row.id_siswa}-${i}`}>{renderCells(row)}</tr>)}</tbody></table></div> : <EmptyState filtered={filtered} onReset={onReset} />;
}
function Students({
  multiple = false,
  initial = []
}) {
  const [query, setQuery] = useState('');
  const [results, setResults] = useState([]);
  const [selected, setSelected] = useState(initial);
  const [error, setError] = useState('');
  useEffect(() => {
    const controller = new AbortController();
    const timer = setTimeout(() => {
      setError('');
      apiRequest(`${base}/lookups?q=${encodeURIComponent(query)}`, {
        signal: controller.signal
      }).then(({
        data
      }) => setResults(data.students)).catch(e => {
        if (e.name !== 'AbortError') setError(e.message);
      });
    }, 200);
    return () => {
      clearTimeout(timer);
      controller.abort();
    };
  }, [query]);
  return <fieldset className="ks-students"><legend>{multiple ? 'Peserta' : 'Siswa'}</legend>
    <input aria-label="Cari siswa" placeholder="Cari nama atau NISN" value={query} onChange={e => setQuery(e.target.value)} />
    <select aria-label="Pilih siswa" value="" onChange={e => {
      const item = results.find(r => String(r.id) === e.target.value);
      if (item) setSelected(s => multiple ? [...s.filter(r => r.id !== item.id), item] : [item]);
    }}><option value="">Pilih siswa</option>{results.map(s => <option key={s.id} value={s.id}>{s.nama} · {s.nisn}</option>)}</select>
    {selected.map(s => <div key={s.id} className="ks-selected">{s.nama}
      <input type="hidden" name={multiple ? 'peserta' : 'id_siswa'} value={s.id} />
      <button type="button" onClick={() => setSelected(items => items.filter(i => i.id !== s.id))} aria-label={`Hapus ${s.nama}`}>×</button></div>)}
    {error && <p role="alert">{error}</p>}
  </fieldset>;
}
function WorkForm({
  title,
  close,
  save,
  children,
  readOnly,
  fullPage,
  action,
  initialFile,
  kind,
  registerGuard
}) {
  const [error, setError] = useState('');
  const [fieldErrors, setFieldErrors] = useState({});
  const [saving, setSaving] = useState(false);
  const lock = useRef(false);
  const formRef = useRef(null);
  const initial = useRef(null);
  const heading = useRef(null);
  const confirm = useConfirm();
  useEffect(() => {
    initial.current = formSnapshot(formRef.current);
    if (fullPage) {
      heading.current?.focus();
      window.scrollTo({
        top: 0
      });
    }
  }, [fullPage]);
  const mayLeave = useCallback(async () => {
    if (lock.current) return false;
    if (readOnly || initial.current === formSnapshot(formRef.current)) return true;
    return Boolean(await confirm({
      title: 'Buang perubahan?',
      message: 'Isian formulir belum disimpan. Kembali akan membuang perubahan Anda.',
      danger: true,
      accept: 'Buang Perubahan'
    }));
  }, [confirm, readOnly]);
  useEffect(() => {
    registerGuard.current = mayLeave;
    return () => {
      registerGuard.current = null;
    };
  }, [registerGuard, mayLeave]);
  async function requestClose() {
    if (await mayLeave()) close();
  }
  async function submit(event) {
    event.preventDefault();
    if (lock.current || readOnly) return;
    lock.current = true;
    const form = new FormData(event.currentTarget);
    if (!form.get('file')?.size && initialFile) form.set('file', initialFile);
    setSaving(true);
    setError('');
    setFieldErrors({});
    try {
      if (['report', 'proposal', 'version', 'cancel'].includes(kind) || kind === 'category' && initial.current !== formSnapshot(formRef.current)) {
        const decision = {
          SETUJUI: 'Setujui',
          TOLAK: 'Tolak',
          MINTA_REVISI: 'Minta Revisi',
          TERVERIFIKASI: 'Verifikasi',
          DITOLAK: 'Tolak'
        };
        const details = kind === 'cancel' ? ['Alasan: ' + form.get('alasan_tindakan')] : kind === 'proposal' ? ['Keputusan: ' + decision[form.get('keputusan')], 'Alasan: ' + form.get('alasan'), 'Arahan: ' + form.get('arahan')] : kind === 'report' ? ['Keputusan: ' + decision[form.get('status_verifikasi')], 'Catatan: ' + form.get('catatan')] : kind === 'version' ? ['Berlaku mulai: ' + form.get('berlaku_mulai'), 'Berlaku sampai: ' + (form.get('berlaku_sampai') || 'Seterusnya')] : ['Status: ' + label(form.get('status'))];
        if (!(await confirm({
          title: 'Konfirmasi ' + (action || title).toLowerCase(),
          message: 'Periksa informasi berikut sebelum disimpan.',
          details,
          accept: action || 'Simpan Perubahan'
        }))) return;
      }
      await save(form);
    } catch (failure) {
      setError(failure.message);
      setFieldErrors(failure.details || {});
    } finally {
      lock.current = false;
      setSaving(false);
    }
  }
  const contents = <>
    {fullPage && <button type="button" className="ks-link ks-back" onClick={requestClose} disabled={saving}><Icon name="arrow" style={{
        transform: 'rotate(180deg)'
      }} size={16} /> Kembali ke daftar</button>}
    {fullPage && <header className="ks-form-heading"><span className="mg-overline">MANAJEMEN KESISWAAN</span><h1 ref={heading} tabIndex={-1}>{title}</h1></header>}
    <form ref={formRef} className="ks-form" onSubmit={submit} aria-busy={saving}>
      <FieldErrors.Provider value={fieldErrors}><fieldset className="mg-form-fields" disabled={saving}>{children}</fieldset></FieldErrors.Provider>
      {error && <p className="ks-error" role="alert">{error}</p>}
      <footer className="ks-actions form-actions"><button type="button" disabled={saving} onClick={requestClose}>{readOnly ? 'Kembali' : 'Batal'}</button>
        {!readOnly && <button className="ks-primary" disabled={saving}>{saving ? 'Memproses…' : action || 'Simpan'}</button>}
      </footer>
    </form>
  </>;
  return fullPage ? <section className="ks-detail">{contents}</section> : <Modal title={title} onClose={requestClose} busy={saving}>{contents}</Modal>;
}
function UploadField({
  required,
  initialFile
}) {
  const [name, setName] = useState(initialFile?.name ?? '');
  return <section className="ks-panel ks-form-panel">
    <h2>Bukti Pendukung</h2>
    <p>PDF, JPEG, atau PNG · maksimal 5 MB</p>
    <Field title="Pilih berkas" name="file" type="file" accept=".pdf,.jpg,.jpeg,.png" required={required && !initialFile} onChange={event => setName(event.target.files[0]?.name ?? initialFile?.name ?? '')} />
    {name && <p className="ks-file-name" role="status"><Icon name="file" size={17} /> {name}</p>}
  </section>;
}
export { Field, Area, Rows, Students, WorkForm, UploadField };
