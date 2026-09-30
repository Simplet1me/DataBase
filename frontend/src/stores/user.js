import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { authApi } from '../api/auth'
export const useUser = defineStore('user', () => {
  const user = ref(null), token = ref(localStorage.getItem('club-token') || '')
  const manager = computed(() => ['president', 'vice_president'].includes(user.value?.club?.clubRole))
  const clubId = computed(() => user.value?.club?.clubId)
  function save(data) { user.value = data; localStorage.setItem('club-user', JSON.stringify(data)) }
  async function login(data) {
    const result = await authApi.login(data)
    token.value = result.token; localStorage.setItem('club-token', result.token)
    const { token: ignored, ...identity } = result; save(identity)
  }
  async function refresh() { if (token.value) save(await authApi.profile()) }
  function logout() { token.value = ''; user.value = null; localStorage.removeItem('club-token'); localStorage.removeItem('club-user') }
  return { user, token, manager, clubId, login, refresh, logout }
})
