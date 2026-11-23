const router = require('express').Router();
const { authenticate } = require('../controllers/auth.controller');
const c = require('../controllers/siswa-ekskul.controller');

router.use(authenticate, c.guard);
router.get('/ekskul', c.catalog);
router.get('/ekskul/saya', c.mine);
router.post('/ekskul/:id/daftar', c.register);
router.get('/ekskul/:id/presensi', c.history);
module.exports = router;
