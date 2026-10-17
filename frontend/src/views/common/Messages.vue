<script setup>
import { ref } from 'vue'
import { messageApi } from '../../api/message'
import { usePage } from '../../utils/ui'
import PageHeader from '../../components/PageHeader.vue'
const rows = ref([])
const { loading, error, load } = usePage(async () => { rows.value = await messageApi.list() })
</script>
<template><PageHeader title="消息中心"><el-button :loading="loading" @click="load">刷新</el-button></PageHeader><el-alert v-if="error" :title="error" type="error" /><div v-loading="loading" class="message-list"><article v-for="row in rows" :key="row.msgId" class="message-card"><div><h2>{{ row.msgTitle }}</h2><p class="body-copy">{{ row.msgContent }}</p><time>{{ row.publishTime }} <span>· {{ row.publishName }} 发布</span></time></div></article></div><el-empty v-if="!loading && !rows.length" description="暂无系统消息" /></template>
