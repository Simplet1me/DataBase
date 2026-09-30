<script setup>
import { ref } from 'vue'
import { clubApi } from '../../api/club'
import { useUser } from '../../stores/user'
import { usePage, action, confirm } from '../../utils/ui'
import PageHeader from '../../components/PageHeader.vue'
import AuditPanel from '../../components/AuditPanel.vue'
const store = useUser(), rows = ref([]), busy = ref(false)
const { loading, error, load } = usePage(async () => { rows.value = await clubApi.dissolves(store.clubId) })
async function submit() { busy.value = true; await action(async () => { await confirm('解散双审通过后，本社团及关联数据将被删除。确认发起解散申请？'); await clubApi.dissolve(store.clubId); await load() }, '解散申请已提交'); busy.value = false }
</script>
<template><PageHeader title="解散申请" subtitle="妥善完成每一个阶段，也是一份责任。" eyebrow="CLUB LIFECYCLE"><el-button @click="load" :loading="loading">刷新进度</el-button></PageHeader><section class="danger-panel"><h2>申请解散 {{ store.user?.club?.clubName }}</h2><p>审批期间暂停新的入社申请和活动申办。学生会与指导教师均同意后，将删除社团及关联数据，释放所有社员身份和教师指导关系。</p><el-button v-if="store.user?.club?.clubRole === 'president'" type="danger" :loading="busy" :disabled="rows.some(r => r.finalStatus === 'pending')" @click="submit">发起解散申请</el-button><p v-else class="muted">仅社长可以发起解散申请。</p></section><el-alert v-if="error" :title="error" type="error" /><h2 class="section-title">申请进度与历史</h2><AuditPanel :rows="rows" readonly kind="dissolve" /></template>
