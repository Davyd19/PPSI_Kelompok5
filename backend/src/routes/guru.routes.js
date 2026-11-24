const express = require('express');
const router = express.Router();
const { authenticate } = require('../controllers/auth.controller');
const guru = require('../controllers/guru.controller');

router.use(authenticate);

// Presensi sekolah
router.get('/presensi/sesi', guru.todaySessions);
router.post('/presensi/sesi', guru.openSession);
router.get('/presensi/sesi/:id/qr', guru.sessionQr);
router.post('/presensi/sesi/:id/tutup', guru.closeSession);
router.get('/presensi/sesi/:id/kelas', guru.sessionClasses);
router.get('/presensi/sesi/:id/siswa', guru.sessionStudents);
router.post('/presensi/sesi/:id/manual', guru.manualAttendance);
router.post('/presensi/sesi/:id/manual-kelas', guru.manualBatchAttendance);

// Rekap kehadiran
router.get('/presensi/kelas', guru.recapClasses);
router.get('/presensi/rekap', guru.attendanceRecap);
router.get('/presensi/rekap/siswa/:studentId', guru.studentRecapHistory);

// Laporan pelanggaran
router.get('/pelanggaran/formulir', guru.violationForm);
router.get('/pelanggaran/siswa', guru.violationStudents);
router.post('/pelanggaran', guru.submitViolation);
router.post(
  '/pelanggaran/:id/bukti',
  express.raw({ type: ['image/*', 'application/pdf', 'application/octet-stream'], limit: '10mb' }),
  guru.uploadViolationEvidence,
);
router.get('/pelanggaran', guru.myViolations);

module.exports = router;
