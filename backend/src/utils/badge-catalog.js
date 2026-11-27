const icons = ["medal", "trophy", "star", "school", "book", "calendar", "check", "clock", "shield", "target", "flame", "bolt", "heart", "leaf", "flag", "users", "music", "palette", "sports", "science", "globe", "rocket", "sun", "mountain"];
const sources = [{
  code: 'PRESENSI_SEKOLAH',
  label: 'Presensi sekolah',
  methods: ['AKUMULASI', 'BERUNTUN', 'PERSENTASE'],
  unit: 'sesi'
}, {
  code: 'PRESENSI_EKSKUL',
  label: 'Presensi ekstrakurikuler',
  methods: ['AKUMULASI', 'BERUNTUN', 'PERSENTASE'],
  unit: 'pertemuan'
}, {
  code: 'PRESTASI',
  label: 'Prestasi siswa',
  methods: ['AKUMULASI'],
  unit: 'prestasi'
}, {
  code: 'KEGIATAN',
  label: 'Kegiatan / portofolio',
  methods: ['AKUMULASI'],
  unit: 'kegiatan'
}, {
  code: 'KEANGGOTAAN_EKSKUL',
  label: 'Keanggotaan ekstrakurikuler',
  methods: ['AKUMULASI'],
  unit: 'ekskul berbeda'
}, {
  code: 'PELANGGARAN',
  label: 'Tanpa pelanggaran terverifikasi',
  methods: ['HARI_TANPA_PELANGGARAN'],
  unit: 'hari penuh'
}];
module.exports = {
  icons,
  sources
};
