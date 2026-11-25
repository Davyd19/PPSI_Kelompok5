const { Op } = require('sequelize');
const { models } = require('../models');
const PRIMARY_ROLES = ['ADMIN', 'KESISWAAN', 'KEPALA_SEKOLAH', 'GURU', 'GURU_BK'];
const today = () => new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Jakarta', year: 'numeric', month: '2-digit', day: '2-digit' }).format(new Date());
const onDate = date => ({ tanggal_mulai: { [Op.lte]: date }, [Op.or]: [{ tanggal_selesai: null }, { tanggal_selesai: { [Op.gte]: date } }] });
function allowedPlatform(role, platform) {
  return platform === 'web' ? ['ADMIN','KESISWAAN','KEPALA_SEKOLAH'].includes(role)
    : platform === 'mobile' && ['GURU','GURU_BK','SISWA','ORANG_TUA'].includes(role);
}
async function publicUser(kind, account, platform) {
  const role = kind === 'guru' ? await models.peran.findByPk(account.id_peran_utama) : null;
  const primary = kind === 'guru' ? (PRIMARY_ROLES.includes(role?.kode) ? role.kode : null) : kind.toUpperCase();
  const teacher = ['GURU','GURU_BK'].includes(primary);
  const duties = [];
  if (teacher) {
    const where = { id_guru: account.id, ...onDate(today()) };
    const [wali, pembina] = await Promise.all([models.wali.count({where}),models.pembina.count({where})]);
    if(wali) duties.push('WALI_KELAS');
    if(pembina) duties.push('PEMBINA_EKSTRAKURIKULER');
  }
  const roles = primary ? [...new Set([primary, ...(teacher ? ['GURU'] : []), ...duties])] : [];
  return { id: account.id, kind, name: account.nama, identitas_login: account.identitas_login,
    email: account.email ?? null, telepon: account.telepon ?? null,
    ...(kind === 'siswa' ? { nisn: account.nisn, nis: account.nis ?? null } : {}),
    primary_role: primary, duties, roles,
    available_roles: allowedPlatform(primary, platform) ? roles : [],
    role: primary?.toLowerCase() ?? kind, roleLabel: primary?.replaceAll('_',' ') ?? kind };
}
module.exports = { PRIMARY_ROLES, today, onDate, allowedPlatform, publicUser };
