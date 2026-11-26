const invalid = message => require('./api-error')(422, 'VALIDATION_ERROR', message);
const MINUTES = [5, 10, 15, 30, 60];
const dayWib = date => new Date(date.getTime() + 7 * 3600000).toISOString().slice(0, 10);
// Explicit windows are authoritative. Duration is retained only for old clients.
function schedule(body, day, now = new Date()) {
  const explicit = body?.qr_aktif_mulai !== undefined || body?.qr_aktif_sampai !== undefined;
  let start, end;
  if (explicit) {
    const parse = value => {
      if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?(?:Z|[+-]\d{2}:\d{2})$/.test(value)) throw invalid('Waktu QR harus berupa tanggal dan waktu dengan zona waktu.');
      const date = new Date(value);
      if (!Number.isFinite(date.getTime())) throw invalid('Waktu QR tidak valid.');
      return date;
    };
    start = parse(body.qr_aktif_mulai); end = parse(body.qr_aktif_sampai);
  } else {
    const duration = body?.berlaku_menit == null ? 15 : Number(body.berlaku_menit);
    if (!MINUTES.includes(duration)) throw invalid('Durasi QR harus 5, 10, 15, 30, atau 60 menit.');
    start = now;
    end = new Date(Math.min(now.getTime() + duration * 60000, new Date(`${day}T23:59:59.999+07:00`).getTime()));
  }
  if (dayWib(start) !== day || dayWib(end) !== day) throw invalid('Rentang QR harus berada pada tanggal sesi yang sama (WIB).');
  if (start >= end || end <= now) throw invalid('Waktu tutup harus sesudah waktu mulai dan belum terlewati.');
  return { qr_aktif_mulai: start, token_kedaluwarsa: end };
}
function state(session, now = new Date()) {
  const start = new Date(session.qr_aktif_mulai ?? session.waktu_buka);
  const end = new Date(session.token_kedaluwarsa);
  if (session.status !== 'AKTIF' || !session.token_kedaluwarsa || !Number.isFinite(start.getTime())) return 'BERAKHIR';
  if (now >= end) return 'BERAKHIR';
  return now < start ? 'TERJADWAL' : 'AKTIF';
}
module.exports = { schedule, state, MINUTES };
