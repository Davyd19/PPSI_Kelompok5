const express = require('express');
const cors = require('cors');
const { origins } = require('./config/env');
const { notFound, errorHandler } = require('./middleware/errors');
const app = express();
app.disable('x-powered-by');
app.use(cors({ origin(origin, callback) {
  if (!origin || origins.includes(origin)) return callback(null, true);
  callback(Object.assign(new Error('Origin denied'), { status: 403 }));
} }));
app.use(express.json({ limit: '100kb' }));
app.use('/api/v1', require('./routes'));
app.use(notFound);
app.use(errorHandler);
module.exports = app;
