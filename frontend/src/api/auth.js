import request from '../utils/request'
export const authApi = {
  login: data => request.post('/auth/login', data), profile: () => request.get('/auth/profile'),
  personal: () => request.get('/auth/personal'), password: data => request.put('/auth/password', data),
}
export async function hashPassword(value) {
  const bytes = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value))
  return [...new Uint8Array(bytes)].map(v => v.toString(16).padStart(2, '0')).join('')
}
