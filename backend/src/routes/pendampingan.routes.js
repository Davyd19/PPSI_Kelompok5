const { authenticate } = require('../controllers/auth.controller');
const c = require('../controllers/pendampingan.controller');
module.exports = role => {
  const router = require('express').Router();
  router.use(authenticate, c.guard(role));
  router.get('/kasus', c.list);
  router.get('/kasus/:id', c.detail);
  if (role === 'GURU_BK') {
    router.post('/kasus/:id/verifikasi', c.verify);
    router.get('/kasus/:id/rencana-konseling', c.plan);
    router.post('/kasus/:id/rencana-konseling', c.savePlan);
  }
  const actions = role === 'GURU_BK' ? ['catatan-konseling', 'eskalasi', 'tutup'] : ['catatan-pembinaan', 'usulan'];
  for (const action of [...actions, 'tindak-lanjut-ortu', 'pemantauan', 'tindak-lanjut']) router.post(`/kasus/:id/${action}`, c.record(action));
  return router;
};
