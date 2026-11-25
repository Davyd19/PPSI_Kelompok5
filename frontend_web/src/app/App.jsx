import { useEffect, useState } from 'react';
import { Navigate, Route, Routes } from 'react-router-dom';
import LoginPage from '../pages/LoginPage';
import AdminPage from '../pages/admin/AdminPage';
import KesiswaanPage from '../pages/kesiswaan/KesiswaanPage';
import KepalaSekolahPage from '../pages/kepsek/KepalaSekolahPage';
import { apiRequest, setAccessToken } from '../api/client';

// Setiap akun langsung masuk ke satu portal: Admin, Kepala Sekolah, atau Kesiswaan sesuai peran utama.
const homes = { ADMIN:'/admin/dashboard', KESISWAAN:'/kesiswaan/dashboard', KEPALA_SEKOLAH:'/kepala-sekolah/dashboard' };

export default function App() {
  const [profile,setProfile] = useState(null);
  const [error,setError] = useState('');
  function clear() {
    setAccessToken(null);
    setProfile(null);
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
  return <>
    {error && <div className="auth-notice" role="alert">{error} <button onClick={()=>setError('')}>Tutup</button></div>}
    <Routes>
      <Route path="/" element={profile ? <Navigate to={home} replace/> : <LoginPage onSelect={setProfile}/>}/>
      <Route path="/admin/:section" element={profile?.activeRole==='ADMIN' ? <AdminPage profile={profile} onLogout={logout}/> : <Navigate to={home} replace/>}/>
      <Route path="/kesiswaan/:section" element={profile?.activeRole==='KESISWAAN' ? <KesiswaanPage profile={profile} onLogout={logout}/> : <Navigate to={home} replace/>}/>
      <Route path="/kepala-sekolah/:section" element={profile?.activeRole==='KEPALA_SEKOLAH' ? <KepalaSekolahPage profile={profile} onLogout={logout}/> : <Navigate to={home} replace/>}/>
      <Route path="*" element={<Navigate to={home} replace/>}/>
    </Routes>
  </>;
}
