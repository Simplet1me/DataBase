<script setup>
import { reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { useUser } from '../../stores/user'
import { hashPassword } from '../../api/auth'
const store = useUser(), router = useRouter(), form = ref(), busy = ref(false)
const data = reactive({ userType: 'student', account: '', password: '' })
const rules = { account: [{ required: true, message: '请输入学号或工号', trigger: 'blur' }], password: [{ required: true, message: '请输入密码', trigger: 'blur' }] }
async function submit() {
  if (!await form.value.validate().catch(() => false)) return
  busy.value = true
  try { await store.login({ ...data, password: await hashPassword(data.password) }); await router.push(data.userType === 'teacher' ? '/teacher/workbench' : '/clubs') } catch {} finally { busy.value = false }
}
</script>
<template><div class="login-page"><section class="login-story"><div class="brand"><span class="brand-symbol">禾</span><span>青禾校园<small>CAMPUS CLUB</small></span></div><div class="login-headline"><span class="eyebrow">YOUR CAMPUS, YOUR COMMUNITY</span><h1>让热爱相遇，<br>让青春同行。</h1><p>从一次相遇，到一群同行的人。<br>在这里，找到属于你的校园生活。</p><div class="orbit-art" aria-hidden="true"><span class="orbit one"></span><span class="orbit two"></span><span class="orbit three"></span><span class="orbit-center">同好 · 同行</span></div></div><div class="login-foot">高校学生社团管理系统 <span>2026 / 青禾</span></div></section><section class="login-form-area"><div class="login-form"><span class="eyebrow">WELCOME BACK</span><h2>欢迎回到青禾</h2><p class="muted">登录，开启今天的社团日常。</p><el-form ref="form" :model="data" :rules="rules" label-position="top" size="large" @submit.prevent="submit"><el-form-item label="登录身份"><el-radio-group v-model="data.userType"><el-radio-button value="student">学生</el-radio-button><el-radio-button value="teacher">教师</el-radio-button></el-radio-group></el-form-item><el-form-item :label="data.userType === 'student' ? '学号' : '工号'" prop="account"><el-input v-model="data.account" autocomplete="username" :maxlength="20" placeholder="请输入学号 / 工号" /></el-form-item><el-form-item label="密码" prop="password"><el-input v-model="data.password" type="password" show-password autocomplete="current-password" placeholder="请输入登录密码" /></el-form-item><el-button native-type="submit" type="primary" class="login-submit" :loading="busy">登录青禾 <span>→</span></el-button></el-form><p class="login-help">账号由学校统一预置。如需帮助，请联系学生会。</p></div></section></div></template>
