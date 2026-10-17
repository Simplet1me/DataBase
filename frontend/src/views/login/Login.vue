<script setup>
import { reactive, ref } from "vue";
import { useRouter } from "vue-router";
import { useUser } from "../../stores/user";
import { hashPassword } from "../../api/auth";
const store = useUser(),
  router = useRouter(),
  form = ref(),
  busy = ref(false);
const data = reactive({ userType: "student", account: "", password: "" });
const rules = {
  account: [{ required: true, message: "请输入学号或工号", trigger: "blur" }],
  password: [{ required: true, message: "请输入密码", trigger: "blur" }],
};
async function submit() {
  if (!(await form.value.validate().catch(() => false))) return;
  busy.value = true;
  try {
    await store.login({ ...data, password: await hashPassword(data.password) });
    await router.push(
      data.userType === "teacher" ? "/teacher/workbench" : "/clubs",
    );
  } catch {
  } finally {
    busy.value = false;
  }
}
</script>
<template>
  <div class="login-page">

    <section class="login-form-area">
      <div class="login-form">

        <h2>高校学生社团管理系统</h2>
        <el-form ref="form" :model="data" :rules="rules" label-position="top" size="large"
          @submit.prevent="submit"><el-form-item label="登录身份"><el-radio-group v-model="data.userType"><el-radio-button
                value="student">学生</el-radio-button><el-radio-button
                value="teacher">教师</el-radio-button></el-radio-group></el-form-item><el-form-item
            :label="data.userType === 'student' ? '学号' : '工号'" prop="account"><el-input v-model="data.account"
              autocomplete="username" :maxlength="20" placeholder="请输入学号 / 工号" /></el-form-item><el-form-item label="密码"
            prop="password"><el-input v-model="data.password" type="password" show-password
              autocomplete="current-password" placeholder="请输入登录密码" /></el-form-item><el-button native-type="submit"
            type="primary" class="login-submit" :loading="busy">登录</el-button></el-form>
      </div>
    </section>
  </div>
</template>
