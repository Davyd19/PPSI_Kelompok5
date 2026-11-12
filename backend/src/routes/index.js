const router = require('express').Router();
const demo = require('../controllers/demo.controller');
const {
  validateRole
} = require('../validators/demo.validation');
const {
  nodeEnv
} = require('../config/env');
const auth = require('../controllers/auth.controller');
router.post('/auth/login', auth.login);
const session = require('../controllers/auth-session.controller');
router.post('/auth/refresh', session.refresh);
router.post('/auth/logout', session.logout);
router.get('/auth/me', auth.authenticate, auth.me);
router.get('/student/badges', auth.authenticate, async (req,res) => {
  if (req.authPlatform !== 'mobile' || req.user.kind !== 'siswa') {
    throw require('../utils/api-error')(403,'FORBIDDEN','Koleksi hanya tersedia untuk siswa.');
  }
  res.set('Cache-Control','no-store').json({data:await require('../services/badges').collection(req.user.id)});
});
router.use('/kesiswaan', require('./kesiswaan.routes'));
router.use('/admin', require('./admin.routes'));
router.get('/health', (req, res) => res.json({
  data: {
    status: 'ok',
    database: 'not_checked',
    simulation: true
  }
}));
// Demo dinonaktifkan pada lingkungan production; ini bukan mekanisme autentikasi.
if (nodeEnv !== 'production') {
  router.get('/demo/profiles', demo.profiles);
  router.get('/demo/dashboard', validateRole, demo.dashboard);
}
module.exports = router;
