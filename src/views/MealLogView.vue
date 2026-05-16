<template>
  <div class="p-4 space-y-4">

    <!-- Day total summary bar -->
    <div class="card bg-green-50 border-green-100">
      <div class="flex items-center justify-between mb-2">
        <h2 class="font-semibold text-green-900">Today's total</h2>
        <span class="text-lg font-bold text-green-800">{{ totalCalories.toFixed(0) }} kcal</span>
      </div>
      <div class="grid grid-cols-3 gap-2 text-center">
        <div class="bg-white rounded-xl py-2">
          <p class="text-sm font-bold text-blue-700">{{ totalProtein.toFixed(1) }}g</p>
          <p class="text-[10px] text-gray-400">protein</p>
        </div>
        <div class="bg-white rounded-xl py-2">
          <p class="text-sm font-bold text-amber-600">{{ totalCarbs.toFixed(1) }}g</p>
          <p class="text-[10px] text-gray-400">carbs</p>
        </div>
        <div class="bg-white rounded-xl py-2">
          <p class="text-sm font-bold text-rose-500">{{ totalFat.toFixed(1) }}g</p>
          <p class="text-[10px] text-gray-400">fat</p>
        </div>
      </div>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="py-12 text-center text-sm text-gray-400">Loading…</div>

    <!-- Empty -->
    <div v-else-if="meals.length === 0" class="py-12 text-center">
      <p class="text-3xl mb-2">🍽️</p>
      <p class="text-sm text-gray-400">No meals logged today.</p>
      <RouterLink to="/add" class="mt-3 inline-block text-sm text-green-600 font-medium">
        + Add your first meal
      </RouterLink>
    </div>

    <!-- Meal list -->
    <ul v-else class="space-y-2">
      <li
        v-for="meal in meals"
        :key="meal.id"
        class="card flex items-start gap-3"
      >
        <!-- Time badge -->
        <div class="shrink-0 text-center bg-gray-50 rounded-xl px-2 py-1 min-w-[48px]">
          <p class="text-xs font-semibold text-gray-700">{{ formatTime(meal.logged_at) }}</p>
        </div>

        <!-- Details -->
        <div class="flex-1 min-w-0">
          <p class="text-sm font-medium text-gray-800 truncate">{{ meal.display_name }}</p>
          <p class="text-xs text-gray-400 mt-0.5">
            {{ meal.quantity }} {{ meal.unit }}
          </p>
          <div class="flex gap-3 mt-1.5">
            <span class="text-[11px] text-blue-600">P {{ meal.protein_g.toFixed(1) }}g</span>
            <span class="text-[11px] text-amber-600">C {{ meal.carbs_g.toFixed(1) }}g</span>
            <span class="text-[11px] text-rose-500">F {{ meal.fat_g.toFixed(1) }}g</span>
          </div>
        </div>

        <!-- Calories + delete -->
        <div class="shrink-0 flex flex-col items-end gap-2">
          <span class="text-sm font-bold text-gray-800">{{ meal.calories.toFixed(0) }} kcal</span>
          <button
            @click="confirmDelete(meal)"
            class="text-gray-300 active:text-red-500 transition-colors text-lg leading-none"
            title="Delete"
          >
            ✕
          </button>
        </div>
      </li>
    </ul>

    <!-- Add another -->
    <RouterLink v-if="meals.length > 0" to="/add" class="btn-primary text-center block">
      + Add meal
    </RouterLink>

    <!-- Delete confirmation modal -->
    <Transition name="sheet">
      <div v-if="toDelete" class="fixed inset-0 z-50 flex items-end justify-center">
        <div class="absolute inset-0 bg-black/40" @click="toDelete = null" />
        <div class="relative bg-white rounded-t-2xl p-5 w-full max-w-md mx-auto space-y-4">
          <div class="w-10 h-1 bg-gray-200 rounded-full mx-auto" />
          <p class="font-semibold text-gray-900 text-center">Delete this entry?</p>
          <p class="text-sm text-gray-500 text-center">
            {{ toDelete.display_name }} · {{ toDelete.calories.toFixed(0) }} kcal
          </p>
          <div class="flex gap-3">
            <button @click="toDelete = null" class="btn-secondary">Cancel</button>
            <button
              @click="deleteMeal"
              class="flex-1 py-3 px-4 bg-red-500 text-white font-medium rounded-xl active:bg-red-600 transition-colors"
              :disabled="deleting"
            >
              {{ deleting ? 'Deleting…' : 'Delete' }}
            </button>
          </div>
        </div>
      </div>
    </Transition>

  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { RouterLink } from 'vue-router'
import { supabase } from '@/lib/supabase'
import { useAuthStore } from '@/stores/auth'

const auth = useAuthStore()
const meals = ref([])
const loading = ref(true)
const toDelete = ref(null)
const deleting = ref(false)

const totalCalories = computed(() => meals.value.reduce((s, m) => s + (m.calories  ?? 0), 0))
const totalProtein  = computed(() => meals.value.reduce((s, m) => s + (m.protein_g ?? 0), 0))
const totalCarbs    = computed(() => meals.value.reduce((s, m) => s + (m.carbs_g   ?? 0), 0))
const totalFat      = computed(() => meals.value.reduce((s, m) => s + (m.fat_g     ?? 0), 0))

function formatTime(iso) {
  return new Date(iso).toLocaleTimeString('el-GR', { hour: '2-digit', minute: '2-digit' })
}

async function loadMeals() {
  loading.value = true
  const start = new Date(); start.setHours(0, 0, 0, 0)
  const end   = new Date(); end.setHours(23, 59, 59, 999)

  const { data } = await supabase
    .from('meal_log')
    .select(`
      id, logged_at, quantity, unit, note, calories, protein_g, carbs_g, fat_g,
      recipe_id, ingredient_id,
      recipes ( name ),
      ingredients ( name )
    `)
    .eq('user_id', auth.user.id)
    .gte('logged_at', start.toISOString())
    .lte('logged_at', end.toISOString())
    .order('logged_at', { ascending: true })

  meals.value = (data ?? []).map(m => ({
    ...m,
    display_name: m.note || m.recipes?.name || m.ingredients?.name || '—',
  }))

  loading.value = false
}

function confirmDelete(meal) {
  toDelete.value = meal
}

async function deleteMeal() {
  if (!toDelete.value) return
  deleting.value = true
  await supabase.from('meal_log').delete().eq('id', toDelete.value.id)
  meals.value = meals.value.filter(m => m.id !== toDelete.value.id)
  toDelete.value = null
  deleting.value = false
}

onMounted(loadMeals)
</script>

<style scoped>
.sheet-enter-active, .sheet-leave-active { transition: opacity 0.2s ease; }
.sheet-enter-from, .sheet-leave-to { opacity: 0; }
</style>
