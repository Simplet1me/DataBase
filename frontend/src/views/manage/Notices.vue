<script setup>
import { ref } from 'vue'
import { clubApi } from '../../api/club'
import { useUser } from '../../stores/user'
import { usePage, action, confirm } from '../../utils/ui'
import { noticeFields } from '../../utils/columns'
import PageHeader from '../../components/PageHeader.vue'
import FormDialog from '../../components/FormDialog.vue'
const store = useUser(), rows = ref([]), open = ref(false), selected = ref(null)
const { loading, error, load } = usePage(async () => { rows.value = await clubApi.notices(store.clubId) })
function edit(row = null) { selected.value = row; open.value = true }
async function remove(row) { await action(async () => { await confirm(`确认删除「${row.noticeTitle}」？删除后将不再对外展示。`); await clubApi.deleteNotice(store.clubId, row.noticeId); await load() }) }
</script>
<template><PageHeader title="社团公告" subtitle="把重要的事，告诉每一位伙伴。" eyebrow="CLUB NOTICEBOARD"><el-button @click="load" :loading="loading">刷新</el-button><el-button type="primary" @click="edit()">发布公告 ＋</el-button></PageHeader><el-alert v-if="error" :title="error" type="error" /><div class="audit-grid" v-loading="loading"><article v-for="row in rows" :key="row.noticeId" class="panel" :class="{ 'deleted-row': row.isDeleted }"><div class="section-row"><h3>{{ row.noticeTitle }}</h3><el-tag v-if="row.isDeleted" type="info">已删除</el-tag><el-tag v-else type="success">展示中</el-tag></div><p class="body-copy">{{ row.noticeContent }}</p><time>{{ row.publishName }} · {{ row.publishTime }}</time><div v-if="!row.isDeleted" class="card-footer"><el-button @click="edit(row)">编辑</el-button><el-button type="danger" plain @click="remove(row)">删除</el-button></div></article></div><el-empty v-if="!loading && !rows.length" description="还没有发布公告" /><FormDialog v-model="open" :title="selected ? '编辑公告' : '发布公告'" :fields="noticeFields" :initial="selected" :save="data => clubApi.notice(store.clubId, data, selected?.noticeId)" @saved="load" /></template>
