const {
  DataTypes
} = require('sequelize');
const sequelize = require('../config/database');
const schema = require('./schema.json');
function column(f) {
  const types = {
    id: DataTypes.INTEGER.UNSIGNED,
    integer: DataTypes.INTEGER,
    string: DataTypes.STRING(191),
    text: DataTypes.TEXT,
    date: DataTypes.DATEONLY,
    datetime: DataTypes.DATE(3),
    time: DataTypes.TIME,
    boolean: DataTypes.BOOLEAN
  };
  return {
    type: types[f.type],
    allowNull: f.nullable,
    ...(f.defaultValue !== undefined ? { defaultValue:f.defaultValue } : {})
  };
}
const models = {};
for (const [key, spec] of Object.entries(schema)) {
  const attributes = {
    id: {
      type: DataTypes.INTEGER.UNSIGNED,
      primaryKey: true,
      autoIncrement: true
    }
  };
  for (const f of spec.fields) attributes[f.name] = column(f);
  models[key] = sequelize.define(spec.name, attributes, {
    tableName: spec.table,
    timestamps: false,
    defaultScope: {
      attributes: {
        exclude: ['hash_kata_sandi']
      }
    },
    indexes: spec.unique.map((fields, i) => ({
      unique: true,
      fields,
      name: `uq_${key}_${i + 1}`
    }))
  });
}
for (const [key, spec] of Object.entries(schema)) for (const f of spec.fields.filter(f => f.ref)) {
  models[key].belongsTo(models[f.ref], {
    as: f.name.slice(3),
    foreignKey: f.name,
    onDelete: 'RESTRICT',
    onUpdate: 'RESTRICT'
  });
  models[f.ref].hasMany(models[key], {
    as: `${key}_${f.name}`,
    foreignKey: f.name,
    onDelete: 'RESTRICT',
    onUpdate: 'RESTRICT'
  });
}
module.exports = {
  sequelize,
  models,
  schema,
  column
};
