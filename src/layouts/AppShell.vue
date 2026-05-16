<template>
  <div class="flex flex-col min-h-screen max-w-md mx-auto bg-gray-50">

    <!-- Top header -->
    <header class="bg-white border-b border-gray-100 px-4 pt-2 pb-3 sticky top-0 z-10">
      <div class="flex items-center justify-between">
        <div>
          <p class="text-xs text-gray-400 font-medium uppercase tracking-wide">{{ dayLabel }}</p>
          <h1 class="text-lg font-semibold text-gray-900 leading-tight">{{ pageTitle }}</h1>
        </div>
        <div class="flex items-center gap-3">
          <RouterLink to="/foods"    class="text-sm text-gray-400 active:text-gray-600">🥗</RouterLink>
          <RouterLink to="/history"  class="text-sm text-gray-400 active:text-gray-600">📅</RouterLink>
          <RouterLink to="/settings" class="text-sm text-gray-400 active:text-gray-600">⚙️</RouterLink>
          <button @click="handleLogout" class="text-sm text-gray-400 active:text-gray-600 transition-colors">
            Sign out
          </button>
        </div>
      </div>
    </header>

    <!-- Page content -->
    <main class="flex-1 overflow-y-auto pb-24">
      <RouterView />
    </main>

    <!-- Bottom navigation -->
    <nav class="fixed bottom-0 left-1/2 -translate-x-1/2 w-full max-w-md bg-white border-t border-gray-100
                grid grid-cols-5 pb-safe z-10">
      <RouterLink
        v-for="tab in tabs"
        :key="tab.name"
        :to="tab.to"
        custom
        v-slot="{ isActive, navigate }"
      >
        <button
          @click="navigate"
          :class="['nav-tab', { active: isActive }]"
        >
          <span class="text-xl" v-html="tab.icon" />
          <span class="text-[10px] font-medium">{{ tab.label }}</span>
        </button>
      </RouterLink>
    </nav>

  </div>
</template>

<script setup>
import { computed } from 'vue'
import { RouterView, RouterLink, useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const auth = useAuthStore()
const route = useRoute()
const router = useRouter()

const tabs = [
  { name: 'Today',   to: '/',       icon: '📊', label: 'Today'  },
  { name: 'MealLog', to: '/log',    icon: '📋', label: 'Log'    },
  { name: 'AddMeal', to: '/add',    icon: '➕', label: 'Add'    },
  { name: 'Body',    to: '/body',   icon: '⚖️', label: 'Body'   },
  { name: 'Charts',  to: '/charts', icon: '📈', label: 'Charts' },
]

const pageTitles = {
  Today:    'Today\'s summary',
  MealLog:  'Meal log',
  AddMeal:  'Add meal',
  Foods:    'Ingredients & recipes',
  Body:     'Body measurements',
  Charts:   'Charts',
  History:  'History',
  Settings: 'Settings',
}

const pageTitle = computed(() => pageTitles[route.name] ?? 'Διατροφή')

const dayLabel = computed(() => {
  return new Date().toLocaleDateString('el-GR', {
    weekday: 'long', day: 'numeric', month: 'long',
  })
})

async function handleLogout() {
  await auth.logout()
  router.push({ name: 'Login' })
}
</script>
