// Snapshot migrasi tidak mengikuti perubahan model berikutnya.
const {schema, checks} = require('./20261105000100-schema.json');
module.exports = {
  async up(q, S) {
    // MySQL DDL commits implicitly: run on an empty database; never use sync/alter.
    for (const [key, spec] of Object.entries(schema)) {
      const cols = {
        id: {
          type: S.INTEGER.UNSIGNED,
          primaryKey: true,
          autoIncrement: true,
          allowNull: false
        }
      };
      const types = {
        id: S.INTEGER.UNSIGNED,
        integer: S.INTEGER,
        string: S.STRING(191),
        text: S.TEXT,
        date: S.DATEONLY,
        datetime: S.DATE(3),
        time: S.TIME,
        boolean: S.BOOLEAN
      };
      for (const f of spec.fields) cols[f.name] = {
        type: types[f.type],
        allowNull: f.nullable
      };
      await q.createTable(spec.table, cols, {
        engine: 'InnoDB',
        charset: 'utf8mb4',
        collate: 'utf8mb4_unicode_ci'
      });
      for (const [i, fields] of spec.unique.entries()) await q.addIndex(spec.table, fields, {
        unique: true,
        name: `uq_${key}_${i + 1}`
      });
      for (const f of spec.fields.filter(f => f.ref)) await q.addIndex(spec.table, [f.name], {
        name: `ix_${key}_${f.name}`.slice(0, 64)
      });
      if (spec.fields.some(f => f.name === 'nama')) await q.addIndex(spec.table, ['nama'], {
        name: `ix_${key}_nama`
      });
    }
    for (const [key, spec] of Object.entries(schema)) for (const f of spec.fields.filter(f => f.ref)) await q.addConstraint(spec.table, {
      fields: [f.name],
      type: 'foreign key',
      name: `fk_${key}_${f.name}`.slice(0, 64),
      references: {
        table: schema[f.ref].table,
        field: 'id'
      },
      onDelete: 'RESTRICT',
      onUpdate: 'RESTRICT'
    });
    for (const [key, cs] of Object.entries(checks)) for (const [name, sql] of cs) await q.sequelize.query(`ALTER TABLE \`${schema[key].table}\` ADD CONSTRAINT \`${key}_${name}\` CHECK (${sql})`);
  },
  async down(q) {
    for (const [key, spec] of Object.entries(schema)) for (const f of spec.fields.filter(f => f.ref)) await q.removeConstraint(spec.table, `fk_${key}_${f.name}`.slice(0, 64));
    for (const spec of Object.values(schema).reverse()) await q.dropTable(spec.table);
  }
};
