const express = require('express');
const router = express.Router();
const { authenticate } = require('../controllers/auth.controller');
const fail = require('../utils/api-error');
const presensi = require('../controllers/presensi-sekolah.controller');
const rekap = require('../controllers/rekap-kehadiran.controller');
const pelanggaran = require('../controllers/pelanggaran-guru.controller');
const profil = require('../controllers/profil-guru.controller');

router.use(authenticate);
router.use((req, res, next) => {
  if (req.authPlatform !== 'mobile' || req.user.kind !== 'guru' || !['GURU','GURU_BK'].includes(req.user.primary_role)) {
    throw fail(403, 'FORBIDDEN', 'Fitur ini hanya dapat diakses oleh Guru aktif melalui mobile.');
  }
  next();
});
router.get('/presensi/sesi', presensi.todaySessions);
router.post('/presensi/sesi', presensi.open);
router.get('/presensi/sesi/:id/qr', presensi.qr);
router.post('/presensi/sesi/:id/tutup', presensi.close);
router.get('/presensi/sesi/:id/kelas', presensi.classes);
router.get('/presensi/sesi/:id/siswa', presensi.students);
router.post('/presensi/sesi/:id/manual', presensi.manual);
router.post('/presensi/sesi/:id/manual-kelas', presensi.manualBatch);
router.post('/presensi/sesi/:id/koreksi', presensi.correct);
router.get('/presensi/kelas', rekap.classes);
router.get('/presensi/rekap', rekap.recap);
router.get('/presensi/rekap/siswa/:id', rekap.studentHistory);
router.get('/pelanggaran/formulir', pelanggaran.form);
router.get('/pelanggaran/siswa', pelanggaran.students);
router.post('/pelanggaran', pelanggaran.create);
router.post('/pelanggaran/:id/bukti', express.raw({ type: ['image/*', 'application/pdf', 'application/octet-stream'], limit: '10mb' }), pelanggaran.upload);
router.get('/pelanggaran', pelanggaran.mine);
router.get('/profil', profil.show);
router.post('/profil', profil.update);
router.post('/profil/kata-sandi', profil.changePassword);
module.exports = router;
