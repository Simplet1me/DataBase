<script setup>
import { reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { clubApi } from '../../api/club'
import { useUser } from '../../stores/user'
import { usePage, action } from '../../utils/ui'
import PageHeader from '../../components/PageHeader.vue'
const store = useUser(), router = useRouter(), form = ref(), teachers = ref([]), busy = ref(false)
const data = reactive({ clubName: '', clubDesc: '', applyTeaId: '', stuIds: [store.user.id, '', '', '', ''] })
const { loading, error } = usePage(async () => { teachers.value = await clubApi.freeTeachers() })
const required = [{ required: true, message: '请填写此项', trigger: 'blur' }]
async function submit() {
  if (!await form.value.validate().catch(() => false)) return
  busy.value = true
  await action(async () => { await clubApi.create(data); await router.push('/me') }, '建团申请已提交')
  busy.value = false
}
</script>
<template><PageHeader title="发起建团" /><el-alert v-if="store.clubId" title="你已加入社团，退出后才能参与新的建团申请。" type="warning" show-icon :closable="false" /><el-alert v-if="error" :title="error" type="error" /><div class="create-layout"><section class="panel" v-loading="loading"><el-form ref="form" :model="data" label-position="top" :disabled="!!store.clubId" @submit.prevent="submit"><h3>社团信息</h3><el-form-item label="社团名称" prop="clubName" :rules="required"><el-input v-model="data.clubName" maxlength="50" placeholder="请输入社团名称" /></el-form-item><el-form-item label="社团简介" prop="clubDesc" :rules="required"><el-input v-model="data.clubDesc" type="textarea" :rows="5" maxlength="10000" show-word-limit placeholder="请输入社团简介" /></el-form-item><el-form-item label="指导教师" prop="applyTeaId" :rules="required"><el-select v-model="data.applyTeaId" placeholder="选择一位空闲指导教师" style="width:100%"><el-option v-for="t in teachers" :key="t.teaId" :label="`${t.teaName} · ${t.teaId}`" :value="t.teaId" /></el-select></el-form-item><h3>发起人</h3><el-alert title="需五名不同且未加入社团的学生。" type="info" :closable="false" /><div class="founder-grid"><el-form-item v-for="(_, i) in data.stuIds" :key="i" :label="`${i + 1}. ${i === 0 ? '社长（本人）' : i < 3 ? '副社长' : '普通社员'}`" :prop="`stuIds.${i}`" :rules="required"><el-input v-model="data.stuIds[i]" :disabled="i === 0" maxlength="20" placeholder="填写学号" /></el-form-item></div><el-button type="primary" native-type="submit" :loading="busy">提交申请</el-button></el-form></section></div></template>
