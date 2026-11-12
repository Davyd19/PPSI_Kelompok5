const path = require('node:path');
const fs = require('node:fs/promises');
const { randomUUID } = require('node:crypto');
const { sequelize, models } = require('../models');
const audit = require('../utils/audit');
const { id, date, string, invalid, missing } = require('./kesiswaan.controller').validation;

const directory = path.resolve(process.env.PRESTASI_UPLOAD_DIR || path.join(__dirname,'../../storage/prestasi'));
const accepted = {
  'application/pdf': data => data.subarray(0,5).toString() === '%PDF-' && data.subarray(-1024).toString().includes('%%EOF'),
  'image/jpeg': data => data[0] === 255 && data[1] === 216 && data[2] === 255 && data.at(-2) === 255 && data.at(-1) === 217,
  'image/png': data => data.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10])) &&
    data.subarray(-8,-4).toString() === 'IEND'
};
exports.list = async (req,res) => {
  const page = req.query.page ? id(req.query.page) : 1;
  if (page > 100000) throw invalid('Halaman tidak valid.');
  const rows = await models.portofolio.findAndCountAll({
    where:{jenis:'PRESTASI'}, order:[['tanggal','DESC'],['id','DESC']],limit:25,offset:(page-1)*25,
    include:[{model:models.peserta,as:'peserta_id_portofolio',separate:true,
      include:[{model:models.siswa,as:'siswa',attributes:['id','nama']}]},
      {model:models.lampiran,as:'lampiran_id_portofolio',separate:true,attributes:['id','nama_berkas','jenis_berkas']}]
  });
  res.json({data:rows.rows,meta:{total:rows.count,page,page_size:25}});
};
exports.create = async (req,res) => {
  const body = req.body || {};
  if (!Array.isArray(body.peserta) || body.peserta.length < 1 || body.peserta.length > 100) throw invalid('Pilih 1 sampai 100 siswa.');
  const ids = [...new Set(body.peserta.map(id))];
  const data = {
    id_guru_pencatat:req.user.id,jenis:'PRESTASI',judul:string(body.judul,'Judul',191),
    tanggal:date(body.tanggal,'Tanggal prestasi'),deskripsi:string(body.deskripsi,'Deskripsi',20000,true),
    tingkat_prestasi:string(body.tingkat_prestasi,'Tingkat prestasi',191),
    hasil_prestasi:string(body.hasil_prestasi,'Hasil prestasi',191),
    nama_tim:string(body.nama_tim,'Nama tim',191,ids.length===1)
  };
  const saved = await sequelize.transaction(async t => {
    if (await models.siswa.count({where:{id:ids},transaction:t}) !== ids.length) throw invalid('Peserta tidak ditemukan.');
    const row = await models.portofolio.create(data,{transaction:t});
    await models.peserta.bulkCreate(ids.map(student => ({id_portofolio:row.id,id_siswa:student})),{transaction:t});
    await audit(req,'portofolio',row.id,null,{...row.toJSON(),peserta:ids.join(',')},'CATAT_PRESTASI',t);
    return row;
  });
  res.status(201).json({data:saved});
};
exports.upload = async (req,res) => {
  const type = req.get('Content-Type')?.split(';')[0];
  if (!Object.hasOwn(accepted,type) || !Buffer.isBuffer(req.body) || !accepted[type](req.body)) throw invalid('Gunakan file PDF, JPEG, atau PNG yang valid.');
  let name;
  try { name = path.basename(decodeURIComponent(req.get('X-Filename') || 'bukti')); }
  catch { throw invalid('Nama berkas tidak valid.'); }
  name = string(name,'Nama berkas',191);
  if (/[\x00-\x1f\x7f]/.test(name)) throw invalid('Nama berkas tidak valid.');
  const key = randomUUID();
  const file = path.join(directory,key);
  await fs.mkdir(directory,{recursive:true});
  await fs.writeFile(file,req.body,{flag:'wx',mode:0o600});
  let attachment;
  try {
    attachment = await sequelize.transaction(async t => {
      const item = await models.portofolio.findByPk(id(req.params.id),{transaction:t,lock:t.LOCK.UPDATE});
      if (!item || item.jenis!=='PRESTASI') throw missing();
      const row = await models.lampiran.create({id_portofolio:item.id,nama_berkas:name,lokasi_berkas:key,jenis_berkas:type,waktu_unggah:new Date()},{transaction:t});
      await audit(req,'lampiran',row.id,null,{id_portofolio:item.id,nama_berkas:name},'UNGGAH_BUKTI',t);
      return row;
    });
  } catch(error) {
    await fs.unlink(file).catch(()=>{});
    throw error;
  }
  res.status(201).json({data:{id:attachment.id,nama_berkas:name,jenis_berkas:type}});
};
exports.download = async (req,res,next) => {
  const row = await models.lampiran.findByPk(id(req.params.id));
  if (!row || !/^[a-f0-9-]{36}$/.test(row.lokasi_berkas)) throw missing();
  const item = await models.portofolio.findByPk(row.id_portofolio);
  if (item?.jenis !== 'PRESTASI') throw missing();
  try { await fs.access(path.join(directory,row.lokasi_berkas)); } catch { throw missing(); }
  res.set('X-Content-Type-Options','nosniff').set('Cache-Control','private, no-store').type(row.jenis_berkas);
  res.download(path.join(directory,row.lokasi_berkas),row.nama_berkas,error => { if (error) next(error); });
};
