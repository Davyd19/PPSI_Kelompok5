const { database } = require('./env');
const config = { ...database, dialect: 'mysql', logging: false };
module.exports = { development: config, test: config, production: config };
