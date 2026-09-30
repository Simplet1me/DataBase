<script setup>
import { ref } from 'vue'
import { messageApi } from '../../api/message'
import { usePage, action, confirm } from '../../utils/ui'
import { messageFields } from '../../utils/columns'
import PageHeader from '../../components/PageHeader.vue'
import FormDialog from '../../components/FormDialog.vue'
const rows = ref([]), open = ref(false), selected = ref(null)
const { loading, error, load } = usePage(async () => { rows.value = await messageApi.list() })
function edit(row = null) { selected.value = row; open.value = true }
async function remove(row) { await action(async () => { await confirm(`确认删除「${row.msgTitle}」？`); await messageApi.remove(row.msgId); await load() }) }
</script>
<template><PageHeader title="系统消息管理" subtitle="用清晰的公告，把校园日常连接起来。" eyebrow="CAMPUS COMMUNICATION"><el-button @click="load" :loading="loading">刷新</el-button><el-button type="primary" @click="edit()">发布消息 ＋</el-button></PageHeader><el-alert v-if="error" :title="error" type="error" /><div class="audit-grid" v-loading="loading"><article v-for="row in rows" :key="row.msgId" class="panel"><h3>{{ row.msgTitle }}</h3><p class="body-copy">{{ row.msgContent }}</p><time>{{ row.publishName }} · {{ row.publishTime }}</time><div class="card-footer"><el-button @click="edit(row)">编辑</el-button><el-button type="danger" plain @click="remove(row)">删除</el-button></div></article></div><el-empty v-if="!loading && !rows.length" description="暂无系统消息" /><FormDialog v-model="open" :title="selected ? '编辑系统消息' : '发布系统消息'" :fields="messageFields" :initial="selected" :save="data => messageApi.save(data, selected?.msgId)" @saved="load" /></template>
