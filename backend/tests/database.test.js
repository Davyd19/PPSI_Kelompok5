const { test } = require('node:test');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const path = require('node:path');
test('explicit DB check fails safely when connection unavailable', () => {
  const result = spawnSync(process.execPath, ['src/database-check.js'], { cwd: path.join(__dirname, '..'), env: { ...process.env, DB_HOST: '127.0.0.1', DB_PORT: '1', DB_PASSWORD: 'not-to-be-printed' }, encoding: 'utf8', timeout: 15000 });
  assert.equal(result.status,1); assert.match(result.stderr,/Koneksi MySQL gagal/); assert.doesNotMatch(result.stderr,/not-to-be-printed/);
});
test('Sequelize UUID defaults and MySQL configuration load without modifying DB', async () => {
  const { DataTypes } = require('sequelize');
  const db = require('../src/config/database');
  const Probe = db.define('MemoryOnlyProbe', { id: { type: DataTypes.UUID, defaultValue: DataTypes.UUIDV4, primaryKey: true } }, { timestamps: false });
  assert.match(Probe.build().id,/^[0-9a-f-]{36}$/); assert.equal(db.getDialect(),'mysql'); await db.close();
});
