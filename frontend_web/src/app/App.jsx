import { useEffect, useState } from 'react';
import { Navigate, Route, Routes } from 'react-router-dom';
import LoginPage from '../pages/LoginPage';
import DashboardPage from '../pages/DashboardPage';
import AdminPage from '../pages/admin/AdminPage';
import { setAccessToken } from '../api/client';
export default function App() {
  const [profile, setProfile] = useState(null);
  function logout() {
    setAccessToken(null);
    setProfile(null);
  }
  useEffect(() => {
    const expired = () => {
      setAccessToken(null);
      setProfile(null);
    };
    window.addEventListener('sim-session-expired', expired);
    return () => window.removeEventListener('sim-session-expired', expired);
  }, []);
  const home = profile?.authenticated ? '/admin/dashboard' : '/beranda';
  return <Routes><Route path="/" element={profile ? <Navigate to={home} replace /> : <LoginPage onSelect={setProfile} />} /><Route path="/admin/:section" element={profile?.authenticated && profile.roles.includes('ADMIN') ? <AdminPage profile={profile} onLogout={logout} /> : <Navigate to="/" replace />} /><Route path="/beranda" element={profile ? profile.authenticated ? <Navigate to="/admin/dashboard" replace /> : <DashboardPage profile={profile} onLogout={logout} /> : <Navigate to="/" replace />} /><Route path="*" element={<Navigate to={profile ? home : '/'} replace />} /></Routes>;
}
