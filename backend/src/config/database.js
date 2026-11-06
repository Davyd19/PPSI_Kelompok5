const {
  Sequelize
} = require('sequelize');
const {
  database
} = require('./env');
module.exports = new Sequelize(database.database, database.username, database.password, {
  host: database.host,
  port: database.port,
  dialect: 'mysql',
  logging: false,
  timezone: '+00:00',
  dialectOptions: {
    connectTimeout: 5000
  },
  pool: {
    max: 5,
    min: 0,
    idle: 10000
  }
});
