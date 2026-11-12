const express = require('express');
const router = express.Router();
const { authenticate } = require('../controllers/auth.controller');
const k = require('../controllers/kesiswaan.controller');
const p = require('../controllers/prestasi.controller');
const fail = require('../utils/api-error');

router.use(authenticate, (req,res,next) => {
  if (req.authPlatform !== 'web' || !req.user.available_roles.includes('KESISWAAN')) {
    throw fail(403,'FORBIDDEN','Fitur ini hanya dapat diakses Kesiswaan aktif.');
  }
  res.set('Cache-Control','no-store');
  next();
});
router.get('/dashboard',k.dashboard);
router.get('/lookups',k.lookups);
router.get('/categories',k.categories);
router.post('/categories',k.saveCategory);
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
router.post('/achievements',p.create);
router.post('/achievements/:id/attachments',express.raw({
  type:['application/pdf','image/jpeg','image/png'],limit:5*1024*1024
}),p.upload);
router.get('/attachments/:id',p.download);
module.exports = router;
