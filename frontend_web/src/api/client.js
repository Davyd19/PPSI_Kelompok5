const base = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:3000/api/v1').replace(/\/$/, '');
export async function apiGet(path, signal) {
  try {
    const response = await fetch(`${base}${path}`, { signal: signal || AbortSignal.timeout(8000) });
    const body = await response.json();
    if (!response.ok) throw new Error(body.error?.message || 'Permintaan gagal.');
    return body.data;
  } catch (error) {
    if (error.name === 'AbortError') throw error;
    if (error instanceof TypeError || error.name === 'TimeoutError') throw new Error('API tidak dapat dihubungi. Pastikan backend berjalan dan alamat API benar.');
    throw error;
  }
}
