const path = require('node:path');
require('dotenv').config({ path: path.resolve(__dirname, '../../.env'), quiet: true });
function port(value, name) {
  const number = Number(value);
  if (!Number.isInteger(number) || number < 1 || number > 65535) throw new Error(`${name} harus berupa port 1–65535.`);
  return number;
}
const nodeEnv = process.env.NODE_ENV || 'development';
if (!['development', 'test', 'production'].includes(nodeEnv)) throw new Error('NODE_ENV tidak valid.');
const origins = (process.env.CORS_ORIGINS || 'http://localhost:5173,http://127.0.0.1:5173').split(',').map(s => s.trim()).filter(Boolean);
for (const origin of origins) {
  let parsed;
  try { parsed = new URL(origin); } catch { throw new Error('CORS_ORIGINS harus berisi origin HTTP/HTTPS.'); }
  if (!['http:', 'https:'].includes(parsed.protocol) || parsed.origin !== origin) throw new Error('CORS_ORIGINS harus berisi origin tanpa path.');
}
module.exports = {
  nodeEnv, port: port(process.env.PORT || 3000, 'PORT'), host: process.env.HOST || '0.0.0.0', origins,
  database: { host: process.env.DB_HOST || '127.0.0.1', port: port(process.env.DB_PORT || 3306, 'DB_PORT'),
    database: process.env.DB_NAME || 'sim_kesiswaan_dev', username: process.env.DB_USER || 'sim_kesiswaan', password: process.env.DB_PASSWORD || '' },
};
