import { Children, useCallback, useEffect, useId, useRef, useState } from 'react';
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

export function RowActions({children}) {
  const items = Children.toArray(children).filter(Boolean);
  const [open,setOpen] = useState(false);
  const trigger = useRef(null);
  const popup = useRef(null);
  const popupId = useId();
  useEffect(() => {
    if(!open) return;
    popup.current?.querySelector('button:not(:disabled)')?.focus({preventScroll:true});
    const close = event => {if(!popup.current?.contains(event.target) && !trigger.current?.contains(event.target)) setOpen(false);};
    const keys = event => {
      if(event.key === 'Escape' || event.key === 'Tab') {setOpen(false); if(event.key==='Escape') {event.preventDefault(); trigger.current?.focus();}}
      if(['ArrowDown','ArrowUp','Home','End'].includes(event.key)) {
        event.preventDefault(); const buttons = [...popup.current.querySelectorAll('button:not(:disabled)')];
        const index = buttons.indexOf(document.activeElement);
        buttons[event.key==='Home' ? 0 : event.key==='End' ? buttons.length-1 : (index+(event.key==='ArrowDown'?1:-1)+buttons.length)%buttons.length]?.focus();
      }
    };
    document.addEventListener('pointerdown',close); document.addEventListener('keydown',keys);
    window.addEventListener('resize',close); window.addEventListener('wheel',close,true);
    return () => { document.removeEventListener('pointerdown',close); document.removeEventListener('keydown',keys); window.removeEventListener('resize',close); window.removeEventListener('wheel',close,true); };
  },[open]);
  const box = open ? trigger.current?.getBoundingClientRect() : null;
  return <div className="mg-row-actions">{items.slice(0,2)}{items.length > 2 && <><button ref={trigger} type="button" aria-expanded={open} aria-controls={open ? popupId : undefined} aria-haspopup="true" onClick={() => setOpen(value=>!value)}><Icon name="more" size={16}/>Lainnya</button>{open && createPortal(<div id={popupId} ref={popup} className="mg-surface mg-action-menu" role="group" aria-label="Aksi lainnya" style={{left:Math.max(12,Math.min(box.right-210,window.innerWidth-222)),top:Math.min(box.bottom+6,window.innerHeight-220)}} onClick={()=>{trigger.current?.focus();setOpen(false);}}>{items.slice(2)}</div>, document.body)}</>}</div>;
}
