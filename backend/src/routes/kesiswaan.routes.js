const express = require('express');
const router = express.Router();
const { authenticate } = require('../controllers/auth.controller');
const k = require('../controllers/kesiswaan.controller');
const p = require('../controllers/prestasi.controller');
const w = require('../controllers/kesiswaan-workspace.controller');
const fail = require('../utils/api-error');

router.use(authenticate, (req,res,next) => {
  if (req.authPlatform !== 'web' || req.user.primary_role !== 'KESISWAAN') {
    throw fail(403,'FORBIDDEN','Fitur ini hanya dapat diakses Kesiswaan aktif.');
  }
  res.set('Cache-Control','no-store');
  next();
});
const evidence = require('../controllers/report-evidence.controller');
router.get('/reports/:id/bukti',evidence.list);
router.post('/reports/:id/bukti',express.raw({type:['application/pdf','image/jpeg','image/png'],limit:5*1024*1024}),evidence.upload);
router.get('/bukti/:id',evidence.download);
router.get('/dashboard',k.dashboard);
router.get('/proposal-queue',w.proposalQueue);
router.get('/students',w.students);
router.get('/students/:id',w.student);
router.get('/categories/:id',w.category);
router.delete('/categories/:id',w.deleteCategory);
router.put('/categories/:id/versions/:versionId',w.version);
router.delete('/categories/:id/versions/:versionId',w.version);
router.get('/reports/:id',w.report);
router.get('/proposals/:id',w.proposal);
router.get('/lookups',k.lookups);
router.get('/categories',k.categories);
router.post('/categories',w.createCategory);
router.put('/categories/:id',k.saveCategory);
router.post('/categories/:id/versions',k.addVersion);
router.get('/reports.csv',k.exportReports);
router.get('/reports',k.reports);
router.post('/reports',k.createReport);
router.post('/reports/:id/verify',k.verify);
router.get('/attendance.csv',k.exportAttendance);
router.get('/attendance',k.attendance);
router.get('/proposals',k.proposals);
router.post('/proposals/:id/decision',k.decide);
router.get('/achievements',p.list);
router.get('/achievements/:id',p.detail);
router.put('/achievements/:id',p.update);
router.post('/achievements/:id/cancel',p.cancel);
router.post('/achievements',p.create);
router.post('/achievements/:id/attachments',express.raw({
  type:['application/pdf','image/jpeg','image/png'],limit:5*1024*1024
}),p.upload);
router.get('/attachments/:id',p.download);
module.exports = router;
