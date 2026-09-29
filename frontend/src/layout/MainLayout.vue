<script setup>
import { useRoute } from 'vue-router'

const route = useRoute()

// 侧边栏菜单项，与路由 children 一一对应
const menus = [
  { path: '/home', title: '首页', icon: 'HomeFilled' },
  { path: '/about', title: '关于', icon: 'InfoFilled' },
]
</script>

<template>
  <el-container class="layout">
    <el-aside width="200px" class="layout-aside">
      <div class="logo">DataBase</div>
      <el-menu :default-active="route.path" router class="layout-menu">
        <el-menu-item v-for="item in menus" :key="item.path" :index="item.path">
          <el-icon><component :is="item.icon" /></el-icon>
          <span>{{ item.title }}</span>
        </el-menu-item>
      </el-menu>
    </el-aside>
    <el-container>
      <el-header class="layout-header">
        <span>{{ route.meta.title }}</span>
      </el-header>
      <el-main class="layout-main">
        <router-view />
      </el-main>
    </el-container>
  </el-container>
</template>

<style scoped>
.layout {
  height: 100vh;
}

.layout-aside {
  border-right: 1px solid var(--el-border-color-light);
  background-color: #fff;
  display: flex;
  flex-direction: column;
}

.logo {
  height: 60px;
  line-height: 60px;
  text-align: center;
  font-size: 20px;
  font-weight: 600;
  color: var(--el-color-primary);
}

.layout-menu {
  border-right: none;
  flex: 1;
}

.layout-header {
  display: flex;
  align-items: center;
  border-bottom: 1px solid var(--el-border-color-light);
  background-color: #fff;
  font-size: 16px;
  font-weight: 500;
}

.layout-main {
  background-color: var(--el-fill-color-lighter);
}
</style>
