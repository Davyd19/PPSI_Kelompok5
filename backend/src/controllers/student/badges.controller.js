'use strict';
const {ensureStudent}=require('./helpers');
exports.badges=async(req,res)=>{
 ensureStudent(req);
 const rows=await require('../../services/badges').collection(req.user.id);
 res.set('Cache-Control','no-store').json({data:rows.map(row=>({...row,kategori:row.sumber_data,category:row.sumber_data,description:row.deskripsi,verification_tag:row.diperoleh?'Diperoleh otomatis':'Dalam progres'}))});
};
