<script setup>
import { ref } from 'vue'
import { unionApi } from '../../api/union'
import { usePage } from '../../utils/ui'
import PageHeader from '../../components/PageHeader.vue'
import AuditPanel from '../../components/AuditPanel.vue'
const creates = ref([]), dissolves = ref([]), records = ref([])
const { loading, error, load } = usePage(async () => { [creates.value, dissolves.value, records.value] = await Promise.all([unionApi.creates(), unionApi.dissolves(), unionApi.records()]) })
</script>
<template><PageHeader title="双审工作台" subtitle="认真回应每一份申请，支持校园社团的生长。" eyebrow="STUDENT UNION"><el-button @click="load" :loading="loading">刷新工作台</el-button></PageHeader><el-alert v-if="error" :title="error" type="error" /><section v-loading="loading"><el-tabs><el-tab-pane :label="`建团审批 (${creates.length})`"><AuditPanel :rows="creates" side="union" :audit="(r, result) => unionApi.audit('create', r.createApplyId, result)" @changed="load" /></el-tab-pane><el-tab-pane :label="`解散审批 (${dissolves.length})`"><AuditPanel :rows="dissolves" side="union" kind="dissolve" :audit="(r, result) => unionApi.audit('dissolve', r.dissolveApplyId, result)" @changed="load" /></el-tab-pane><el-tab-pane label="历史建团审批"><AuditPanel :rows="records" readonly /></el-tab-pane></el-tabs></section></template>
