const { sequelize } = require('./models');
const { reconcile } = require('./services/badges');
reconcile().then(result => {
  console.log(result.skipped ? 'Penghitungan badge sedang dijalankan.' : `${result.changed} pencapaian badge diperbarui.`);
}).catch(error => {
  console.error('Penghitungan badge gagal.',error.original?.code || error.name);
  process.exitCode = 1;
}).finally(() => sequelize.close());
