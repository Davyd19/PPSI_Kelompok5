exports.notFound = (req, res) => res.status(404).json({
  error: {
    code: 'NOT_FOUND',
    message: 'Endpoint tidak ditemukan.'
  }
});
exports.errorHandler = (error, req, res, next) => {
  if (res.headersSent) return next(error);
  if (error.name === 'SequelizeUniqueConstraintError') return res.status(409).json({
    error: {
      code: 'DUPLICATE_DATA',
      message: 'Data dengan kombinasi identitas tersebut sudah tersedia.'
    }
  });
  if (error.name === 'SequelizeForeignKeyConstraintError') return res.status(409).json({
    error: {
      code: 'DATA_IN_USE',
      message: 'Data terkait tidak ditemukan atau data masih dirujuk oleh catatan lain.'
    }
  });
  if (error.name === 'SequelizeValidationError') return res.status(422).json({
    error: {
      code: 'VALIDATION_ERROR',
      message: 'Periksa kembali isian formulir.'
    }
  });
  if (error.original?.code === 'ER_CHECK_CONSTRAINT_VIOLATED') return res.status(422).json({
    error: {
      code: 'VALIDATION_ERROR',
      message: 'Data tidak memenuhi aturan integritas.'
    }
  });
  if (error.name?.includes('Connection')) return res.status(503).json({
    error: {
      code: 'DATABASE_UNAVAILABLE',
      message: 'Database belum tersedia. Periksa konfigurasi dan migrasi.'
    }
  });
  if (error.code && Number.isInteger(error.status) && error.status >= 400 && error.status < 600) return res.status(error.status).json({
    error: {
      code: error.code,
      message: error.message,
      ...(error.details ? {
        details: error.details
      } : {})
    }
  });
  const status = error.status === 400 ? 400 : error.status === 413 ? 413 : error.status === 403 ? 403 : 500;
  const messages = {
    400: ['INVALID_JSON', 'Format JSON tidak valid.'],
    413: ['PAYLOAD_TOO_LARGE', 'Ukuran request terlalu besar.'],
    403: ['ORIGIN_NOT_ALLOWED', 'Origin web tidak diizinkan.'],
    500: ['INTERNAL_ERROR', 'Terjadi kesalahan pada server.']
  };
  const [code, message] = messages[status];
  res.status(status).json({
    error: {
      code,
      message
    }
  });
};
