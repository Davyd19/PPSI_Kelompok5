import { useEffect, useState } from 'react';
import { apiRequest } from '../api/client';
import Icon from './Icon';
export default function ReportEvidence({
  id
}) {
  const [items, setItems] = useState([]),
    [error, setError] = useState(''),
    [loading, setLoading] = useState(true),
    [retry, setRetry] = useState(0);
  useEffect(() => {
    const c = new AbortController();
    apiRequest('/kesiswaan/reports/' + id + '/bukti', {
      signal: c.signal
    }).then(p => setItems(p.data)).catch(e => {
      if (e.name !== 'AbortError') setError(e.message);
    }).finally(() => {
      if (!c.signal.aborted) setLoading(false);
    });
    return () => c.abort();
  }, [id, retry]);
  async function download(item) {
    try {
      const blob = await apiRequest('/kesiswaan/bukti/' + item.id, {
        responseType: 'blob'
      });
      const url = URL.createObjectURL(blob),
        a = document.createElement('a');
      a.href = url;
      a.download = item.nama_berkas;
      a.click();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
    } catch (e) {
      setError(e.message);
    }
  }
  return <section className="ks-panel ks-form-panel"><h2>Bukti Laporan</h2>
    {loading ? <p>Memuat bukti…</p> : error ? <p role="alert">{error} <button type="button" onClick={() => {
        setError('');
        setLoading(true);
        setRetry(n => n + 1);
      }}>Coba lagi</button></p> : items.length ? items.map(item => <button type="button" key={item.id} onClick={() => download(item)}><Icon name="download" size={16} /> {item.nama_berkas}</button>) : <p>Belum ada bukti yang diunggah.</p>}
  </section>;
}
