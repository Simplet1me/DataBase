<script setup>
import { ref } from 'vue'
import StatusTag from './StatusTag.vue'
import { action, confirm } from '../utils/ui'
const props = defineProps({ rows: Array, side: String, kind: { type: String, default: 'create' }, audit: Function, readonly: Boolean })
const emit = defineEmits(['changed'])
const busy = ref(false)
async function decide(row, result) {
  if (busy.value) return
  busy.value = true
  await action(async () => { await confirm(`确认${result === 'agree' ? '同意' : '驳回'}「${row.clubName}」的申请？`); await props.audit(row, result); emit('changed') })
  busy.value = false
}
</script>
<template><el-empty v-if="!rows?.length" description="暂无申请记录" /><div v-else class="audit-grid"><article v-for="row in rows" :key="row.createApplyId || row.dissolveApplyId" class="panel audit-card"><div class="section-row"><h3>{{ row.clubName }}</h3><StatusTag :value="row.finalStatus" /></div><p class="body-copy">{{ row.clubDesc || `申请人：${row.applyStuName || row.applyStuId}` }}</p><p v-if="row.applyTeaName" class="muted">指导教师：{{ row.applyTeaName }}</p><div v-if="row.initiators" class="initiators"><span v-for="s in row.initiators" :key="s.stuId">{{ s.stuName }} <small>{{ s.stuId }}</small></span></div><div class="approval-track"><div><small>01 学生会审批</small><StatusTag :value="row.unionAuditStatus" /><small>{{ row.unionAuditName || row.unionAuditStuId }} {{ row.unionAuditTime }}</small></div><span>→</span><div><small>02 指导教师审批</small><StatusTag :value="row.teaAuditStatus" /><small>{{ row.teaAuditTime }}</small></div></div><div class="section-row"><time>{{ row.applyTime }}</time><div v-if="!readonly && row.finalStatus === 'pending' && row[`${side}AuditStatus`] === 'pending'"><el-button :disabled="busy" type="danger" plain @click="decide(row, 'reject')">驳回</el-button><el-button :disabled="busy" type="primary" @click="decide(row, 'agree')">同意</el-button></div></div></article></div></template>
