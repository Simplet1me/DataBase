<script setup>
import { ElMessage } from 'element-plus'

const handleClick = () => {
  ElMessage.success('Element Plus 组件运行正常')
}
</script>

<template>
  <el-card>
    <template #header>欢迎</template>
    <p>Vue 3 + Vite + Element Plus 基础框架已就绪。</p>
    <el-space>
      <el-button type="primary" @click="handleClick">主要按钮</el-button>
      <el-button type="success">成功按钮</el-button>
      <el-button type="info">信息按钮</el-button>
    </el-space>
  </el-card>
</template>
