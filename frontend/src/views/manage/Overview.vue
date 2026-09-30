<script setup>
import { ref } from 'vue'
import { clubApi } from '../../api/club'
import { useUser } from '../../stores/user'
import { usePage } from '../../utils/ui'
import { memberColumns, joinColumns, activityColumns } from '../../utils/columns'
import PageHeader from '../../components/PageHeader.vue'
import DataTable from '../../components/DataTable.vue'
const store = useUser(), club = ref({}), members = ref([]), joins = ref([]), activities = ref([]), notices = ref([])
const { loading, error, load } = usePage(async () => {
  const id = store.clubId
  ;[club.value, members.value, joins.value, activities.value, notices.value] = await Promise.all([clubApi.mine(), clubApi.members(id), clubApi.joins(id), clubApi.activities(id, true), clubApi.notices(id)])
})
</script>
<template><PageHeader :title="club.clubName || '我的社团'" :subtitle="club.clubDesc" eyebrow="CLUB OVERVIEW"><el-button @click="load" :loading="loading">刷新总览</el-button></PageHeader><el-alert v-if="error" :title="error" type="error" /><div class="stats-grid"><div class="stat-card"><span>在职社员</span><strong>{{ members.length }}<small>人</small></strong></div><div class="stat-card"><span>待审入社申请</span><strong>{{ joins.length }}<small>份</small></strong></div><div class="stat-card"><span>进行中的活动</span><strong>{{ activities.filter(a => a.actStatus === 'running').length }}<small>场</small></strong></div><div class="stat-card"><span>指导教师</span><strong class="text-stat">{{ club.teaName || '—' }}</strong></div></div><section class="panel" v-loading="loading"><el-tabs><el-tab-pane label="在职社员"><DataTable :rows="members" :columns="memberColumns" /></el-tab-pane><el-tab-pane label="入社申请"><DataTable :rows="joins" :columns="joinColumns" /></el-tab-pane><el-tab-pane label="活动记录"><DataTable :rows="activities" :columns="activityColumns" /></el-tab-pane><el-tab-pane label="社团公告"><article v-for="n in notices" :key="n.noticeId" class="notice-item" :class="{ 'deleted-row': n.isDeleted }"><h3>{{ n.noticeTitle }} <el-tag v-if="n.isDeleted" type="info">已删除</el-tag></h3><p class="body-copy">{{ n.noticeContent }}</p><time>{{ n.publishTime }}</time></article><el-empty v-if="!notices.length" description="暂无公告" /></el-tab-pane></el-tabs></section></template>
