const {
  database
} = require('./env');
const config = {
  ...database,
  dialect: 'mysql',
  logging: false,
  timezone: '+00:00'
};
module.exports = {
  development: config,
  test: config,
  production: config
};
