exports.notFound = (req, res) => res.status(404).json({ error: { code: 'NOT_FOUND', message: 'Endpoint tidak ditemukan.' } });
exports.errorHandler = (error, req, res, next) => {
  if (res.headersSent) return next(error);
  const status = error.status === 400 ? 400 : error.status === 413 ? 413 : error.status === 403 ? 403 : 500;
  const messages = { 400: ['INVALID_JSON', 'Format JSON tidak valid.'], 413: ['PAYLOAD_TOO_LARGE', 'Ukuran request terlalu besar.'], 403: ['ORIGIN_NOT_ALLOWED', 'Origin web tidak diizinkan.'], 500: ['INTERNAL_ERROR', 'Terjadi kesalahan pada server.'] };
  const [code, message] = messages[status];
  res.status(status).json({ error: { code, message } });
};
