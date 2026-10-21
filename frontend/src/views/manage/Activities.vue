<script setup>
import { ref, computed } from 'vue'
import { clubApi } from '../../api/club'
import { useUser } from '../../stores/user'
import { usePage, action, confirm } from '../../utils/ui'
import { activityColumns } from '../../utils/columns'
import PageHeader from '../../components/PageHeader.vue'
import DataTable from '../../components/DataTable.vue'
import FormDialog from '../../components/FormDialog.vue'
const props = defineProps({ readonly: Boolean })
const store = useUser(), rows = ref([]), filter = ref(''), open = ref(false)
const { loading, error, load } = usePage(async () => { rows.value = await clubApi.activities(store.clubId, true) })
const canManage = computed(() => store.manager && !props.readonly)
const filtered = computed(() => rows.value.filter(r => !filter.value || r.actStatus === filter.value))
const fields = [{ key: 'actName', label: '活动名称', max: 50 }, { key: 'actDesc', label: '活动介绍', type: 'textarea', max: 10000 }, { key: 'actStartTime', label: '开始时间', type: 'datetime' }, { key: 'actEndTime', label: '结束时间', type: 'datetime' }, { key: 'actPlace', label: '活动地点' }]
async function finish(row) { await action(async () => { await confirm(`确认将「${row.actName}」标记为已结束？`); await clubApi.finish(store.clubId, row.actId); await load() }) }
</script>
<template><PageHeader :title="props.readonly ? '查看活动' : '活动管理'"><el-button @click="load" :loading="loading">刷新</el-button><el-button v-if="canManage" type="primary" @click="open = true">申办新活动</el-button></PageHeader><el-alert v-if="error" :title="error" type="error" /><section class="panel"><el-radio-group v-model="filter" class="filter-bar"><el-radio-button value="">全部活动</el-radio-button><el-radio-button value="wait_audit">待审批</el-radio-button><el-radio-button value="running">进行中</el-radio-button><el-radio-button value="finish">已结束</el-radio-button><el-radio-button value="reject">已驳回</el-radio-button></el-radio-group><DataTable :rows="filtered" :columns="activityColumns" :loading="loading"><template v-if="canManage" #default="{ row }"><el-button v-if="row.actStatus === 'running'" type="primary" link @click="finish(row)">结束活动</el-button><span v-else class="muted">{{ row.actStatus === 'wait_audit' ? '等待指导教师审批' : '流程已结束' }}</span></template></DataTable></section><FormDialog v-if="canManage" v-model="open" title="申办社团活动" :fields="fields" :save="data => clubApi.activity(store.clubId, data)" @saved="load" /></template>
