<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { unionApi } from '../../api/union'
import { useUser } from '../../stores/user'
import { usePage, action, confirm } from '../../utils/ui'
import PageHeader from '../../components/PageHeader.vue'
import DataTable from '../../components/DataTable.vue'
import FormDialog from '../../components/FormDialog.vue'
const store = useUser(), router = useRouter(), rows = ref([]), logs = ref([]), open = ref(false)
const { loading, error, load } = usePage(async () => { [rows.value, logs.value] = await Promise.all([unionApi.members(), unionApi.logs()]) })
async function remove(row) { await action(async () => { await confirm(`确认移除学生会成员 ${row.stuName}？`); await unionApi.remove(row.stuId); await store.refresh(); if (!store.user.unionMember) await router.push('/me'); else await load() }) }
</script>
<template><PageHeader title="学生会成员" subtitle="平等协作，共同服务校园社团。" eyebrow="UNION MEMBERS"><el-button @click="load" :loading="loading">刷新</el-button><el-button type="primary" @click="open = true">新增成员 ＋</el-button></PageHeader><el-alert v-if="error" :title="error" type="error" /><div class="info-strip"><span>当前 {{ rows.length }} 位成员</span><span>所有成员权限相同，学生会至少保留一人。</span></div><section class="panel"><el-tabs><el-tab-pane label="当前成员"><DataTable :rows="rows" :loading="loading" :columns="[{ key: 'stuName', label: '姓名' }, { key: 'stuId', label: '学号' }, { key: 'joinTime', label: '加入时间', width: 180 }]"><template #default="{ row }"><el-button type="danger" link :disabled="rows.length <= 1" @click="remove(row)">移除成员</el-button></template></DataTable></el-tab-pane><el-tab-pane label="成员操作日志"><DataTable :rows="logs" :columns="[{ key: 'stuName', label: '操作对象' }, { key: 'operateType', label: '操作类型', status: true }, { key: 'operateName', label: '操作人' }, { key: 'operateTime', label: '操作时间', width: 180 }]" /></el-tab-pane></el-tabs></section><FormDialog v-model="open" title="新增学生会成员" :fields="[{ key: 'stuId', label: '学生学号', max: 20 }]" :save="data => unionApi.add(data.stuId)" @saved="load" /></template>
