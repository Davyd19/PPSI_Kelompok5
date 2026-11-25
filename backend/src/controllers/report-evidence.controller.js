const fs = require('node:fs/promises');
const path = require('node:path');
const { models } = require('../models');
const fail = require('../utils/api-error');
const directories = [...new Set([
  path.resolve(process.env.PELANGGARAN_UPLOAD_DIR || path.join(__dirname,'../../storage/pelanggaran')),
  path.resolve(process.env.REPORT_UPLOAD_DIR || path.join(__dirname,'../../storage/reports'))
])];
// Independent authorization in addition to router authentication: never callable by other roles/platforms.
function requireKesiswaan(req) {
  if(req.authPlatform !== 'web' || req.user?.kind !== 'guru' || req.user?.primary_role !== 'KESISWAAN' || !Number.isInteger(req.user.id)) {
    throw fail(403,'FORBIDDEN','Bukti laporan hanya dapat dibaca Kesiswaan aktif melalui web.');
  }
  if(!/^[1-9][0-9]*$/.test(String(req.params.id))) throw fail(422,'VALIDATION_ERROR','Identitas bukti tidak valid.');
}
exports.list = async (req,res) => {
  requireKesiswaan(req);
  const report = await models.laporan.findByPk(req.params.id);
  if(!report) throw fail(404,'NOT_FOUND','Laporan tidak ditemukan.');
  res.set('Cache-Control','private,no-store').json({data:await models.lampiran_laporan.findAll({where:{id_laporan_pelanggaran:report.id},attributes:['id','nama_berkas','jenis_berkas','waktu_unggah']})});
};
exports.download = async(req,res,next) => {
  requireKesiswaan(req);
  const item = await models.lampiran_laporan.findByPk(req.params.id);
  const report = item && await models.laporan.findByPk(item.id_laporan_pelanggaran);
  if(!report || !/^[a-f0-9-]{36}$/.test(item.lokasi_berkas)) throw fail(404,'NOT_FOUND','Bukti tidak ditemukan.');
  let file;
  for(const directory of directories){
    const candidate=path.join(directory,item.lokasi_berkas);
    try {await fs.access(candidate);file=candidate;break;} catch(error){if(error.code!=='ENOENT')throw error;}
  }
  if(!file)throw fail(404,'NOT_FOUND','Berkas tidak ditemukan.');
  res.set('Cache-Control','private,no-store').set('X-Content-Type-Options','nosniff').download(file,item.nama_berkas,error=>{if(error)next(error);});
};
