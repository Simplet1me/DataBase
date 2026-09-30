import axios from 'axios'
import { ElMessage } from 'element-plus'
// 所有页面共享认证与错误处理；数据库业务提示直接展示。
const request = axios.create({ baseURL: '/api', timeout: 30000 })
request.interceptors.request.use(config => {
  const token = localStorage.getItem('club-token')
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})
request.interceptors.response.use(response => {
  const { code, message, data } = response.data
  if (code === 0) return data
  ElMessage.error(message || '请求失败')
  if (code === 401) {
    localStorage.removeItem('club-token'); localStorage.removeItem('club-user')
    window.dispatchEvent(new Event('club-unauthorized'))
  }
  return Promise.reject(Object.assign(new Error(message), { code }))
}, error => {
  ElMessage.error(error.code === 'ECONNABORTED' ? '请求超时，请稍后重试' : '连接失败，请检查后端服务是否启动')
  return Promise.reject(error)
})
export default request
