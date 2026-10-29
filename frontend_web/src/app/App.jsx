import { useState } from 'react';
import { Navigate, Route, Routes } from 'react-router-dom';
import LoginPage from '../pages/LoginPage';
import DashboardPage from '../pages/DashboardPage';
export default function App() {
  const [profile,setProfile]=useState(null);
  return <Routes><Route path="/" element={profile?<Navigate to="/beranda" replace/>:<LoginPage onSelect={setProfile}/>}/><Route path="/beranda" element={profile?<DashboardPage profile={profile} onLogout={()=>setProfile(null)}/>:<Navigate to="/" replace/>}/><Route path="*" element={<Navigate to={profile?'/beranda':'/'} replace/>}/></Routes>;
}
