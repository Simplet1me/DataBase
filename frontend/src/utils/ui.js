import { ref, onMounted } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
// 页面加载和提交状态统一管理，失败后保留表单供用户修正。
export function usePage(loader) {
  const loading = ref(false), error = ref('')
  async function load() {
    loading.value = true; error.value = ''
    try { await loader() } catch (e) { error.value = e.message || '加载失败' } finally { loading.value = false }
  }
  onMounted(load)
  return { loading, error, load }
}
export async function action(task, message = '操作成功') {
  try { await task(); if (message) ElMessage.success(message); return true }
  catch (e) { if (e !== 'cancel' && e !== 'close' && !e?.message) console.error(e); return false }
}
export function confirm(text) { return ElMessageBox.confirm(text, '确认操作', { confirmButtonText: '确认', cancelButtonText: '取消', type: 'warning' }) }
