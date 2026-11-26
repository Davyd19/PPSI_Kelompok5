import { useConfirm } from '../../hooks/useConfirm';
import { createContext, useCallback, useContext, useEffect, useRef, useState } from 'react';
import { Navigate, useNavigate, useParams } from 'react-router-dom';
import { apiRequest } from '../../api/client';
import Icon from '../../components/Icon';
import PortalShell from '../../components/PortalShell';
import ReportEvidence from '../../components/ReportEvidence';
import KesiswaanOverview from './KesiswaanOverview';
import { ManagementProvider, Modal, Notice, StatusBadge, RowActions, LoadingState, EmptyState } from '../../components/ManagementUi';
import { formSnapshot } from '../../utils/management';

const base = '/kesiswaan';
const sections = {
  dashboard:['Dashboard','dashboard'], reports:['Laporan pelanggaran','file'],
  categories:['Kategori dan aturan','shield'], proposals:['Peninjauan kasus','shield'],
  achievements:['Prestasi siswa','badge'], attendance:['Rekap presensi','calendar']
};
const sectionInfo = {
  dashboard: ['Dashboard Kesiswaan & Kedisiplinan', 'Pantau laporan pelanggaran dan rekap kehadiran SMAN 12 Padang.'],
  reports: ['Laporan Pelanggaran', 'Catat kejadian dan periksa laporan yang masuk.'],
  categories: ['Kategori Pelanggaran', 'Kelola kategori dan versi aturan penanganan.'],
  proposals: ['Peninjauan Kasus', 'Tinjau usulan eskalasi dan rujukan yang diajukan.'],
  achievements: ['Pencatatan Prestasi', 'Kelola prestasi individu dan tim beserta bukti pendukungnya.'],
  attendance: ['Rekap Presensi Sekolah', 'Lihat kehadiran siswa per sesi presensi sekolah.'],
};
// Halaman yang punya kolom pencarian beserta petunjuk isiannya.
const searchInfo = {
  reports: 'Nama siswa, NISN, kategori, atau pelapor',
  attendance: 'Nama siswa atau NISN',
  proposals: 'Ringkasan atau nomor usulan, mis. #12',
  achievements: 'Judul, tim, tingkat, hasil, atau nama peserta',
};
const labels = {
  AKTIF: 'Aktif', NONAKTIF: 'Nonaktif', USULAN_ESKALASI: 'Usulan eskalasi', USULAN_RUJUKAN: 'Usulan rujukan',
  MENUNGGU:'Menunggu', TERVERIFIKASI:'Terverifikasi', DITOLAK:'Ditolak', DISETUJUI:'Disetujui',
  PERLU_REVISI:'Perlu revisi', HADIR:'Hadir', TERLAMBAT:'Terlambat', IZIN:'Izin', SAKIT:'Sakit', ALFA:'Alfa',
  PENGECUALIAN_SAH:'Pengecualian sah', PENGECUALIAN_SAH_ZUHUR:'Pengecualian sah Zuhur', BELUM_DIISI:'Belum diisi'
};
const wib = value => value ? new Intl.DateTimeFormat('id-ID',{timeZone:'Asia/Jakarta',dateStyle:'medium',timeStyle:'short'}).format(new Date(value)) : '—';
const shortDate = value => value || '—';
const label = value => labels[value] || String(value ?? '—').replaceAll('_',' ');
const status = value => <StatusBadge value={value}>{label(value)}</StatusBadge>;

const FieldErrors = createContext({});
function Field({ name, title, children, type='text', ...props }) {
  const errors=useContext(FieldErrors);
  const error=errors[name || children?.props?.name];
  const required=props.required || children?.props?.required;
  return <label className="ks-field" data-invalid={Boolean(error)}><span>{title}{required && <span className="mg-required"> *</span>}</span>{children || <input name={name} type={type} aria-invalid={Boolean(error)} {...props}/>}{error && <small role="alert" className="mg-field-error">{error}</small>}</label>;
}
function Area({ name,title,required=false,defaultValue='' }) {
  return <Field title={title}><textarea name={name} required={required} defaultValue={defaultValue} rows={3}/></Field>;
}
function Rows({ headers, items, render, filtered = false, onReset }) {
  return items.length ? <div className="ks-table-scroll" tabIndex={0} role="region" aria-label="Tabel hasil"><table><thead><tr>{headers.map(h=><th key={h}>{h}</th>)}</tr></thead>
    <tbody>{items.map((row,i)=><tr key={row.id ?? `${row.id_sesi}-${row.id_siswa}-${i}`}>{render(row)}</tr>)}</tbody></table></div>
    : <EmptyState filtered={filtered} onReset={onReset}/>;
}
function Students({multiple=false}) {
  const [query,setQuery]=useState('');
  const [results,setResults]=useState([]);
  const [selected,setSelected]=useState([]);
  const [error,setError]=useState('');
  useEffect(()=>{
    const controller=new AbortController();
    const timer=setTimeout(()=>{
      setError('');
      apiRequest(`${base}/lookups?q=${encodeURIComponent(query)}`,{signal:controller.signal})
        .then(({data})=>setResults(data.students)).catch(e=>{if(e.name!=='AbortError') setError(e.message);});
    },200);
    return ()=>{clearTimeout(timer);controller.abort();};
  },[query]);
  return <fieldset className="ks-students"><legend>{multiple?'Peserta':'Siswa'}</legend>
    <input aria-label="Cari siswa" placeholder="Cari nama atau NISN" value={query} onChange={e=>setQuery(e.target.value)}/>
    <select aria-label="Pilih siswa" value="" onChange={e=>{
      const item=results.find(r=>String(r.id)===e.target.value);
      if(item) setSelected(s=>multiple?[...s.filter(r=>r.id!==item.id),item]:[item]);
    }}><option value="">Pilih siswa</option>{results.map(s=><option key={s.id} value={s.id}>{s.nama} · {s.nisn}</option>)}</select>
    {selected.map(s=><div key={s.id} className="ks-selected">{s.nama}
      <input type="hidden" name={multiple?'peserta':'id_siswa'} value={s.id}/>
      <button type="button" onClick={()=>setSelected(items=>items.filter(i=>i.id!==s.id))} aria-label={`Hapus ${s.nama}`}>×</button></div>)}
    {error&&<p role="alert">{error}</p>}
  </fieldset>;
}
function WorkForm({title,close,save,children,readOnly,fullPage,action,initialFile,kind,registerGuard}) {
  const [error,setError] = useState('');
  const [fieldErrors,setFieldErrors] = useState({});
  const [saving,setSaving] = useState(false);
  const lock = useRef(false);
  const formRef = useRef(null);
  const initial = useRef(null);
  const heading = useRef(null);
  const confirm = useConfirm();
  useEffect(() => {
    initial.current = formSnapshot(formRef.current);
    if (fullPage) { heading.current?.focus(); window.scrollTo({top:0}); }
  }, [fullPage]);
  const mayLeave = useCallback(async () => {
    if(lock.current) return false;
    if(readOnly || initial.current === formSnapshot(formRef.current)) return true;
    return Boolean(await confirm({title:'Buang perubahan?',message:'Isian formulir belum disimpan. Kembali akan membuang perubahan Anda.',danger:true,accept:'Buang Perubahan'}));
  },[confirm,readOnly]);
  useEffect(() => { registerGuard.current = mayLeave; return () => {registerGuard.current = null;}; },[registerGuard,mayLeave]);
  async function requestClose() { if(await mayLeave()) close(); }
  async function submit(event) {
    event.preventDefault();
    if(lock.current || readOnly) return;
    lock.current = true;
    const form = new FormData(event.currentTarget);
    if (!form.get('file')?.size && initialFile) form.set('file',initialFile);
    setSaving(true); setError('');setFieldErrors({});
    try {
      if(['report','proposal','version'].includes(kind) || (kind==='category' && initial.current !== formSnapshot(formRef.current))) {
        const decision = {SETUJUI:'Setujui',TOLAK:'Tolak',MINTA_REVISI:'Minta Revisi',TERVERIFIKASI:'Verifikasi',DITOLAK:'Tolak'};
        const details = kind==='proposal' ? ['Keputusan: '+decision[form.get('keputusan')], 'Alasan: '+form.get('alasan'),'Arahan: '+form.get('arahan')] : kind==='report' ? ['Keputusan: '+decision[form.get('status_verifikasi')],'Catatan: '+form.get('catatan')] : kind==='version' ? ['Berlaku mulai: '+form.get('berlaku_mulai'),'Berlaku sampai: '+(form.get('berlaku_sampai') || 'Seterusnya')] : ['Status: '+label(form.get('status'))];
        if(!await confirm({title:'Konfirmasi '+(action || title).toLowerCase(),message:'Periksa informasi berikut sebelum disimpan.',details,accept:action || 'Simpan Perubahan'})) return;
      }
      await save(form);
    } catch(failure) {setError(failure.message);setFieldErrors(failure.details || {});}
    finally {lock.current=false;setSaving(false);}
  }
  const contents = <>
    {fullPage && <button type="button" className="ks-link ks-back" onClick={requestClose} disabled={saving}><Icon name="arrow" style={{transform:'rotate(180deg)'}} size={16}/> Kembali ke daftar</button>}
    {fullPage && <header className="ks-form-heading"><span className="mg-overline">MANAJEMEN KESISWAAN</span><h1 ref={heading} tabIndex={-1}>{title}</h1></header>}
    <form ref={formRef} className="ks-form" onSubmit={submit} aria-busy={saving}>
      <FieldErrors.Provider value={fieldErrors}><fieldset className="mg-form-fields" disabled={saving}>{children}</fieldset></FieldErrors.Provider>
      {error && <p className="ks-error" role="alert">{error}</p>}
      <footer className="ks-actions form-actions"><button type="button" disabled={saving} onClick={requestClose}>{readOnly?'Kembali':'Batal'}</button>
        {!readOnly && <button className="ks-primary" disabled={saving}>{saving?'Memproses…':action||'Simpan'}</button>}
      </footer>
    </form>
  </>;
  return fullPage ? <section className="ks-detail">{contents}</section> : <Modal title={title} onClose={requestClose} busy={saving}>{contents}</Modal>;
}

function UploadField({ required, initialFile }) {
  const [name,setName] = useState(initialFile?.name ?? '');
  return <section className="ks-panel ks-form-panel">
    <h2>Bukti Pendukung</h2>
    <p>PDF, JPEG, atau PNG · maksimal 5 MB</p>
    <Field title="Pilih berkas" name="file" type="file" accept=".pdf,.jpg,.jpeg,.png"
      required={required && !initialFile} onChange={event => setName(event.target.files[0]?.name ?? initialFile?.name ?? '')}/>
    {name && <p className="ks-file-name" role="status"><Icon name="file" size={17}/> {name}</p>}
  </section>;
}

function KesiswaanWorkspace({profile,onLogout}) {
  const {section}=useParams();
  const navigate=useNavigate();
  const leaveGuard=useRef(null);
  const [messageError,setMessageError]=useState(false);
  const closeNotice=useCallback(()=>setMessage(''),[]);
  const [data,setData]=useState(null),[lookups,setLookups]=useState({classes:[],categories:[]});
  const [error,setError]=useState(''),[message,setMessage]=useState(''),[retry,setRetry]=useState(0);
  const [modal,setModal]=useState(null),[filter,setFilter]=useState({mulai:'',sampai:'',kelas:'',status:''}),[page,setPage]=useState(1);
  const [meta,setMeta]=useState(null);
  const [categorySearch, setCategorySearch] = useState('');
  const [categoryStatus, setCategoryStatus] = useState('');
  const [search, setSearch] = useState(''), [q, setQ] = useState(''), [proposalStatus, setProposalStatus] = useState('');
  // Tunda pencarian ke server sampai pengguna berhenti mengetik.
  useEffect(() => {
    const next = search.trim();
    if (next === q) return;
    const timer = setTimeout(() => { setQ(next); setPage(1); }, 350);
    return () => clearTimeout(timer);
  }, [search, q]);
  const filtered=['dashboard','reports','attendance'].includes(section);
  const searchable=Boolean(searchInfo[section]);
  const activeFilter={...filter,status:section==='dashboard'?'':filter.status};
  const qs=new URLSearchParams([
    ...(filtered ? Object.entries(activeFilter).filter(([,v])=>v) : []),
    ...(searchable && q ? [['q',q]] : []),
    ...(section==='proposals' && proposalStatus ? [['status',proposalStatus]] : []),
    ['page',String(page)]
  ]).toString();
  const query=qs;
  const requestKey=`${section}?${query}&revision=${retry}`;
  const [loaded,setLoaded]=useState('');
  useEffect(()=>{
    if(!sections[section])return;
    const controller=new AbortController();
    apiRequest(`${base}/${section}?${query}`,{signal:controller.signal})
      .then(result=>{setData(result.data);setMeta(result.meta);setError('');setLoaded(requestKey);})
      .catch(e=>{if(e.name!=='AbortError'){setError(e.message);setLoaded(requestKey);}});
    return ()=>controller.abort();
  },[section,query,requestKey]);
  useEffect(()=>{
    const controller=new AbortController();
    apiRequest(`${base}/lookups`,{signal:controller.signal}).then(({data})=>setLookups(data)).catch(e=>{if(e.name!=='AbortError'){setMessageError(true);setMessage(e.message);}});
    return ()=>controller.abort();
  },[retry]);
  function resetFilters(){setPage(1);setFilter({mulai:'',sampai:'',kelas:'',status:''});setSearch('');setQ('');setProposalStatus('');}
  function clearSearch(){setSearch('');setQ('');setProposalStatus('');setPage(1);}
  const searchBox = searchable && <Field title="Cari" type="search" value={search} placeholder={searchInfo[section]}
    onChange={e=>setSearch(e.target.value)} aria-label={`Cari ${sectionInfo[section][0].toLowerCase()}`}/>;
  function changed(key,value){setPage(1);setFilter(f=>({...f,[key]:value}));}
  function complete(text){setModal(null);setMessageError(false);setMessage(text);setRetry(n=>n+1);}
  async function download(path,name){
    try {
      const blob=await apiRequest(base+path,{responseType:'blob'});
      const url=URL.createObjectURL(blob);
      const a=document.createElement('a');a.href=url;a.download=name;a.click();
      setTimeout(()=>URL.revokeObjectURL(url),1000);
    } catch(e){setMessageError(true);setMessage(e.message);}
  }
  const post=(path,body,method='POST')=>apiRequest(base+path,{method,body});
  const upload=(id,file)=>apiRequest(`${base}/achievements/${id}/attachments`,{
    method:'POST',body:file,headers:{'Content-Type':file.type,'X-Filename':encodeURIComponent(file.name)}
  });
  async function save(form) {
    const body=Object.fromEntries(form), row=modal.row;
    switch(modal.kind) {
      case 'createReport':
        body.waktu_kejadian+='+07:00';
        await post('/reports',body);break;
      case 'report':await post(`/reports/${row.id}/verify`,body);break;
      case 'category':await post(row?`/categories/${row.id}`:'/categories',body,row?'PUT':'POST');break;
      case 'version':await post(`/categories/${row.id}/versions`,body);break;
      case 'proposal':await post(`/proposals/${row.id}/decision`,body);break;
      case 'achievement': {
        const file=form.get('file');
        delete body.file;
        body.peserta=form.getAll('peserta');
        if(file?.size>5*1024*1024)throw new Error('Lampiran maksimal 5 MB.');
        const {data:achievement}=await post('/achievements',body);
        if(file?.size) {
          try{await upload(achievement.id,file);}
          catch(e){setModal({kind:'attachment',row:achievement,file});setRetry(n=>n+1);setMessageError(true);setMessage('Prestasi tersimpan. Unggahan belum berhasil: '+e.message);return;}
        }
        break;
      }
      case 'attachment': {
        const file=form.get('file');
        if(!file?.size || file.size>5*1024*1024)throw new Error('Pilih berkas maksimal 5 MB.');
        await upload(row.id,file);break;
      }
    }
    complete('Perubahan tersimpan.');
  }
  if(!sections[section])return <Navigate to={`${base}/dashboard`} replace/>;
  const allRows = loaded === requestKey && !error && Array.isArray(data) ? data : [];
  const rows = section === 'categories' ? allRows.filter(row =>
    (!categoryStatus || row.status === categoryStatus) &&
    [row.nama,row.deskripsi].some(value => value?.toLowerCase().includes(categorySearch.trim().toLowerCase()))
  ) : allRows;
  const dialog = modal?.row;
  const fullPage = ['report','proposal','achievement','createReport'].includes(modal?.kind);
  const readOnly = (modal?.kind === 'report' && dialog.status_verifikasi !== 'MENUNGGU') ||
    (modal?.kind === 'proposal' && dialog.status_usulan !== 'MENUNGGU');
  const titles = {
    createReport:'Catat Pelanggaran', report:'Verifikasi Laporan Pelanggaran', category:dialog?'Ubah Kategori':'Tambah Kategori',
    version:'Tambah Versi Aturan', proposal:dialog?.jenis?.includes('RUJUK')?'Peninjauan Usulan Rujukan':'Peninjauan Kasus Eskalasi',
    achievement:'Catat Prestasi Siswa', attachment:'Unggah Bukti Prestasi',
  };
  const actions = { report:'Simpan pemeriksaan', proposal:'Simpan keputusan', achievement:'Simpan prestasi', attachment:'Unggah bukti' };
  const [heading,description] = sectionInfo[section];
  function closeForm() { setModal(null); }
  async function changeSection() {
    if(leaveGuard.current && !await leaveGuard.current()) return false;
    setPage(1);
    setFilter(current => ({...current,status:''}));
    setSearch(''); setQ(''); setProposalStatus(''); setCategorySearch(''); setCategoryStatus('');
    setMessage('');
    closeForm();
    return true;
  }

  return <PortalShell className="management-ui portal" tone="kesiswaan" base={base} label="Manajemen Kesiswaan" sections={sections} profile={profile} roleLabel="Kesiswaan" onLogout={async()=>{if(!leaveGuard.current || await leaveGuard.current()) onLogout();}} onBeforeNavigate={async key=>{if(await changeSection()) navigate(`${base}/${key}`);}}>
      {fullPage && <div className="ks-content"><Notice message={message} error={messageError} onClose={closeNotice}/></div>}
      <div className="ks-content" hidden={fullPage}>
        <div className="ks-heading">
          <div><span className="ks-eyebrow">Manajemen kesiswaan</span><h1>{heading}</h1><p>{description}</p></div>
          <div className="ks-actions">
            {['dashboard','reports','attendance'].includes(section) &&
              <button onClick={() => download('/'+(section==='dashboard'?'attendance':section)+'.csv?'+qs,section==='reports'?'pelanggaran.csv':'presensi.csv')}><Icon name="download" size={16}/> Unduh CSV</button>}
            {['dashboard','reports'].includes(section) &&
              <button className="ks-primary" onClick={() => setModal({kind:'createReport'})}>＋ Catat Pelanggaran</button>}
            {section==='categories' && <button className="ks-primary" onClick={() => setModal({kind:'category'})}>＋ Tambah Kategori</button>}
            {section==='achievements' && <button className="ks-primary" onClick={() => setModal({kind:'achievement'})}>＋ Catat Prestasi</button>}
          </div>
        </div>
        {filtered && <section className="ks-filters ks-panel" aria-label="Filter data">
          <div className="ks-panel-heading"><h2>{section==='dashboard'?'Periode dan Kelas':'Filter Data'}</h2><button className="ks-link" onClick={resetFilters}>Reset</button></div>
          <div className="ks-filter-fields">
            {section!=='dashboard' && <div className="ks-search-field">{searchBox}</div>}
            <Field title="Mulai" type="date" value={filter.mulai} onChange={e=>changed('mulai',e.target.value)}/>
            <Field title="Sampai" type="date" value={filter.sampai} onChange={e=>changed('sampai',e.target.value)}/>
            <Field title="Kelas"><select value={filter.kelas} onChange={e=>changed('kelas',e.target.value)}><option value="">Semua kelas</option>
              {lookups.classes.map(c=><option key={c.id} value={c.id}>{c.nama}</option>)}</select></Field>
            {section!=='dashboard' && <Field title="Status"><select value={filter.status} onChange={e=>changed('status',e.target.value)}><option value="">Semua status</option>
              {(section==='reports'?['MENUNGGU','TERVERIFIKASI','DITOLAK']:['HADIR','TERLAMBAT','IZIN','SAKIT','ALFA','PENGECUALIAN_SAH','PENGECUALIAN_SAH_ZUHUR','BELUM_DIISI']).map(s=><option key={s} value={s}>{label(s)}</option>)}</select></Field>}
          </div>
          {!filter.mulai&&!filter.sampai && <small>Periode awal 30 hari terakhir</small>}
        </section>}
        {['proposals','achievements'].includes(section) && <section className="ks-filters ks-panel" aria-label="Cari data">
          <div className="ks-panel-heading"><h2>Cari Data</h2>{(search || proposalStatus) && <button className="ks-link" onClick={clearSearch}>Reset</button>}</div>
          <div className="ks-filter-fields">
            <div className="ks-search-field">{searchBox}</div>
            {section==='proposals' && <Field title="Status"><select value={proposalStatus} onChange={e=>{setPage(1);setProposalStatus(e.target.value);}}>
              <option value="">Semua status</option>{['MENUNGGU','DISETUJUI','DITOLAK','PERLU_REVISI'].map(s=><option key={s} value={s}>{label(s)}</option>)}</select></Field>}
          </div>
        </section>}
        {section==='categories' && <section className="ks-filters ks-panel" aria-label="Filter kategori"><div className="ks-filter-fields">
          <Field title="Cari kategori" type="search" placeholder="Nama atau deskripsi" value={categorySearch} onChange={event=>setCategorySearch(event.target.value)}/>
          <Field title="Status"><select value={categoryStatus} onChange={event=>setCategoryStatus(event.target.value)}>
            <option value="">Semua status</option><option value="AKTIF">Aktif</option><option value="NONAKTIF">Nonaktif</option>
          </select></Field>
        </div></section>}

    <Notice message={message} error={messageError} onClose={closeNotice}/>
    {loaded!==requestKey ? <LoadingState/> : error ? <p className="ks-error" role="alert">{error} <button onClick={()=>setRetry(n=>n+1)}>Coba lagi</button></p> : <>
      {section==='dashboard'&&<KesiswaanOverview data={data} formatTime={wib} renderStatus={status} renderRows={props => <Rows {...props}/>}
        onReview={row => setModal({kind:'report',row})} onViewReports={() => navigate(base+'/reports')}/>}
      {section==='reports'&&<section className="ks-panel ks-table-panel"><div className="ks-panel-heading"><h2>Daftar Laporan</h2></div><Rows filtered={Boolean(q || proposalStatus)} onReset={clearSearch} headers={['Siswa','Kategori','Waktu','Status','Aksi']} items={rows} render={r=><>
        <td>{r.siswa}<small>{r.kelas}</small></td><td>{r.kategori}</td><td>{wib(r.waktu_kejadian)}</td><td>{status(r.status_verifikasi)}</td>
        <td><button onClick={()=>setModal({kind:'report',row:r})}>Detail</button></td></>}/></section>}
      {section==='categories'&&<section className="ks-panel ks-table-panel">
        <div className="ks-panel-heading"><h2>Daftar Kategori <span className="ks-chip">{rows.length} hasil</span></h2></div><Rows filtered={Boolean(categorySearch.trim() || categoryStatus)} onReset={()=>{setCategorySearch('');setCategoryStatus('');}} headers={['Kategori','Status','Versi aturan','Aksi']} items={rows} render={r=><>
        <td>{r.nama}<small>{r.deskripsi}</small></td><td>{status(r.status)}</td><td>{r.aturan_id_kategori_pelanggaran.map(v=><details key={v.id}><summary>Versi {v.nomor_versi} · {v.berlaku_mulai} – {v.berlaku_sampai||'seterusnya'}</summary><p>{v.ketentuan}</p></details>)}</td>
        <td><RowActions><button onClick={()=>setModal({kind:'category',row:r})}><Icon name="edit" size={15}/>Edit</button><button onClick={()=>setModal({kind:'version',row:r})}>Versi baru</button></RowActions></td></>}/></section>}
      {section==='proposals'&&<section className="ks-panel ks-table-panel"><div className="ks-panel-heading"><h2>Daftar Usulan</h2></div><Rows filtered={Boolean(q || proposalStatus)} onReset={clearSearch} headers={['Usulan','Ringkasan yang diizinkan','Waktu','Status','Aksi']} items={rows} render={r=><>
        <td>{label(r.jenis)}<small>#{r.id}</small></td><td>{r.ringkasan_diizinkan || r.penanganan_siswa?.ringkasan_diizinkan || '—'}</td><td>{wib(r.waktu)}</td><td>{status(r.status_usulan)}</td>
        <td><button onClick={()=>setModal({kind:'proposal',row:r})}>{r.status_usulan==='MENUNGGU'?'Tinjau':'Detail'}</button></td></>}/></section>}
      {section==='attendance'&&<section className="ks-panel ks-table-panel"><div className="ks-panel-heading"><h2>Pratinjau Data Presensi</h2></div><Rows filtered={Boolean(q || proposalStatus)} onReset={clearSearch} headers={['Tanggal','Sesi','Siswa','Kelas','Status']} items={rows} render={r=><>
        <td>{shortDate(r.tanggal)}</td><td>{label(r.jenis_sesi)}</td><td>{r.siswa}</td><td>{r.kelas}</td><td>{status(r.status_kehadiran)}</td></>}/></section>}
      {section==='achievements'&&<section className="ks-panel ks-table-panel"><div className="ks-panel-heading"><h2>Daftar Prestasi Siswa</h2></div><Rows filtered={Boolean(q || proposalStatus)} onReset={clearSearch} headers={['Prestasi','Peserta','Tanggal','Hasil','Bukti']} items={rows} render={r=><>
        <td>{r.judul}<small>{r.nama_tim || r.tingkat_prestasi}</small></td><td>{r.peserta_id_portofolio.map(p=>p.siswa?.nama).join(', ')}</td>
        <td>{shortDate(r.tanggal)}</td><td>{r.hasil_prestasi}</td><td>{r.lampiran_id_portofolio.map(f=><button key={f.id} onClick={()=>download(`/attachments/${f.id}`,f.nama_berkas)}>{f.nama_berkas}</button>)}
        <button onClick={()=>setModal({kind:'attachment',row:r})}>Unggah bukti</button></td></>}/></section>}
      {meta&&meta.page_size&&<div className="ks-pagination"><button disabled={page<=1} onClick={()=>setPage(p=>p-1)}>Sebelumnya</button><span>Halaman {page} · {meta.total} data</span><button disabled={page*meta.page_size>=meta.total} onClick={()=>setPage(p=>p+1)}>Berikutnya</button></div>}
    </>}
    </div>
    {modal && <WorkForm key={modal.kind+'-'+(modal.row?.id || 'new')} kind={modal.kind} registerGuard={leaveGuard} title={titles[modal.kind]} close={closeForm} save={save}
      fullPage={fullPage} readOnly={readOnly} action={actions[modal.kind]} initialFile={modal.file}>
      {modal.kind==='createReport'&&<><Students/><Field title="Kategori"><select name="id_kategori_pelanggaran" required><option value="">Pilih kategori</option>
        {lookups.categories.filter(c=>c.status==='AKTIF').map(c=><option key={c.id} value={c.id}>{c.nama}</option>)}</select></Field>
        <Field title="Waktu kejadian (WIB)" name="waktu_kejadian" type="datetime-local" required/><Area name="uraian" title="Uraian" required/></>}
      {modal.kind==='report' && <>
        <section className="ks-panel ks-form-panel">
          <div className="ks-panel-heading"><h2>Identitas Siswa</h2>{status(dialog.status_verifikasi)}</div>
          <dl className="ks-detail-grid"><div><dt>Nama</dt><dd>{dialog.siswa}</dd></div><div><dt>Kelas</dt><dd>{dialog.kelas || '—'}</dd></div>
            <div><dt>Pelapor</dt><dd>{dialog.pelapor}</dd></div><div><dt>Waktu kejadian</dt><dd>{wib(dialog.waktu_kejadian)} WIB</dd></div></dl>
        </section>
        <section className="ks-panel ks-form-panel"><h2>{dialog.kategori}</h2>
          <p>Versi aturan {dialog.nomor_versi}</p><div className="ks-report-text">{dialog.uraian}</div>
        </section>
        <ReportEvidence id={dialog.id}/>
        <section className="ks-panel ks-form-panel"><h2>Catatan Pemeriksaan</h2>
          {readOnly ? <p>{dialog.hasil_verifikasi || '—'} · {dialog.pemeriksa || '—'}</p> :
            <><Field title="Keputusan"><select name="status_verifikasi"><option value="TERVERIFIKASI">Verifikasi</option><option value="DITOLAK">Tolak</option></select></Field>
              <Area name="catatan" title="Catatan pemeriksaan" required/></>}
        </section>
      </>}

      {modal.kind==='category'&&<><Field title="Nama kategori" name="nama" defaultValue={dialog?.nama} required maxLength={191}/><Area name="deskripsi" title="Deskripsi" defaultValue={dialog?.deskripsi || ''}/>
        <Field title="Status"><select name="status" defaultValue={dialog?.status || 'AKTIF'}><option value="AKTIF">Aktif</option><option value="NONAKTIF">Nonaktif</option></select></Field></>}
      {modal.kind==='version'&&<><p>{dialog.nama}</p><Area name="ketentuan" title="Ketentuan" required/><Field title="Berlaku mulai" name="berlaku_mulai" type="date" required/><Field title="Berlaku sampai" name="berlaku_sampai" type="date"/></>}
      {modal.kind==='proposal' && <>
        <section className="ks-panel ks-form-panel">
          <div className="ks-panel-heading"><h2>Ringkasan Usulan #{dialog.id}</h2>{status(dialog.status_usulan)}</div>
          <dl className="ks-detail-grid"><div><dt>Jenis usulan</dt><dd>{label(dialog.jenis)}</dd></div>
            <div><dt>Diajukan</dt><dd>{wib(dialog.waktu)} WIB</dd></div></dl>
          <div className="ks-report-text">{dialog.ringkasan_diizinkan || dialog.penanganan_siswa?.ringkasan_diizinkan || 'Ringkasan belum tersedia.'}</div>
        </section>
        {dialog.ringkasan_diizinkan && dialog.penanganan_siswa?.ringkasan_diizinkan &&
          dialog.ringkasan_diizinkan !== dialog.penanganan_siswa.ringkasan_diizinkan &&
          <section className="ks-panel ks-form-panel"><h2>Ringkasan Penanganan</h2><p>{dialog.penanganan_siswa.ringkasan_diizinkan}</p></section>}
        {!readOnly && <section className="ks-panel ks-form-panel"><h2>Keputusan dan Tindak Lanjut</h2>
          <fieldset className="ks-decisions"><legend>Keputusan</legend>
            {[['SETUJUI','Setujui'],['TOLAK','Tolak'],['MINTA_REVISI','Minta Revisi']].map(([value,title]) =>
              <label key={value}><input type="radio" name="keputusan" value={value} required/>{title}</label>)}
          </fieldset>
          <Area name="alasan" title="Alasan" required/><Area name="arahan" title="Arahan tindak lanjut" required/>
        </section>}
      </>}
      {modal.kind==='achievement' && <>
        <section className="ks-panel ks-form-panel"><h2>Peserta Prestasi</h2><Students multiple/></section>
        <section className="ks-panel ks-form-panel"><h2>Informasi Prestasi</h2>
          <Field title="Judul" name="judul" required maxLength={191}/>
          <div className="ks-form-columns">
            <Field title="Tanggal" name="tanggal" type="date" required/>
            <Field title="Nama tim jika peserta lebih dari satu" name="nama_tim"/>
            <Field title="Tingkat" name="tingkat_prestasi" required/>
            <Field title="Hasil" name="hasil_prestasi" required/>
          </div>
          <Area name="deskripsi" title="Deskripsi"/>
        </section>
      </>}
      {modal.kind==='attachment' && dialog.judul && <p>{dialog.judul}</p>}
      {['achievement','attachment'].includes(modal.kind) && <UploadField required={modal.kind==='attachment'} initialFile={modal.file}/>}
    </WorkForm>}

  </PortalShell>;
}

export default function KesiswaanPage(props) {return <ManagementProvider><KesiswaanWorkspace {...props}/></ManagementProvider>;}
