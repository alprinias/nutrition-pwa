import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const routes = [
  // Auth routes (no guard)
  {
    path: '/login',
    name: 'Login',
    component: () => import('@/views/auth/LoginView.vue'),
    meta: { requiresGuest: true },
  },
  {
    path: '/register',
    name: 'Register',
    component: () => import('@/views/auth/RegisterView.vue'),
    meta: { requiresGuest: true },
  },
  {
    path: '/forgot-password',
    name: 'ForgotPassword',
    component: () => import('@/views/auth/ForgotPasswordView.vue'),
    meta: { requiresGuest: true },
  },
  {
    path: '/reset-password',
    name: 'ResetPassword',
    component: () => import('@/views/auth/ResetPasswordView.vue'),
  },

  // App routes (require auth) — wrapped in AppShell layout
  {
    path: '/',
    component: () => import('@/layouts/AppShell.vue'),
    meta: { requiresAuth: true },
    children: [
      {
        path: '',
        name: 'Today',
        component: () => import('@/views/TodayView.vue'),
      },
      {
        path: 'log',
        name: 'MealLog',
        component: () => import('@/views/MealLogView.vue'),
      },
      {
        path: 'add',
        name: 'AddMeal',
        component: () => import('@/views/AddMealView.vue'),
      },
      {
        path: 'foods',
        name: 'Foods',
        component: () => import('@/views/FoodsView.vue'),
      },
      {
        path: 'body',
        name: 'Body',
        component: () => import('@/views/BodyView.vue'),
      },
      {
        path: 'charts',
        name: 'Charts',
        component: () => import('@/views/ChartsView.vue'),
      },
      {
        path: 'history',
        name: 'History',
        component: () => import('@/views/HistoryView.vue'),
      },
      {
        path: 'settings',
        name: 'Settings',
        component: () => import('@/views/SettingsView.vue'),
      },
    ],
  },

  // Catch-all
  { path: '/:pathMatch(.*)*', redirect: '/' },
]

const router = createRouter({
  history: createWebHistory(),
  routes,
  scrollBehavior: () => ({ top: 0 }),
})

// Navigation guards
router.beforeEach(async (to) => {
  const auth = useAuthStore()

  // Wait for the initial session check before guarding
  if (auth.loading) {
    await auth.init()
  }

  if (to.meta.requiresAuth && !auth.isAuthenticated) {
    return { name: 'Login' }
  }

  if (to.meta.requiresGuest && auth.isAuthenticated) {
    return { name: 'Today' }
  }
})

export default router
