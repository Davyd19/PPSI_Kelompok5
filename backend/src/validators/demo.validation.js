const model = require('../models/demo.model');
exports.validateRole = (req, res, next) => {
  if (typeof req.query.role !== 'string' || !model.profiles().some(p => p.role === req.query.role)) {
    return res.status(400).json({ error: { code: 'INVALID_ROLE', message: 'Peran tidak valid.' } });
  }
  if (req.query.period !== undefined && (typeof req.query.period !== 'string' || !model.periods().includes(req.query.period))) {
    return res.status(400).json({ error: { code:'INVALID_PERIOD', message:'Periode tidak tersedia.' } });
  }
  if (req.query.grade !== undefined && (typeof req.query.grade !== 'string' || !['all','x','xi','xii'].includes(req.query.grade))) {
    return res.status(400).json({ error: { code:'INVALID_GRADE', message:'Filter tingkat kelas tidak valid.' } });
  }
  next();
};
