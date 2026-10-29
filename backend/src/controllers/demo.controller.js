const demo = require('../models/demo.model');
exports.profiles = (req, res) => res.json({ data: demo.profiles() });
exports.dashboard = (req, res) => res.json({ data: demo.dashboard(req.query.role, req.query.period, req.query.grade) });
