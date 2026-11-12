const { DataTypes: D } = require('sequelize');
const db = require('../config/database');

const Session = db.define('AuthSession', {
  id: { type: D.STRING(36), primaryKey: true },
  jenis_akun: D.STRING(20),
  id_akun: D.INTEGER.UNSIGNED,
  platform: D.STRING(10),
  sidik_sandi: D.STRING(64),
  kedaluwarsa: D.DATE(3),
  dicabut: D.DATE(3)
}, { tableName: 'sesi_autentikasi', timestamps: false });

const RefreshToken = db.define('RefreshToken', {
  hash: { type: D.CHAR(64), primaryKey: true },
  id_sesi: D.STRING(36),
  dipakai: D.DATE(3)
}, { tableName: 'token_refresh', timestamps: false });

function revokeAccountSessions(kind, id, transaction) {
  return Session.update({ dicabut: new Date() }, {
    where: { jenis_akun: kind, id_akun: id, dicabut: null }, transaction
  });
}

module.exports = { Session, RefreshToken, revokeAccountSessions };
