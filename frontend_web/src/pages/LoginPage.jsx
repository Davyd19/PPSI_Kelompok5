import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { apiGet, apiRequest, setAccessToken } from '../api/client';
import { validateAccount } from '../utils/exampleAccounts';
import Icon from '../components/Icon';
import Button from '../components/Button';
import { Identity, Dialog } from '../components/Ui';
export default function LoginPage({
  onSelect
}) {
  const [identity, setIdentity] = useState(''),
    [password, setPassword] = useState(''),
    [visible, setVisible] = useState(false),
    [error, setError] = useState(''),
    [busy, setBusy] = useState(false),
    [dialog, setDialog] = useState('');
  const navigate = useNavigate();
  async function submit(e) {
    e.preventDefault();
    if (!identity.trim() || !password) {
      setError('Identitas akun dan kata sandi wajib diisi.');
      return;
    }
    setBusy(true);
    setError('');
    try {
      const demoIdentity = identity.trim().toLowerCase();
      if (import.meta.env.DEV && ['kesiswaan', 'kepsek'].includes(demoIdentity) && password === 'Contoh123!') {
        const result = validateAccount(identity, password, 'web');
        const profiles = await apiGet('/demo/profiles');
        const profile = profiles.find(p => p.role === result.role && p.platform === 'web');
        if (!profile) throw new Error('Profil prototipe belum tersedia.');
        onSelect(profile);
        navigate('/beranda');
        return;
      }
      const {
        data
      } = await apiRequest('/auth/login', {
        method: 'POST',
        body: {
          identitas_akun: identity,
          kata_sandi: password
        }
      });
      if (!data.user.roles.includes('ADMIN')) throw new Error('Web Admin memerlukan peran Admin aktif. Gunakan aplikasi/modul sesuai peran akun Anda.');
      setAccessToken(data.access_token);
      onSelect({
        ...data.user,
        authenticated: true
      });
      navigate('/admin/dashboard');
    } catch (e) {
      setError(e.message);
    } finally {
      setPassword('');
      setBusy(false);
    }
  }
  return <main className="login-shell"><section className="login-story"><Identity /><div className="login-intro"><span className="dark-pill">Portal Pengelola Sekolah</span><h1>SIM Kesiswaan<br />Admin Portal</h1><h3>Sistem Informasi Kedisiplinan, Kehadiran,<br />dan Ekstrakurikuler</h3><p>Mendukung pengelolaan kesiswaan dan pendampingan siswa SMAN 12 Padang dalam satu sistem.</p></div><div className="login-feature-grid">{[['clock', 'Presensi Sekolah', 'Ringkasan kehadiran pagi dan Zuhur yang terstruktur.'], ['shield', 'Pendampingan Siswa', 'Riwayat penanganan sesuai kewenangan pengguna.'], ['chart', 'Ringkasan Eksekutif', 'Informasi kehadiran, kasus, dan kegiatan siswa.']].map(([icon, title, text]) => <article key={title}><Icon name={icon} /><strong>{title}</strong><p>{text}</p></article>)}</div><small>SMAN 12 Padang · Portal administrasi sekolah.</small></section>
 <section className="login-right"><div className="login-panel"><span className="pill"><Icon name="shield" size={15} /> Akses Pengelola Sekolah</span><h2>Masuk Dashboard</h2><p>Silakan masukkan identitas akun dan kata sandi Anda untuk melanjutkan.</p><div className="login-info"><Icon name="info" /><span>Portal untuk Admin, Kesiswaan, dan Kepala Sekolah.<br />Peran lainnya menggunakan aplikasi mobile.</span></div><form onSubmit={submit} noValidate><label htmlFor="identity">Identitas akun <small>Wajib diisi</small></label><div className="input-wrap"><Icon name="user" /><input id="identity" value={identity} onChange={e => setIdentity(e.target.value)} autoComplete="off" placeholder="Masukkan identitas akun" disabled={busy} /></div><div className="label-row"><label htmlFor="password">Kata sandi</label><Button className="text-button" onClick={() => setDialog('Lupa kata sandi')}>Lupa Kata Sandi?</Button></div><div className="input-wrap"><Icon name="lock" /><input id="password" type={visible ? 'text' : 'password'} value={password} onChange={e => setPassword(e.target.value)} autoComplete="off" placeholder="Masukkan kata sandi" disabled={busy} /><Button aria-label={visible ? 'Sembunyikan kata sandi' : 'Tampilkan kata sandi'} className="icon-button" onClick={() => setVisible(v => !v)}><Icon name="eye" /></Button></div>{error && <p className="form-error" role="alert">{error}</p>}<Button className="primary login-submit" type="submit" disabled={busy}>{busy ? 'Memproses…' : 'Masuk Dashboard'}<Icon name="arrow" /></Button></form><div className="login-access"><Icon name="shield" /><span>Hak akses mengikuti akun yang digunakan.<br /><small>Gunakan identitas akun yang diberikan administrator.</small></span></div></div><div className="login-links"><Button className="text-button" onClick={() => setDialog('Bantuan akun')}><Icon name="help" size={16} /> Bantuan akun</Button><Button className="text-button" onClick={() => setDialog('Panduan penggunaan')}><Icon name="file" size={16} /> Buku panduan</Button></div><small className="copyright">SIM Kesiswaan · SMAN 12 Padang</small></section>
 {dialog && <Dialog title={dialog} onClose={() => setDialog('')}><p>{dialog === 'Lupa kata sandi' ? 'Hubungi Admin sekolah untuk mereset kata sandi akun Anda.' : 'Gunakan akun yang diberikan Admin. Panduan setup tersedia pada dokumentasi pengembangan.'}</p></Dialog>}</main>;
}
