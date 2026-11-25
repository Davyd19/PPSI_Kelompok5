import { useEffect, useRef, useState } from 'react';
import { NavLink } from 'react-router-dom';
import Icon from './Icon';
import { Identity } from './Ui';
import '../pages/kesiswaan/kesiswaan.css';
import '../styles/portal.css';

// Kerangka bersama portal web (sidebar, laci menu ponsel, header profil).
// `tone` memberi aksen warna khas tiap portal: kesiswaan, kepsek, atau admin.
function Nav({ base, label, sections, onNavigate, onBeforeNavigate, footer }) {
  return <>
    <div className="ks-brand"><Identity/></div>
    <nav aria-label={label}>
      <span className="ks-nav-label">{label}</span>
      {Object.entries(sections).map(([key, [title, icon]]) =>
        <NavLink key={key} to={`${base}/${key}`} onClick={async event => { if(onBeforeNavigate) { event.preventDefault(); await onBeforeNavigate(key); } else onNavigate(key); }}><Icon name={icon} size={18}/>{title}</NavLink>)}
    </nav>
    {footer && <div className="ks-side-footer">{footer}</div>}
  </>;
}

export default function PortalShell({ tone, className = '', sideFooter, base, label, sections, profile, roleLabel, onLogout, onNavigate, onBeforeNavigate, children }) {
  const drawer = useRef(null);
  const [profileOpen, setProfileOpen] = useState(false);
  useEffect(() => {
    const wide = window.matchMedia('(min-width: 861px)');
    const closeDrawer = event => { if (event.matches) drawer.current?.close(); };
    wide.addEventListener('change', closeDrawer);
    return () => wide.removeEventListener('change', closeDrawer);
  }, []);
  const navigate = key => { drawer.current?.close(); onNavigate?.(key); };
  const initials = profile.name.split(/\s+/).filter(Boolean).slice(0, 2).map(w => w[0]).join('').toUpperCase();
  return <div className={`ks-layout tone-${tone} ${className}`}>
    <aside className="ks-sidebar"><Nav base={base} label={label} sections={sections} onNavigate={navigate} onBeforeNavigate={onBeforeNavigate ? async key => { await onBeforeNavigate(key); drawer.current?.close(); } : undefined} footer={sideFooter}/></aside>
    <dialog className="ks-drawer" ref={drawer} aria-label={`Menu ${label}`} onClick={event => {
      if (event.target === event.currentTarget) event.currentTarget.close();
    }}>
      <div className="ks-drawer-content">
        <button type="button" className="ks-drawer-close" onClick={() => drawer.current.close()} aria-label="Tutup menu">×</button>
        <Nav base={base} label={label} sections={sections} onNavigate={navigate} onBeforeNavigate={onBeforeNavigate ? async key => { await onBeforeNavigate(key); drawer.current?.close(); } : undefined} footer={sideFooter}/>
      </div>
    </dialog>
    <main className="ks-main">
      <header className="ks-top">
        <div className="ks-top-context">
          <button className="ks-menu" type="button" onClick={() => drawer.current.showModal()} aria-label="Buka menu">☰</button>
          <span className="ks-school"><Icon name="school" size={17}/> SMAN 12 Padang</span>
          <span className="ks-role-tag">{roleLabel}</span>
        </div>
        <details className="ks-profile" open={profileOpen} onToggle={event => setProfileOpen(event.currentTarget.open)}>
          <summary><span><strong>{profile.name}</strong><small>{roleLabel}</small></span><i>{initials}</i></summary>
          <div className="ks-profile-card"><strong>Profil akun</strong><p>{profile.identitas_login}</p><div className="ks-actions"><button onClick={onLogout}><Icon name="logout" size={16}/> Keluar</button></div></div>
        </details>
      </header>
      {children}
    </main>
  </div>;
}
