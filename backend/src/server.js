const app = require('./app');
const { port, host } = require('./config/env');
const server = app.listen(port, host, () => console.log(`SIM Kesiswaan API berjalan di http://${host}:${port}/api/v1`));
server.on('error', () => { console.error('Server gagal dijalankan. Periksa port dan alamat host.'); process.exitCode = 1; });
for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, () => server.close(() => process.exit(0)));
