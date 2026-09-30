<script setup>
import { ref } from 'vue'
import { clubApi } from '../../api/club'
import { authApi, hashPassword } from '../../api/auth'
import { useUser } from '../../stores/user'
import { usePage, action, confirm } from '../../utils/ui'
import PageHeader from '../../components/PageHeader.vue'
import DataTable from '../../components/DataTable.vue'
import StatusTag from '../../components/StatusTag.vue'
import AuditPanel from '../../components/AuditPanel.vue'
import FormDialog from '../../components/FormDialog.vue'
const store = useUser(), records = ref([]), joins = ref([]), creates = ref([]), logs = ref([]), activities = ref([]), personal = ref({}), passwordOpen = ref(false)
const { loading, error, load } = usePage(async () => {
  await store.refresh()
  ;[records.value, joins.value, creates.value, logs.value, personal.value] = await Promise.all([clubApi.records(), clubApi.myJoins(), clubApi.creates(), clubApi.logs(), authApi.personal()])
  activities.value = store.clubId ? await clubApi.activities(store.clubId) : []
})
async function quit() { await action(async () => { await confirm('退出后立即解除社团身份，确认退出当前社团？'); await clubApi.quit(); await load() }) }
async function savePassword(data) { await authApi.password({ oldPassword: await hashPassword(data.old), newPassword: await hashPassword(data.next) }) }
const recordCols = [{ key: 'clubName', label: '社团' }, { key: 'memberRole', label: '角色', status: true }, { key: 'joinTime', label: '入社时间', width: 180 }, { key: 'leaveTime', label: '退社时间', width: 180 }, { key: 'leaveType', label: '退社类型', status: true }]
const activityCols = [{ key: 'actName', label: '活动' }, { key: 'actPlace', label: '地点' }, { key: 'actStartTime', label: '开始时间', width: 180 }, { key: 'actEndTime', label: '结束时间', width: 180 }, { key: 'actStatus', label: '状态', status: true }]
</script>
<template><PageHeader :title="`你好，${store.user?.name}`" subtitle="你的社团足迹，每一次参与都有记录。" eyebrow="MY CAMPUS"><el-button @click="passwordOpen = true">修改密码</el-button><el-button @click="load" :loading="loading">刷新</el-button></PageHeader><el-alert v-if="error" :title="error" type="error" /><section class="profile-card panel"><span class="profile-avatar">{{ store.user?.name?.slice(-1) }}</span><div><h2>{{ store.user?.name }} <el-tag v-if="store.user?.unionMember" type="success">学生会成员</el-tag></h2><p class="muted">{{ store.user?.id }} · {{ personal.stuClass }} · {{ personal.stuPhone }}</p><p v-if="store.user?.club">{{ store.user.club.clubName }} <StatusTag :value="store.user.club.clubRole" /></p><p v-else class="muted">尚未加入社团，去发现感兴趣的伙伴吧。</p></div><div class="profile-actions"><el-button v-if="store.clubId" type="danger" plain @click="quit">退出社团</el-button><router-link v-else to="/clubs"><el-button type="primary">探索社团 ↗</el-button></router-link></div></section><section class="panel" v-loading="loading"><el-tabs><el-tab-pane label="社团档案"><DataTable :rows="records" :columns="recordCols" /></el-tab-pane><el-tab-pane label="入社申请"><DataTable :rows="joins" :columns="[{ key: 'clubName', label: '申请社团' }, { key: 'applyStatus', label: '审批状态', status: true }, { key: 'applyTime', label: '申请时间', width: 180 }, { key: 'replyTime', label: '回复时间', width: 180 }]" /></el-tab-pane><el-tab-pane label="建团进度"><AuditPanel :rows="creates" readonly /></el-tab-pane><el-tab-pane label="角色变更"><DataTable :rows="logs" :columns="[{ key: 'clubName', label: '社团' }, { key: 'oldRole', label: '原角色', status: true }, { key: 'newRole', label: '新角色', status: true }, { key: 'operateName', label: '操作人' }, { key: 'changeTime', label: '时间', width: 180 }]" /></el-tab-pane><el-tab-pane label="本社活动"><DataTable :rows="activities" :columns="activityCols" /></el-tab-pane></el-tabs></section><FormDialog v-model="passwordOpen" title="修改登录密码" :fields="[{ key: 'old', label: '原密码', type: 'password' }, { key: 'next', label: '新密码', type: 'password' }]" :save="savePassword" /></template>
