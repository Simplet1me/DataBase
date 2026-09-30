import { createRouter, createWebHashHistory } from 'vue-router'
import MainLayout from '../layout/MainLayout.vue'
import { useUser } from '../stores/user'
export const pages = [
  { path: '/clubs', title: '社团广场', group: '校园', component: () => import('../views/student/Clubs.vue') },
  { path: '/messages', title: '消息中心', group: '校园', component: () => import('../views/common/Messages.vue') },
  { path: '/me', title: '个人中心', group: '我的', role: 'student', component: () => import('../views/student/Me.vue') },
  { path: '/club/create', title: '发起建团', group: '我的', role: 'student', component: () => import('../views/student/Create.vue') },
  { path: '/manage/overview', title: '社团总览', group: '社团管理', role: 'manager', component: () => import('../views/manage/Overview.vue') },
  { path: '/manage/members', title: '社员管理', group: '社团管理', role: 'manager', component: () => import('../views/manage/Members.vue') },
  { path: '/manage/audit', title: '入社审批', group: '社团管理', role: 'manager', component: () => import('../views/manage/Audit.vue') },
  { path: '/manage/activities', title: '活动管理', group: '社团管理', role: 'manager', component: () => import('../views/manage/Activities.vue') },
  { path: '/manage/notices', title: '公告管理', group: '社团管理', role: 'manager', component: () => import('../views/manage/Notices.vue') },
  { path: '/manage/dissolve', title: '解散申请', group: '社团管理', role: 'manager', component: () => import('../views/manage/Dissolve.vue') },
  { path: '/union/audit', title: '双审工作台', group: '学生会', role: 'union', component: () => import('../views/union/Audit.vue') },
  { path: '/union/members', title: '学生会成员', group: '学生会', role: 'union', component: () => import('../views/union/Members.vue') },
  { path: '/union/messages', title: '系统消息管理', group: '学生会', role: 'union', component: () => import('../views/union/Messages.vue') },
  { path: '/teacher/workbench', title: '教师工作台', group: '指导教师', role: 'teacher', component: () => import('../views/teacher/Workbench.vue') },
]
export function allowed(role, store) {
  if (!role) return true
  if (role === 'manager') return store.manager
  if (role === 'union') return store.user?.unionMember
  return store.user?.userType === role
}
const router = createRouter({ history: createWebHashHistory(), routes: [
  { path: '/login', component: () => import('../views/login/Login.vue'), meta: { title: '登录' } },
  { path: '/', component: MainLayout, redirect: '/clubs', children: pages.map(p => ({ path: p.path, component: p.component, meta: { title: p.title, role: p.role } })) },
  { path: '/:pathMatch(.*)*', redirect: '/clubs' },
] })
router.beforeEach(async to => {
  const store = useUser()
  if (to.path === '/login') return true
  if (!store.token) return '/login'
  try { await store.refresh() } catch { store.logout(); return '/login' }
  if (!allowed(to.meta.role, store)) return '/clubs'
})
router.afterEach(to => { document.title = `${to.meta.title || '社团'} · 社团管理系统` })
window.addEventListener('club-unauthorized', () => { useUser().logout(); router.replace('/login') })
export default router
