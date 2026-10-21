<script setup>
import { computed, ref, onMounted, onUnmounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { pages, allowed } from '../router'
import { useUser } from '../stores/user'
import { School, Grid, Bell, User, Plus, DataAnalysis, UserFilled, Checked, Calendar, Document, CircleClose, Stamp, Setting, ChatDotRound, Reading } from '@element-plus/icons-vue'
const menuIcons = {
  '/clubs': Grid, '/messages': Bell, '/me': User, '/club/create': Plus,
  '/club/activities': Calendar, '/club/notices': Document,
  '/manage/overview': DataAnalysis, '/manage/members': UserFilled, '/manage/audit': Checked,
  '/manage/activities': Calendar, '/manage/notices': Document, '/manage/dissolve': CircleClose,
  '/union/audit': Stamp, '/union/members': Setting, '/union/messages': ChatDotRound,
  '/teacher/workbench': Reading,
}
const route = useRoute(), router = useRouter(), store = useUser(), mobile = ref(false)
const groups = computed(() => {
  const result = {}
  for (const page of pages.filter(p => allowed(p.role, store))) (result[page.group] ||= []).push(page)
  return result
})
function logout() { store.logout(); router.push('/login') }
async function refresh() { try { await store.refresh(); if (!allowed(route.meta.role, store)) router.replace('/clubs') } catch { } }
onMounted(() => window.addEventListener('focus', refresh))
onUnmounted(() => window.removeEventListener('focus', refresh))
</script>
<template>
  <div class="app-shell">
    <aside class="sidebar" :class="{ 'is-open': mobile }">
      <router-link to="/clubs" class="brand"><el-icon class="brand-icon" aria-hidden="true"><School /></el-icon><span>XX大学 · 社团管理</span></router-link>
      <el-menu :default-active="route.path" router @select="mobile = false" aria-label="主导航">
        <el-menu-item-group v-for="(items, group) in groups" :key="group" :title="group">
          <el-menu-item v-for="item in items" :key="item.path" :index="item.path"><el-icon aria-hidden="true"><component :is="menuIcons[item.path]" /></el-icon><span>{{ item.title }}</span></el-menu-item>
        </el-menu-item-group>
      </el-menu>
    </aside>
    <button v-if="mobile" class="sidebar-mask" aria-label="关闭菜单" @click="mobile = false"></button>
    <div class="main-shell">
      <header class="topbar">
        <div class="breadcrumb"><el-button class="mobile-toggle" aria-label="展开菜单" @click="mobile = !mobile">☰</el-button><span>{{ route.meta.title }}</span></div>
        <div class="user-menu"><el-avatar :size="30" class="user-avatar" aria-hidden="true">{{ store.user?.name?.slice(-1) }}</el-avatar><span>{{ store.user?.name }}</span><el-button text @click="logout">退出登录</el-button></div>
      </header>
      <main class="workspace"><router-view :key="route.path + (store.clubId || '')" /></main>
    </div>
  </div>
</template>
