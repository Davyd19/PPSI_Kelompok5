import Icon from '../../components/Icon';

const seriesNames = { 10: 'Kelas X', 11: 'Kelas XI', 12: 'Kelas XII', lainnya: 'Kelas tidak tercatat' };
const seriesColors = { 10: '#203b60', 11: '#266679', 12: '#08634e', lainnya: '#687992' };
const count = value => Number(value).toLocaleString('id-ID');

function WeeklyChart({ trend }) {
  const groups = new Map();
  const activeSeries = new Set();
  for (const row of trend) {
    const raw = String(row.tingkat ?? '').toUpperCase();
    const level = { X: '10', XI: '11', XII: '12' }[raw] ?? (seriesNames[raw] ? raw : 'lainnya');
    if (!groups.has(row.pekan)) groups.set(row.pekan, {});
    const week = groups.get(row.pekan);
    week[level] = (week[level] ?? 0) + Number(row.total);
    activeSeries.add(level);
  }

  const series = Object.keys(seriesNames).filter(level => activeSeries.has(level));
  const weeks = [...groups.keys()].sort();
  const max = Math.max(1, ...[...groups.values()].flatMap(Object.values));
  const step = Math.ceil(max / 4);
  const ceiling = step * 4;
  const ticks = [4, 3, 2, 1, 0].map(tick => tick * step);

  return <section className="ks-panel ks-chart-panel" aria-labelledby="ks-chart-title">
    <div className="ks-panel-heading">
      <div><h2 id="ks-chart-title">Tren Pelanggaran Siswa</h2><p>Jumlah laporan per minggu dan tingkat kelas</p></div>
      <ul className="ks-legend" aria-label="Tingkat kelas">
        {series.map(level => <li key={level}><i style={{ background: seriesColors[level] }}/>{seriesNames[level]}</li>)}
      </ul>
    </div>
    {weeks.length ? <div className="ks-chart-scroll" tabIndex={0} role="region" aria-label="Grafik tren pelanggaran">
      <div className="ks-chart" style={{ minWidth: Math.max(320, weeks.length * 88 + 45) }}>
        <div className="ks-chart-grid" aria-hidden="true">{ticks.map(value => <div key={value}><span>{count(value)}</span></div>)}</div>
        <div className="ks-chart-weeks">
          {weeks.map(week => <div className="ks-chart-week" key={week}>
            <div className="ks-bars">
              {series.map(level => {
                const total = groups.get(week)[level] ?? 0;
                const description = `${week}, ${seriesNames[level]}: ${count(total)} laporan`;
                return <div className="ks-bar" key={level} role="img" aria-label={description} title={description}
                  style={{ height: `${100 * total / ceiling}%`, background: seriesColors[level] }}/>;
              })}
            </div>
            <span>{week.replace(/^(\d{4})-W(\d+)$/, 'Minggu $2 · $1')}</span>
          </div>)}
        </div>
      </div>
    </div> : <p className="ks-empty">Belum ada laporan pada periode ini.</p>}
  </section>;
}

export default function KesiswaanOverview({ data, formatTime, renderStatus, renderRows, onReview, onViewReports }) {
  const completed = data.attendance.filter(row => row.status_kehadiran !== 'BELUM_DIISI' && !row.status_kehadiran.startsWith('PENGECUALIAN'))
    .reduce((sum, row) => sum + Number(row.total), 0);
  const present = data.attendance.filter(row => ['HADIR', 'TERLAMBAT'].includes(row.status_kehadiran))
    .reduce((sum, row) => sum + Number(row.total), 0);
  const waiting = Number(data.reports.find(row => row.status_verifikasi === 'MENUNGGU')?.total ?? 0);
  const total = data.reports.reduce((sum, row) => sum + Number(row.total), 0);
  const rate = completed ? (100 * present / completed).toLocaleString('id-ID', { maximumFractionDigits: 1 }) + '%' : '—';
  const cards = [
    ['Kasus aktif', count(data.active_cases), 'shield', 'Penanganan yang masih terbuka'],
    ['Menunggu peninjauan', count(waiting), 'file', 'Laporan yang perlu diperiksa'],
    ['Laporan pada periode', count(total), 'chart', 'Seluruh status verifikasi'],
    ['Kehadiran siswa', rate, 'calendar', completed ? `${count(present)} dari ${count(completed)} presensi tercatat` : 'Belum ada presensi yang dapat dinilai'],
  ];

  return <>
    <div className="ks-cards">{cards.map(([title, value, icon, description]) => <article key={title}>
      <span>{title}</span><span className="ks-stat-icon"><Icon name={icon} size={18}/></span>
      <strong>{value}</strong><small>{description}</small>
    </article>)}</div>
    <WeeklyChart trend={data.trend}/>
    <section className="ks-panel ks-table-panel">
      <div className="ks-panel-heading">
        <div><h2>Laporan Perlu Peninjauan <span className="ks-chip">{count(waiting)} laporan</span></h2>
          <p>Antrean laporan pelanggaran yang menunggu verifikasi.</p></div>
      </div>
      {renderRows({
        headers: ['Siswa & kelas', 'Kategori pelanggaran', 'Pelapor & waktu kejadian', 'Status', 'Aksi'],
        items: data.queue,
        render: row => <><td><strong>{row.siswa}</strong><small>{row.kelas}</small></td><td>{row.kategori}</td>
          <td>{row.pelapor}<small>{formatTime(row.waktu_kejadian)}</small></td><td>{renderStatus(row.status_verifikasi)}</td>
          <td><button onClick={() => onReview(row)}>Tinjau</button></td></>,
      })}
      <footer className="ks-table-footer"><span>Menampilkan {data.queue.length} dari {count(waiting)} laporan</span>
        <button className="ks-link" onClick={onViewReports}>Lihat semua laporan <Icon name="arrow" size={15}/></button></footer>
    </section>
  </>;
}

