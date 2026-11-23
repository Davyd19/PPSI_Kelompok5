const router = require('express').Router();
const { authenticate } = require('../controllers/auth.controller');
const k = require('../controllers/kepsek.controller');

router.use(authenticate, k.guard);
router.get('/dashboard', k.dashboard);
router.get('/kasus', k.cases);
router.get('/ekskul', k.ekskul);
router.get('/laporan.csv', k.exportSummary);
module.exports = router;
