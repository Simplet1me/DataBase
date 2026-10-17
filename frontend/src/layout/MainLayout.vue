<script setup>
import { computed, ref, onMounted, onUnmounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { pages, allowed } from '../router'
import { useUser } from '../stores/user'
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
      <router-link to="/clubs" class="brand">XX大学 · 社团管理</router-link>
      <el-menu :default-active="route.path" router @select="mobile = false" aria-label="主导航">
        <el-menu-item-group v-for="(items, group) in groups" :key="group" :title="group">
          <el-menu-item v-for="item in items" :key="item.path" :index="item.path">{{ item.title }}</el-menu-item>
        </el-menu-item-group>
      </el-menu>
    </aside>
    <button v-if="mobile" class="sidebar-mask" aria-label="关闭菜单" @click="mobile = false"></button>
    <div class="main-shell">
      <header class="topbar">
        <div class="breadcrumb"><el-button class="mobile-toggle" aria-label="展开菜单" @click="mobile = !mobile">☰</el-button><span>{{ route.meta.title }}</span></div>
        <div class="user-menu"><span>{{ store.user?.name }}</span><el-button text @click="logout">退出登录</el-button></div>
      </header>
      <main class="workspace"><router-view :key="route.path + (store.clubId || '')" /></main>
    </div>
  </div>
</template>
