<script setup>
import { ref } from 'vue'
import { messageApi } from '../../api/message'
import { usePage } from '../../utils/ui'
import PageHeader from '../../components/PageHeader.vue'
const rows = ref([])
const { loading, error, load } = usePage(async () => { rows.value = await messageApi.list() })
</script>
<template><PageHeader title="消息中心" subtitle="来自学生会的校园公告，重要日常不再错过。" eyebrow="CAMPUS BULLETIN"><el-button :loading="loading" @click="load">刷新消息</el-button></PageHeader><el-alert v-if="error" :title="error" type="error" /><div v-loading="loading" class="message-list"><article v-for="(row, i) in rows" :key="row.msgId" class="message-card"><div class="message-number">{{ String(i + 1).padStart(2, '0') }}</div><div><div class="eyebrow">学生会公告</div><h2>{{ row.msgTitle }}</h2><p class="body-copy">{{ row.msgContent }}</p><time>{{ row.publishTime }} <span>· {{ row.publishName }} 发布</span></time></div></article></div><el-empty v-if="!loading && !rows.length" description="暂无系统消息" /></template>
