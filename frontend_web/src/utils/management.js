
export function statusTone(value) {
  const key = String(value ?? '').toUpperCase();
  if (['AKTIF','TERVERIFIKASI','DISETUJUI','HADIR','SELESAI','DITERIMA'].includes(key)) return 'success';
  if (['MENUNGGU','PERLU_REVISI','TERLAMBAT','DIPROSES'].includes(key)) return 'warning';
  if (['DITOLAK','NONAKTIF','ALFA','DIBATALKAN'].includes(key)) return 'danger';
  if (['IZIN','SAKIT','PENGECUALIAN_SAH','PENGECUALIAN_SAH_ZUHUR'].includes(key)) return 'info';
  return 'neutral';
}
export function sameValues(initial, current) {
  const keys = new Set([...Object.keys(initial), ...Object.keys(current)]);
  return [...keys].every(key => String(initial[key] ?? '') === String(current[key] ?? ''));
}
export function formSnapshot(form) {
  return JSON.stringify([...new FormData(form)].map(([key,value]) => [key, typeof value === 'string' ? value : value.name ? [value.name,value.size,value.lastModified] : null]));
}
