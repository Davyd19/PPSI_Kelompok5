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
router.get('/auth/me', auth.authenticate, auth.me);
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
