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
      <router-link to="/clubs" class="brand"><span
          class="brand-symbol"></span><span>XX大学<small>学生社团管理系统</small></span></router-link>
      <nav aria-label="主导航">
        <section v-for="(items, group) in groups" :key="group" class="nav-group">
          <div class="nav-label">{{ group }}</div><router-link v-for="item in items" :key="item.path" :to="item.path"
            @click="mobile = false"><span class="nav-dot"></span>{{ item.title }}<span
              class="nav-arrow">↗</span></router-link>
        </section>
      </nav>
      <div class="sidebar-note"><span class="live-dot"></span> 让热爱，在校园发生<small>CAMPUS CLUB / 2026</small></div>
    </aside>
    <button v-if="mobile" class="sidebar-mask" aria-label="关闭菜单" @click="mobile = false"></button>
    <div class="main-shell">
      <header class="topbar">
        <div class="breadcrumb"><button class="mobile-toggle" aria-label="展开菜单"
            @click="mobile = !mobile">☰</button><span>XX大学</span><span class="slash">/</span><strong>{{ route.meta.title
            }}</strong></div>
        <div class="user-menu"><router-link to="/messages" class="top-message">消息中心</router-link><span class="avatar">{{
          store.user?.name?.slice(-1) }}</span>
          <div><strong>{{ store.user?.name }}</strong><small>{{ store.user?.id }}</small></div><el-button text
            @click="logout">退出</el-button>
        </div>
      </header>
      <main class="workspace"><router-view :key="route.path + (store.clubId || '')" /></main>
      <footer class="app-footer"><span>高校学生社团管理系统</span><span>把共同的热爱，变成一起的日常。</span></footer>
    </div>
  </div>
</template>
