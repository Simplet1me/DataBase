<script setup>
import { ref, reactive, computed } from 'vue'
import { useRouter } from 'vue-router'
import { clubApi } from '../../api/club'
import { useUser } from '../../stores/user'
import { usePage, action, confirm } from '../../utils/ui'
import { memberColumns } from '../../utils/columns'
import PageHeader from '../../components/PageHeader.vue'
import DataTable from '../../components/DataTable.vue'
const store = useUser(), router = useRouter(), rows = ref([]), history = ref([]), open = ref(false), busy = ref(false), form = ref()
const data = reactive({ demoteStuIds: [store.user.id], newPresidentStuId: '' })
const managers = computed(() => rows.value.filter(r => r.memberRole !== 'member'))
const { loading, error, load } = usePage(async () => { [rows.value, history.value] = await Promise.all([clubApi.members(store.clubId), clubApi.history(store.clubId)]) })
async function refreshIdentity() { await store.refresh(); if (!store.manager) await router.push('/me'); else await load() }
async function role(row) { await action(async () => { const newRole = row.memberRole === 'member' ? 'vice_president' : 'member'; await confirm(`确认调整 ${row.stuName} 的社团角色？`); await clubApi.role(store.clubId, { stuId: row.stuId, newRole }); await refreshIdentity() }) }
async function kick(row) { await action(async () => { await confirm(`确认将 ${row.stuName} 移出社团？`); await clubApi.kick(store.clubId, row.stuId); await refreshIdentity() }) }
async function change() {
  if (!await form.value.validate().catch(() => false)) return
  busy.value = true
  await action(async () => { await confirm('确认完成社长换届？提交后将重新计算你的社团权限。'); await clubApi.president(store.clubId, data); open.value = false; await refreshIdentity() }, '换届成功')
  busy.value = false
}
</script>
<template><PageHeader title="社员管理" subtitle="一起成长，也让每一份责任清晰有序。" eyebrow="PEOPLE & ROLES"><el-button @click="load" :loading="loading">刷新</el-button><el-button v-if="store.user?.club?.clubRole === 'president'" type="primary" @click="open = true">社长换届 ↗</el-button></PageHeader><el-alert v-if="error" :title="error" type="error" /><section class="panel"><el-tabs><el-tab-pane label="在职社员"><DataTable :rows="rows" :columns="memberColumns" :loading="loading"><template #default="{ row }"><template v-if="row.memberRole !== 'president'"><el-button link type="primary" @click="role(row)">{{ row.memberRole === 'member' ? '晋升副社长' : '降为社员' }}</el-button><el-button link type="danger" @click="kick(row)">移出社团</el-button></template><span v-else class="muted">通过换届调整</span></template></DataTable></el-tab-pane><el-tab-pane label="历史退社记录"><DataTable :rows="history" :columns="[{ key: 'stuName', label: '姓名' }, { key: 'stuId', label: '学号' }, { key: 'leaveType', label: '退社类型', status: true }, { key: 'leaveTime', label: '退社时间', width: 180 }, { key: 'operateStuId', label: '操作人' }]" /></el-tab-pane></el-tabs></section><el-dialog v-model="open" title="社长换届" width="min(560px, 94vw)"><el-alert title="请将现任社长加入降级名单，再选择新社长。任一步失败时全部回滚。" type="info" :closable="false" /><el-form ref="form" :model="data" label-position="top" class="spaced"><el-form-item label="降级为普通社员的管理层" prop="demoteStuIds" :rules="[{ required: true, type: 'array', min: 1, message: '请至少选择现任社长' }]"><el-select v-model="data.demoteStuIds" multiple style="width:100%"><el-option v-for="s in managers" :key="s.stuId" :value="s.stuId" :label="`${s.stuName} · ${s.stuId}`" /></el-select></el-form-item><el-form-item label="新社长" prop="newPresidentStuId" :rules="[{ required: true, message: '请选择新社长' }]"><el-select v-model="data.newPresidentStuId" style="width:100%"><el-option v-for="s in rows.filter(s => s.stuId !== store.user.id)" :key="s.stuId" :value="s.stuId" :label="`${s.stuName} · ${s.stuId}`" /></el-select></el-form-item></el-form><template #footer><el-button @click="open = false">取消</el-button><el-button type="primary" :loading="busy" @click="change">确认换届</el-button></template></el-dialog></template>
