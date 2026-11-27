export function actionAppearance(label=''){
 const text=label.toLowerCase();
 if(/sandi|password/.test(text))return {icon:'key',tone:'neutral'};
 if(/hapus/.test(text))return {icon:'trash',tone:'danger'};
 if(/nonaktif|akhiri|batalkan|tolak/.test(text))return {icon:'close',tone:'danger'};
 if(/reset|filter/.test(text))return {icon:'filter',tone:'neutral'};
 if(/muat ulang|ganti/.test(text))return {icon:'refresh',tone:'neutral'};
 if(/ubah|edit|koreksi/.test(text))return {icon:'edit',tone:'neutral'};
 if(/tinjau|verifikasi/.test(text))return {icon:'shield',tone:'neutral'};
 if(/aktifkan|setujui/.test(text))return {icon:'check',tone:'success'};
 if(/unduh/.test(text))return {icon:'download',tone:'neutral'};
 if(/unggah|bukti/.test(text))return {icon:'upload',tone:'neutral'};
 if(/versi|tambah/.test(text))return {icon:'plus',tone:'neutral'};
 return {icon:'eye',tone:'neutral'};
}
