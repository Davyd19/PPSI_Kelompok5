import { useEffect, useRef } from 'react';
import Button from './Button';
import Icon from './Icon';
export function Identity() {return <div className="identity"><span className="school-mark"><Icon name="school" size={26}/></span><span><strong>SIM Kesiswaan</strong><small>SMAN 12 PADANG</small></span></div>;}
export function Feedback({loading,error,onRetry}) {return <div className={`feedback ${error?'error':''}`} role={error?'alert':'status'}>{loading ? 'Memuat informasi…' : <><p>{error || 'Belum ada informasi tersedia.'}</p>{onRetry && <Button onClick={onRetry}>Coba Lagi</Button>}</>}</div>;}
export function Dialog({title,children,onClose}) {
 const close = useRef(null);
 useEffect(()=>{const previous=document.activeElement;close.current?.focus();const key=e=>{if(e.key==='Escape')onClose();if(e.key==='Tab'){const focusable=e.currentTarget.querySelectorAll('button,input,select,a[href]');const first=focusable[0],last=focusable[focusable.length-1];if(e.shiftKey&&document.activeElement===first){e.preventDefault();last.focus();}else if(!e.shiftKey&&document.activeElement===last){e.preventDefault();first.focus();}}};const dialog=close.current?.closest('[role=dialog]');dialog?.addEventListener('keydown',key);return()=>{dialog?.removeEventListener('keydown',key);previous?.focus();};},[onClose]);
 return <div className="modal-backdrop" onClick={onClose}><section role="dialog" aria-modal="true" aria-labelledby="dialog-title" className="modal" onClick={e=>e.stopPropagation()}><h2 id="dialog-title">{title}</h2><div>{children}</div><Button ref={close} onClick={onClose}>Tutup</Button></section></div>;
}
export function Card({title,subtitle,action,children,className=''}) {return <section className={`card ${className}`}><div className="card-heading"><div><h2>{title}</h2>{subtitle&&<p>{subtitle}</p>}</div>{action}</div>{children}</section>;}
export function Stat({label,value,detail,icon='chart',tone=''}) {return <article className={`stat-card ${tone}`}><div className="stat-label">{label}<span className="stat-icon"><Icon name={icon}/></span></div><strong>{value}</strong><p>{detail}</p></article>;}
