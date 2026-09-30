import { createApp } from 'vue'
import { createPinia } from 'pinia'
import 'element-plus/theme-chalk/base.css'
import 'element-plus/theme-chalk/el-message.css'
import 'element-plus/theme-chalk/el-message-box.css'
import 'element-plus/theme-chalk/el-loading.css'
import App from './App.vue'
import router from './router'
import './style.css'
// 先安装状态管理，再安装依赖登录态的路由。
const app = createApp(App)
app.use(createPinia()).use(router).mount('#app')
app.config.errorHandler = (error) => console.error('页面发生错误', error)
