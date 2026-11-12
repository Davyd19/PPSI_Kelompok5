const { models, schema } = require('../models');

async function audit(req, key, id, before, after, action, t) {
  const row = await models.audit.create({
    id_guru: req.user?.id ?? null,
    jenis_tindakan: action,
    nama_tabel: schema[key].table,
    identitas_data: String(id),
    waktu: new Date(),
    alasan: req.body?.alasan_tindakan || null
  }, {
    transaction: t
  });
  const skip = new Set(['hash_kata_sandi', 'kata_sandi']);
  for (const name of new Set([...Object.keys(before || {}), ...Object.keys(after || {})])) {
    if (skip.has(name)) continue;
    const a = before?.[name] ?? null,
      b = after?.[name] ?? null;
    if (String(a) === String(b)) continue;
    await models.detail_audit.create({
      id_audit_perubahan: row.id,
      nama_atribut: name,
      nilai_sebelum: a == null ? null : String(a),
      nilai_sesudah: b == null ? null : String(b)
    }, {
      transaction: t
    });
  }
}
module.exports = audit;
