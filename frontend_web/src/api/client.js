const base = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:3000/api/v1').replace(/\/$/, '');
let accessToken = null;
export function setAccessToken(value) {
  accessToken = value;
}
export async function apiRequest(path, {
  method = 'GET',
  body,
  signal, headers = {}, responseType
} = {}) {
  try {
    const raw = body instanceof Blob;
    const response = await fetch(`${base}${path}`, {
      method,
      headers: {
        ...(body !== undefined && !raw ? {
          'Content-Type': 'application/json'
        } : {}),
        ...(accessToken ? {
          Authorization: `Bearer ${accessToken}`
        } : {}),
        ...headers
      },
      body: body === undefined || raw ? body : JSON.stringify(body),
      signal: signal || AbortSignal.timeout(15000)
    });
    if (response.status === 204) return {};
    if (response.ok && responseType === 'blob') return response.blob();
    const payload = await response.json();
    if (!response.ok) {
      if (response.status === 401 && path !== '/auth/login') window.dispatchEvent(new Event('sim-session-expired'));
      const error = new Error(payload.error?.message || 'Permintaan gagal.');
      error.status = response.status;
      error.details = payload.error?.details;
      throw error;
    }
    return payload;
  } catch (error) {
    if (error instanceof TypeError || error.name === 'TimeoutError') throw new Error('API tidak dapat dihubungi. Periksa koneksi dan server.');
    throw error;
  }
}
export async function apiGet(path, signal) {
  try {
    const response = await fetch(`${base}${path}`, {
      signal: signal || AbortSignal.timeout(8000)
    });
    const body = await response.json();
    if (!response.ok) throw new Error(body.error?.message || 'Permintaan gagal.');
    return body.data;
  } catch (error) {
    if (error.name === 'AbortError') throw error;
    if (error instanceof TypeError || error.name === 'TimeoutError') throw new Error('API tidak dapat dihubungi. Pastikan backend berjalan dan alamat API benar.');
    throw error;
  }
}
