export const exampleAccounts = {admin:'admin', kesiswaan:'kesiswaan', kepsek:'kepala_sekolah', siswa:'siswa', ortu:'orang_tua', guru:'guru', wali:'wali_kelas', bk:'guru_bk', pembina:'pembina_ekstrakurikuler'};
export function validateAccount(identity,password,platform) {
  const role = exampleAccounts[identity.trim().toLowerCase()];
  if (!role || password !== 'Contoh123!') return { error:'Identitas akun atau kata sandi salah.' };
  const isWeb = ['admin','kesiswaan','kepala_sekolah'].includes(role);
  if ((platform === 'web') !== isWeb) return { error: isWeb ? 'Gunakan portal web untuk akun ini.' : 'Gunakan aplikasi mobile untuk akun ini.' };
  return {role};
}
