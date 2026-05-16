<template>
  <div class="flex flex-col h-full overflow-hidden">

    <!-- ── TOP ZONE: Calorie ring + macro bars (never scrolls) ── -->
    <div class="shrink-0 px-4 pt-4 pb-2">
      <div class="card flex items-center gap-5">
        <div class="relative w-24 h-24 flex-shrink-0">
          <svg class="w-24 h-24 -rotate-90" viewBox="0 0 100 100">
            <circle cx="50" cy="50" r="42" fill="none" stroke="#f3f4f6" stroke-width="10" />
            <circle
              cx="50" cy="50" r="42"
              fill="none" stroke="#16a34a" stroke-width="10" stroke-linecap="round"
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
            {{ totalCalories }} / {{ targets.target_kcal }} kcal
          </p>
          <p class="text-xs text-gray-400">{{ remainingCalories }} remaining</p>
          <div class="mt-3 space-y-2">
            <MacroBar label="Protein" :value="totals.protein" :max="protMinG"  color="bg-blue-500"  unit="g" />
            <MacroBar label="Carbs"   :value="totals.carbs"   :max="carbMaxG"  color="bg-amber-400" unit="g" />
            <MacroBar label="Fat"     :value="totals.fat"      :max="fatMaxG"   color="bg-rose-400"  unit="g" />
          </div>
        </div>
      </div>
    </div>

    <!-- ── MIDDLE ZONE: Scrollable meal list (fills remaining space) ── -->
    <div class="flex-1 overflow-y-auto px-4 pb-2 min-h-0">
      <div class="card">
        <!-- Header with macro totals -->
        <div class="flex items-center justify-between mb-2">
          <h2 class="font-semibold text-gray-800">Today's meals</h2>
          <div v-if="meals.length > 0" class="flex gap-3 text-xs">
            <span class="text-blue-600 font-medium">P {{ totals.protein.toFixed(0) }}g</span>
            <span class="text-amber-600 font-medium">C {{ totals.carbs.toFixed(0) }}g</span>
            <span class="text-rose-500 font-medium">F {{ totals.fat.toFixed(0) }}g</span>
          </div>
        </div>

        <!-- Loading -->
        <div v-if="loading" class="py-8 text-center text-sm text-gray-400">Loading…</div>

        <!-- Empty -->
        <div v-else-if="meals.length === 0" class="py-8 text-center">
          <p class="text-sm text-gray-400">No meals logged yet today.</p>
        </div>

        <!-- Meal rows -->
        <ul v-else class="divide-y divide-gray-50">
          <li v-for="meal in meals" :key="meal.id" class="py-2.5 flex items-start gap-3">
            <!-- Time badge -->
            <div class="shrink-0 bg-gray-50 rounded-xl px-2 py-1 min-w-[46px] text-center mt-0.5">
              <p class="text-xs font-semibold text-gray-700">{{ formatTime(meal.logged_at) }}</p>
            </div>
            <!-- Details -->
            <div class="flex-1 min-w-0">
              <p class="text-sm font-medium text-gray-800 truncate">{{ meal.name }}</p>
              <p class="text-xs text-gray-400 mt-0.5">{{ meal.quantity }} {{ meal.unit }}</p>
              <div class="flex gap-3 mt-1">
                <span class="text-[11px] text-blue-600">P {{ meal.protein_g.toFixed(1) }}g</span>
                <span class="text-[11px] text-amber-600">C {{ meal.carbs_g.toFixed(1) }}g</span>
                <span class="text-[11px] text-rose-500">F {{ meal.fat_g.toFixed(1) }}g</span>
              </div>
            </div>
            <!-- Calories + delete -->
            <div class="shrink-0 flex flex-col items-end gap-1.5">
              <span class="text-sm font-bold text-gray-800">{{ meal.calories.toFixed(0) }} kcal</span>
              <button @click="confirmDelete(meal)"
                class="text-gray-300 active:text-red-500 transition-colors text-base leading-none">✕</button>
            </div>
          </li>
        </ul>
      </div>
    </div>

    <!-- ── BOTTOM ZONE: Add meal button (never scrolls) ── -->
    <div class="shrink-0 px-4 pt-2 pb-3">
      <RouterLink to="/add" class="btn-primary text-center block">
        + Add meal
      </RouterLink>
    </div>

    <!-- ── DELETE CONFIRM SHEET ── -->
    <Transition name="sheet">
      <div v-if="toDelete" class="fixed inset-0 z-50 flex items-end justify-center">
        <div class="absolute inset-0 bg-black/40" @click="toDelete = null" />
        <div class="relative bg-white rounded-t-2xl p-5 w-full max-w-md mx-auto space-y-4">
          <div class="w-10 h-1 bg-gray-200 rounded-full mx-auto" />
          <p class="font-semibold text-gray-900 text-center">Delete this entry?</p>
          <p class="text-sm text-gray-500 text-center">
            {{ toDelete.name }} · {{ toDelete.calories.toFixed(0) }} kcal
          </p>
          <div class="flex gap-3">
            <button @click="toDelete = null" class="btn-secondary">Cancel</button>
            <button @click="deleteMeal"
              class="flex-1 py-3 px-4 bg-red-500 text-white font-medium rounded-xl active:bg-red-600"
              :disabled="deleting">
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
import MacroBar from '@/components/MacroBar.vue'

const auth    = useAuthStore()
const meals   = ref([])
const loading = ref(true)
const toDelete = ref(null)
const deleting = ref(false)

const targets = ref({
  target_kcal:  1850,
  prot_min_g:   120,
  prot_max_pct: 35,
  carb_max_pct: 50,
  fat_max_pct:  35,
})

const protMinG = computed(() => targets.value.prot_min_g ?? 120)
const carbMaxG = computed(() => Math.round((targets.value.target_kcal * targets.value.carb_max_pct / 100) / 4))
const fatMaxG  = computed(() => Math.round((targets.value.target_kcal * targets.value.fat_max_pct  / 100) / 9))

const totals = computed(() => ({
  protein: meals.value.reduce((s, m) => s + (m.protein_g ?? 0), 0),
  carbs:   meals.value.reduce((s, m) => s + (m.carbs_g   ?? 0), 0),
  fat:     meals.value.reduce((s, m) => s + (m.fat_g     ?? 0), 0),
}))

const totalCalories = computed(() =>
  meals.value.reduce((s, m) => s + (m.calories ?? 0), 0).toFixed(0)
)

const remainingCalories = computed(() =>
  Math.max(0, targets.value.target_kcal - totalCalories.value).toFixed(0)
)

const calorieProgress = computed(() =>
  Math.min(1, totalCalories.value / targets.value.target_kcal)
)

function formatTime(iso) {
  return new Date(iso).toLocaleTimeString('el-GR', { hour: '2-digit', minute: '2-digit', hour12: false })
}

async function loadToday() {
  loading.value = true
  const start = new Date(); start.setHours(0, 0, 0, 0)
  const end   = new Date(); end.setHours(23, 59, 59, 999)

  const { data, error } = await supabase
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

  if (!error) {
    meals.value = (data ?? []).map(m => ({
      ...m,
      name: m.note || m.recipes?.name || m.ingredients?.name || '—',
    }))
  }
  loading.value = false
}

async function loadTargets() {
  const { data } = await supabase
    .from('user_targets')
    .select('target_kcal, prot_min_g, prot_max_pct, carb_max_pct, fat_max_pct')
    .eq('user_id', auth.user.id)
    .maybeSingle()

  if (data) targets.value = { ...targets.value, ...data }
}

function confirmDelete(meal) { toDelete.value = meal }

async function deleteMeal() {
  if (!toDelete.value) return
  deleting.value = true
  await supabase.from('meal_log').delete().eq('id', toDelete.value.id)
  meals.value = meals.value.filter(m => m.id !== toDelete.value.id)
  toDelete.value = null
  deleting.value = false
}

onMounted(() => { loadToday(); loadTargets() })
</script>

<style scoped>
.sheet-enter-active, .sheet-leave-active { transition: opacity 0.2s ease; }
.sheet-enter-from, .sheet-leave-to { opacity: 0; }
</style>
