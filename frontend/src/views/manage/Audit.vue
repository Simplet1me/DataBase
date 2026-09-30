<script setup>
import { ref } from 'vue'
import { clubApi } from '../../api/club'
import { useUser } from '../../stores/user'
import { usePage, action, confirm } from '../../utils/ui'
import { joinColumns } from '../../utils/columns'
import PageHeader from '../../components/PageHeader.vue'
import DataTable from '../../components/DataTable.vue'
const store = useUser(), rows = ref([]), busy = ref(false)
const { loading, error, load } = usePage(async () => { rows.value = await clubApi.joins(store.clubId) })
async function audit(row, result) { busy.value = true; await action(async () => { await confirm(`确认${result === 'agree' ? '同意' : '拒绝'} ${row.stuName} 的入社申请？`); await clubApi.auditJoin(row.applyId, result); await load() }); busy.value = false }
</script>
<template><PageHeader title="入社审批" subtitle="新的同行者，正等待你的回应。" eyebrow="JOIN REQUESTS"><el-button :loading="loading" @click="load">刷新申请</el-button></PageHeader><el-alert v-if="error" :title="error" type="error" /><div class="info-strip"><span>当前待审批 {{ rows.length }} 份</span><span>同意后，申请人将自动加入社团。</span></div><section class="panel"><DataTable :rows="rows" :columns="joinColumns" :loading="loading" empty="暂时没有待审批的入社申请"><template #default="{ row }"><el-button type="primary" size="small" :disabled="busy" @click="audit(row, 'agree')">同意</el-button><el-button type="danger" plain size="small" :disabled="busy" @click="audit(row, 'reject')">拒绝</el-button></template></DataTable></section></template>
