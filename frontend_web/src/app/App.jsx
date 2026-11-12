import { useEffect, useState } from 'react';
import { Navigate, Route, Routes } from 'react-router-dom';
import LoginPage from '../pages/LoginPage';
import AdminPage from '../pages/admin/AdminPage';
import KesiswaanPage from '../pages/kesiswaan/KesiswaanPage';
import { Identity } from '../components/Ui';
import { apiRequest, setAccessToken } from '../api/client';

const roleLabels = { ADMIN:'Admin', KESISWAAN:'Kesiswaan', KEPALA_SEKOLAH:'Kepala Sekolah' };
const homes = { ADMIN:'/admin/dashboard', KESISWAAN:'/kesiswaan/dashboard', KEPALA_SEKOLAH:'/kepala-sekolah' };

export default function App() {
  const [profile,setProfile] = useState(null);
  const [switching,setSwitching] = useState(false);
  const [error,setError] = useState('');
  function clear() {
    setAccessToken(null);
    setProfile(null);
    setSwitching(false);
  }
  async function logout() {
    setError('');
    try {
      await apiRequest('/auth/logout',{method:'POST'});
      clear();
    } catch (e) {
      setError(e.message);
    }
  }
  useEffect(() => {
    window.addEventListener('sim-session-expired',clear);
    return () => window.removeEventListener('sim-session-expired',clear);
  }, []);
  const home = homes[profile?.activeRole] ?? '/';
  const chooser = profile && (!profile.activeRole || switching);
  const changeRole = async () => {
    try {
      const {data} = await apiRequest('/auth/me');
      setProfile(current => current ? {...current,...data} : null);
      setSwitching(true);
    } catch (e) { setError(e.message); }
  };
  return <>
    {error && <div className="auth-notice" role="alert">{error} <button onClick={()=>setError('')}>Tutup</button></div>}
    {chooser ? <main className="login-right"><section className="login-panel">
      <Identity/><h2>Pilih peran</h2><p>{profile.name}</p>
      {profile.available_roles.map(role => <button className="primary login-submit" key={role} onClick={()=>{
        setProfile({...profile,activeRole:role});setSwitching(false);
      }}>{roleLabels[role]}</button>)}
      <button className="text-button" onClick={logout}>Keluar</button>
    </section></main> : <>
      {profile?.activeRole !== 'KESISWAAN' && profile?.available_roles?.length > 1 && <button className="role-switch" onClick={changeRole}>Ganti peran</button>}
      <Routes>
        <Route path="/" element={profile ? <Navigate to={home} replace/> : <LoginPage onSelect={setProfile}/>}/>
        <Route path="/admin/:section" element={profile?.activeRole==='ADMIN' ? <AdminPage profile={profile} onLogout={logout}/> : <Navigate to={home} replace/>}/>
        <Route path="/kesiswaan/:section" element={profile?.activeRole==='KESISWAAN' ? <KesiswaanPage profile={profile} onLogout={logout} onSwitchRole={changeRole}/> : <Navigate to={home} replace/>}/>
        <Route path="/kepala-sekolah" element={profile?.activeRole==='KEPALA_SEKOLAH' ? <main className="login-right"><section className="login-panel"><Identity/><h2>Kepala Sekolah</h2><p>{profile.name} · {profile.identitas_login}</p><p>Dashboard Kepala Sekolah sedang dikembangkan.</p><button className="text-button" onClick={logout}>Keluar</button></section></main> : <Navigate to={home} replace/>}/>
        <Route path="*" element={<Navigate to={home} replace/>}/>
      </Routes>
    </>}
  </>;
}
