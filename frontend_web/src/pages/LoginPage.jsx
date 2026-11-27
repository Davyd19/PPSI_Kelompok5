import { useState } from 'react';
import { apiRequest, setAccessToken } from '../api/client';
import Icon from '../components/Icon';
import Button from '../components/Button';
import { Dialog } from '../components/Ui';
import logo from '../assets/logo.png';
import photo from '../assets/sekolah.jpg';
import '../styles/login.css';

const DIALOG_TEXT = {
  'Lupa kata sandi': 'Hubungi Admin sekolah untuk mereset kata sandi akun Anda.',
  'Hubungi Admin Sekolah': 'Akun SIM Kesiswaan dibuat oleh Admin sekolah. Silakan hubungi Admin sekolah untuk mendapatkan identitas akun dan kata sandi.',
};

export default function LoginPage({ onSelect }) {
  const [identity, setIdentity] = useState(''),
    [password, setPassword] = useState(''),
    [visible, setVisible] = useState(false),
    [error, setError] = useState(''),
    [busy, setBusy] = useState(false),
    [dialog, setDialog] = useState('');

  async function submit(e) {
    e.preventDefault();
    if (!identity.trim() || !password) {
      setError('Identitas akun dan kata sandi wajib diisi.');
      return;
    }
    setBusy(true);
    setError('');
    try {
      const { data } = await apiRequest('/auth/login', {
        method: 'POST',
        body: { identitas_akun: identity, kata_sandi: password, platform: 'web' },
      });
      setAccessToken(data.access_token);
      onSelect({
        ...data.user,
        authenticated: true,
        activeRole: data.user.primary_role ?? data.user.available_roles[0],
      });
    } catch (e) {
      setError(e.message);
    } finally {
      setPassword('');
      setBusy(false);
    }
  }

  return (
    <main className="auth-shell">
      <span className="auth-glow auth-glow--a" aria-hidden="true" />
      <span className="auth-glow auth-glow--b" aria-hidden="true" />

      <div className="auth-layout">
        {/* Kiri: foto sekolah */}
        <section className="auth-visual" aria-label="Tentang SIM Kesiswaan">
          <img className="auth-school-background" src={photo} alt="SMA Negeri 12 Padang" />
          <div className="auth-school-caption"><span className="auth-eyebrow">SMAN 12 PADANG</span><h2>SIM Kesiswaan</h2><p>Sistem Informasi Kesiswaan<br/>SMAN 12 Padang.</p></div>
        </section>

        {/* Kanan: sama seperti tampilan mobile */}
        <section className="auth-side">
          <div className="auth-brand">
            <div className="auth-logo"><img src={logo} alt="Logo SMAN 12 Padang" /></div>
            <span className="auth-eyebrow">SMAN 12 Padang</span>
            <h1>Selamat Datang</h1>
          </div>

          <div className="auth-card" role="group" aria-labelledby="auth-title">
            <div className="auth-card-head">
              <h2 id="auth-title">Masuk ke akun</h2>
              <p>Gunakan identitas akun dari Admin sekolah.</p>
            </div>

            <form onSubmit={submit} noValidate>
              <label htmlFor="identity">Identitas akun</label>
              <div className="auth-input">
                <Icon name="user" size={18} />
                <input id="identity" value={identity} onChange={e => setIdentity(e.target.value)}
                  autoComplete="username" placeholder="Contoh: nama.guru" disabled={busy} />
              </div>

              <label htmlFor="password">Kata sandi</label>
              <div className="auth-input">
                <Icon name="lock" size={18} />
                <input id="password" type={visible ? 'text' : 'password'} value={password}
                  onChange={e => setPassword(e.target.value)} autoComplete="current-password"
                  placeholder="Masukkan kata sandi" disabled={busy} />
                <Button aria-label={visible ? 'Sembunyikan kata sandi' : 'Tampilkan kata sandi'}
                  className="auth-eye" onClick={() => setVisible(v => !v)}><Icon name="eye" size={18} /></Button>
              </div>

              <div className="auth-forgot">
                <Button className="auth-link" onClick={() => setDialog('Lupa kata sandi')}>Lupa kata sandi?</Button>
              </div>

              {error && <p className="auth-error" role="alert"><Icon name="info" size={16} />{error}</p>}

              <Button className="auth-submit" type="submit" disabled={busy}>
                {busy ? 'Memproses…' : 'Masuk ke SIM Kesiswaan'}<Icon name="arrow" size={16} />
              </Button>
            </form>
          </div>
        </section>
      </div>

      <footer className="auth-footer">
        <span>Belum punya akun?</span>
        <Button className="auth-link auth-link--sun" onClick={() => setDialog('Hubungi Admin Sekolah')}>Hubungi Admin Sekolah</Button>
      </footer>

      {dialog && <Dialog title={dialog} onClose={() => setDialog('')}><p>{DIALOG_TEXT[dialog]}</p></Dialog>}
    </main>
  );
}
