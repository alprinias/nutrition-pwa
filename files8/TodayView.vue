<template>
  <div class="p-4 space-y-4">

    <!-- Calorie ring summary -->
    <div class="card flex items-center gap-5">
      <div class="relative w-24 h-24 flex-shrink-0">
        <svg class="w-24 h-24 -rotate-90" viewBox="0 0 100 100">
          <!-- Track -->
          <circle cx="50" cy="50" r="42" fill="none" stroke="#f3f4f6" stroke-width="10" />
          <!-- Progress -->
          <circle
            cx="50" cy="50" r="42"
            fill="none"
            stroke="#16a34a"
            stroke-width="10"
            stroke-linecap="round"
            :stroke-dasharray="`${calorieProgress * 263.9} 263.9`"
            class="transition-all duration-700"
          />
        </svg>
        <div class="absolute inset-0 flex flex-col items-center justify-center">
          <span class="text-lg font-bold text-gray-900">{{ totalCalories }}</span>
          <span class="text-[10px] text-gray-400">kcal</span>
        </div>
      </div>

      <div class="flex-1">
        <p class="text-sm font-semibold text-gray-700 mb-1">
          {{ totalCalories }} / {{ targetCalories }} kcal
        </p>
        <p class="text-xs text-gray-400">{{ remainingCalories }} remaining</p>

        <!-- Macro bars -->
        <div class="mt-3 space-y-2">
          <MacroBar label="Protein" :value="totals.protein" :max="protMaxG" color="bg-blue-500" unit="g" />
          <MacroBar label="Carbs"   :value="totals.carbs"   :max="carbMaxG" color="bg-amber-400" unit="g" />
          <MacroBar label="Fat"     :value="totals.fat"     :max="fatMaxG"  color="bg-rose-400"  unit="g" />
        </div>
      </div>
    </div>

    <!-- Macro detail pills -->
    <div class="grid grid-cols-3 gap-3">
      <div class="card macro-pill bg-blue-50 border-blue-100">
        <span class="text-xs font-medium text-blue-600">Protein</span>
        <span class="text-xl font-bold text-blue-800">{{ totals.protein.toFixed(0) }}</span>
        <span class="text-[10px] text-blue-500">g</span>
      </div>
      <div class="card macro-pill bg-amber-50 border-amber-100">
        <span class="text-xs font-medium text-amber-600">Carbs</span>
        <span class="text-xl font-bold text-amber-800">{{ totals.carbs.toFixed(0) }}</span>
        <span class="text-[10px] text-amber-500">g</span>
      </div>
      <div class="card macro-pill bg-rose-50 border-rose-100">
        <span class="text-xs font-medium text-rose-600">Fat</span>
        <span class="text-xl font-bold text-rose-800">{{ totals.fat.toFixed(0) }}</span>
        <span class="text-[10px] text-rose-500">g</span>
      </div>
    </div>

    <!-- Today's meals quick list -->
    <div class="card">
      <div class="flex items-center justify-between mb-3">
        <h2 class="font-semibold text-gray-800">Today's meals</h2>
        <RouterLink to="/log" class="text-xs text-green-600 font-medium">See all</RouterLink>
      </div>

      <div v-if="loading" class="py-6 text-center text-sm text-gray-400">Loading…</div>

      <div v-else-if="meals.length === 0" class="py-6 text-center">
        <p class="text-sm text-gray-400">No meals logged yet today.</p>
        <RouterLink to="/add" class="mt-2 inline-block text-sm text-green-600 font-medium">
          + Add your first meal
        </RouterLink>
      </div>

      <ul v-else class="divide-y divide-gray-50">
        <li
          v-for="meal in meals.slice(0, 5)"
          :key="meal.id"
          class="py-2 flex items-center justify-between"
        >
          <div>
            <p class="text-sm font-medium text-gray-800">{{ meal.name }}</p>
            <p class="text-xs text-gray-400">{{ formatTime(meal.logged_at) }}</p>
          </div>
          <span class="text-sm font-semibold text-gray-700">{{ meal.calories.toFixed(0) }} kcal</span>
        </li>
      </ul>
    </div>

    <!-- Add meal shortcut -->
    <RouterLink
      to="/add"
      class="btn-primary text-center block"
    >
      + Add meal
    </RouterLink>

  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { RouterLink } from 'vue-router'
import { supabase } from '@/lib/supabase'
import { useAuthStore } from '@/stores/auth'
import MacroBar from '@/components/MacroBar.vue'

const auth = useAuthStore()
const meals = ref([])
const loading = ref(true)
const targets = ref({ prot_max_pct: 35, carb_max_pct: 50, fat_max_pct: 35, target_kcal: 2000 })

const protMaxG = computed(() => Math.round((targets.value.target_kcal * targets.value.prot_max_pct / 100) / 4))
const carbMaxG = computed(() => Math.round((targets.value.target_kcal * targets.value.carb_max_pct / 100) / 4))
const fatMaxG  = computed(() => Math.round((targets.value.target_kcal * targets.value.fat_max_pct  / 100) / 9))
const targetCalories = ref(2000)

const totals = computed(() => ({
  protein: meals.value.reduce((s, m) => s + (m.protein_g ?? 0), 0),
  carbs:   meals.value.reduce((s, m) => s + (m.carbs_g   ?? 0), 0),
  fat:     meals.value.reduce((s, m) => s + (m.fat_g     ?? 0), 0),
}))

const totalCalories = computed(() =>
  meals.value.reduce((s, m) => s + (m.calories ?? 0), 0).toFixed(0)
)

const remainingCalories = computed(() =>
  Math.max(0, targetCalories.value - totalCalories.value).toFixed(0)
)

const calorieProgress = computed(() =>
  Math.min(1, totalCalories.value / targetCalories.value)
)

function formatTime(iso) {
  return new Date(iso).toLocaleTimeString('el-GR', { hour: '2-digit', minute: '2-digit', hour12: false })
}

async function loadToday() {
  loading.value = true
  const start = new Date()
  start.setHours(0, 0, 0, 0)
  const end = new Date()
  end.setHours(23, 59, 59, 999)

  const { data, error } = await supabase
    .from('meal_log')
    .select('id, logged_at, calories, protein_g, carbs_g, fat_g, note, recipe_id, ingredient_id')
    .eq('user_id', auth.user.id)
    .gte('logged_at', start.toISOString())
    .lte('logged_at', end.toISOString())
    .order('logged_at', { ascending: true })

  if (!error) {
    // Attach a display name: use note, or recipe/ingredient id as fallback
    meals.value = (data ?? []).map(m => ({
      ...m,
      name: m.note || (m.recipe_id ? `Recipe #${m.recipe_id}` : `Item #${m.ingredient_id}`),
    }))
  }
  loading.value = false
}

async function loadTargets() {
  const { data } = await supabase
    .from('user_targets')
    .select('target_kcal, prot_max_pct, carb_max_pct, fat_max_pct')
    .eq('user_id', auth.user.id)
    .maybeSingle()

  if (data) targets.value = data
}

onMounted(() => {
  loadToday()
  loadTargets()
})
</script>
