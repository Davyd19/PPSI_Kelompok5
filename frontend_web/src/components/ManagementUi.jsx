import {actionAppearance} from '../utils/table-actions';
import { cloneElement, isValidElement, Children, useCallback, useEffect, useId, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import Icon from './Icon';
import { statusTone } from '../utils/management';
import { ConfirmationContext } from '../hooks/useConfirm';
import '../styles/management.css';

let openPanels = 0;
let previousOverflow = '';

export function Modal({ title, children, onClose, busy = false, drawer = false, description, confirm = false }) {
  const ref = useRef(null);
  const titleId = useId();
  const descriptionId = useId();
  useEffect(() => {
    const element = ref.current;
    const previous = document.activeElement;
    if (openPanels++ === 0) { previousOverflow = document.body.style.overflow; document.body.style.overflow = 'hidden'; }
    element.showModal();
    (element.querySelector('[data-initial-focus]') || element.querySelector('button:not(:disabled), input:not(:disabled)'))?.focus({preventScroll:true});
    return () => {
      element.close();
      if (--openPanels === 0) document.body.style.overflow = previousOverflow;
      if (previous?.isConnected) previous.focus();
    };
  }, []);
  return createPortal(<dialog ref={ref} className={`mg-surface mg-dialog ${drawer ? 'mg-drawer' : ''} ${confirm ? 'mg-confirm' : ''}`} aria-labelledby={titleId} aria-describedby={description ? descriptionId : undefined} aria-busy={busy} onCancel={event => { event.preventDefault(); if (!busy) onClose(); }} onClick={event => { if (!busy && event.target === event.currentTarget) { const box = ref.current.getBoundingClientRect(); if(event.clientX < box.left || event.clientX > box.right || event.clientY < box.top || event.clientY > box.bottom) onClose(); } }}>
    <header className="mg-dialog-heading"><div><span className="mg-overline">SIM KESISWAAN</span><h2 id={titleId}>{title}</h2>{description && <p id={descriptionId}>{description}</p>}</div><button type="button" className="mg-icon-button" aria-label="Tutup dialog" disabled={busy} onClick={onClose}><Icon name="close" size={18}/></button></header>
    <div className="mg-dialog-body">{children}</div>
  </dialog>, document.body);
}

export function ManagementProvider({children}) {
  const [request,setRequest] = useState(null);
  const pending = useRef(null);
  useEffect(() => () => pending.current?.(null), []);
  const ask = useCallback(options => new Promise(resolve => {
    pending.current?.(null);
    pending.current = resolve;
    setRequest(options);
  }), []);
  function finish(value) { const resolve = pending.current; pending.current = null; setRequest(null); resolve?.(value); }
  return <ConfirmationContext.Provider value={ask}>{children}{request && <Modal confirm title={request.title || 'Konfirmasi tindakan'} onClose={() => finish(null)}>
    <div className={`mg-confirm-symbol ${request.danger ? 'danger' : ''}`}><Icon name={request.danger ? 'trash' : 'shield'} size={25}/></div>
    <p className="mg-confirm-description">{request.message}</p>
    {request.subject && <div className="mg-subject"><Icon name="file" size={19}/><strong>{request.subject}</strong></div>}
    {request.details?.length > 0 && <ul className="mg-impact">{request.details.map(item => <li key={item}>{item}</li>)}</ul>}
    <form onSubmit={event => { event.preventDefault(); finish(request.date ? new FormData(event.currentTarget).get('date') : true); }}>
      {request.date && <label className="mg-field"><span>Tanggal akhir masa berlaku *</span><input name="date" type="date" required defaultValue=""/><small>Akses berlaku sampai dengan tanggal yang dipilih.</small></label>}
      <footer className="mg-footer"><button data-initial-focus type="button" onClick={() => finish(null)}>Batal</button><button type="submit" className={request.danger ? 'mg-danger' : 'mg-primary'}>{request.accept || 'Lanjutkan'}</button></footer>
    </form>
  </Modal>}</ConfirmationContext.Provider>;
}
export function StatusBadge({value, children}) { return <span className={`mg-status mg-status-${statusTone(value)}`}><span aria-hidden="true"/>{children || String(value ?? 'Belum diisi').toLowerCase().replaceAll('_',' ').replace(/^./,c=>c.toUpperCase())}</span>; }

export function Notice({message, onClose, error = false}) {
  useEffect(() => { if(error || !message) return; const timer = setTimeout(onClose,6500); return () => clearTimeout(timer); }, [message,error,onClose]);
  if (!message) return null;
  return <div className={`mg-notice ${error ? 'mg-notice-error' : ''}`} role={error ? 'alert' : 'status'}><span className="mg-notice-icon"><Icon name={error ? 'info' : 'check'} size={20}/></span><div><strong>{error ? 'Tindakan belum berhasil' : 'Informasi'}</strong><p>{message}</p></div><button type="button" aria-label="Tutup pesan" onClick={onClose}><Icon name="close" size={17}/></button></div>;
}
export function LoadingState() {return <div className="mg-skeleton" role="status" aria-label="Memuat data"><span className="mg-sr-only">Memuat data…</span><div/><div/><div/><div/></div>;}
export function EmptyState({filtered = false, onReset}) {return <div className="mg-empty"><span><Icon name={filtered ? 'search' : 'file'} size={26}/></span><strong>{filtered ? 'Tidak ada hasil yang cocok' : 'Belum ada data'}</strong><p>{filtered ? 'Coba ubah kata pencarian atau filter Anda.' : 'Data akan tampil di sini setelah tersedia.'}</p>{filtered && onReset && <button type="button" onClick={onReset}>Reset filter</button>}</div>;}

function actionLabel(children){
 return Children.toArray(children).map(child=>typeof child==='string'||typeof child==='number'?String(child):isValidElement(child)?actionLabel(child.props.children):'').join(' ').replace(/\s+/g,' ').trim();
}
export function IconAction({label,icon,className='',...props}){
 const appearance=actionAppearance(label);
 return <button type="button" {...props} title={label} aria-label={label} data-tone={appearance.tone} className={`mg-row-icon ${className}`}><Icon name={icon||appearance.icon} size={17}/></button>;
}
export function RowActions({children}){
 const items=Children.toArray(children).filter(isValidElement);
 return <div className="mg-row-actions mg-icon-actions" role="group" aria-label="Aksi data">{items.map((item,index)=>{
  const label=item.props['aria-label']||item.props.title||actionLabel(item.props.children)||'Lihat detail';
  const appearance=actionAppearance(label);
  return cloneElement(item,{key:item.key||index,title:label,'aria-label':label,'data-tone':appearance.tone,className:`${item.props.className||''} mg-row-icon`,children:<Icon name={appearance.icon} size={17}/>});
 })}</div>;
}
