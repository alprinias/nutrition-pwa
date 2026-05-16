<template>
  <div class="p-4 space-y-4">

    <!-- Month navigator -->
    <div class="flex items-center justify-between">
      <button @click="prevMonth" class="p-2 rounded-xl bg-white border border-gray-200 active:bg-gray-50">
        ‹
      </button>
      <h2 class="font-semibold text-gray-800">
        {{ monthLabel }}
      </h2>
      <button @click="nextMonth" class="p-2 rounded-xl bg-white border border-gray-200 active:bg-gray-50"
        :disabled="isCurrentMonth"
        :class="isCurrentMonth ? 'opacity-30 cursor-not-allowed' : ''"
      >
        ›
      </button>
    </div>

    <!-- Calendar grid -->
    <div class="card p-3">
      <!-- Day headers -->
      <div class="grid grid-cols-7 mb-1">
        <div v-for="d in dayHeaders" :key="d"
          class="text-center text-[10px] font-medium text-gray-400 py-1">
          {{ d }}
        </div>
      </div>

      <!-- Day cells -->
      <div class="grid grid-cols-7 gap-y-1">
        <!-- Empty cells for first week offset -->
        <div v-for="_ in firstDayOffset" :key="`e-${_}`" />

        <button
          v-for="day in daysInMonth"
          :key="day"
          @click="selectDay(day)"
          :class="[
            'relative flex flex-col items-center justify-center rounded-xl py-1.5 transition-colors text-sm',
            selectedDay === day ? 'bg-green-600 text-white' : 'active:bg-gray-50',
            isToday(day) && selectedDay !== day ? 'font-bold text-green-600' : '',
            !hasData(day) ? 'text-gray-300' : 'text-gray-800',
          ]"
        >
          <span>{{ day }}</span>
          <!-- Dot indicator if data exists -->
          <span v-if="hasData(day)"
            class="absolute bottom-0.5 w-1 h-1 rounded-full"
            :class="selectedDay === day ? 'bg-white' : 'bg-green-500'"
          />
        </button>
      </div>
    </div>

    <!-- Selected day detail -->
    <div v-if="selectedDay">
      <div class="flex items-center justify-between mb-2">
        <h3 class="font-semibold text-gray-800">{{ selectedDateLabel }}</h3>
        <span class="text-sm font-bold text-gray-700">{{ dayTotals.calories.toFixed(0) }} kcal</span>
      </div>

      <!-- Loading -->
      <div v-if="loadingDay" class="card py-8 text-center text-sm text-gray-400">Loading…</div>

      <!-- No data -->
      <div v-else-if="dayMeals.length === 0" class="card py-8 text-center">
        <p class="text-sm text-gray-400">No meals logged on this day.</p>
      </div>

      <template v-else>
        <!-- Macro summary -->
        <div class="grid grid-cols-3 gap-3 mb-3">
          <div class="card macro-pill bg-blue-50 border-blue-100">
            <span class="text-xs font-medium text-blue-600">Protein</span>
            <span class="text-lg font-bold text-blue-800">{{ dayTotals.protein.toFixed(0) }}</span>
            <span class="text-[10px] text-blue-500">g</span>
          </div>
          <div class="card macro-pill bg-amber-50 border-amber-100">
            <span class="text-xs font-medium text-amber-600">Carbs</span>
            <span class="text-lg font-bold text-amber-800">{{ dayTotals.carbs.toFixed(0) }}</span>
            <span class="text-[10px] text-amber-500">g</span>
          </div>
          <div class="card macro-pill bg-rose-50 border-rose-100">
            <span class="text-xs font-medium text-rose-600">Fat</span>
            <span class="text-lg font-bold text-rose-800">{{ dayTotals.fat.toFixed(0) }}</span>
            <span class="text-[10px] text-rose-500">g</span>
          </div>
        </div>

        <!-- Macro % bars -->
        <div class="card mb-3 space-y-2">
          <MacroBar label="Protein" :value="dayTotals.protein" :max="targets.prot_max_g" color="bg-blue-500" unit="g" />
          <MacroBar label="Carbs"   :value="dayTotals.carbs"   :max="targets.carb_max_g" color="bg-amber-400" unit="g" />
          <MacroBar label="Fat"     :value="dayTotals.fat"      :max="targets.fat_max_g"  color="bg-rose-400"  unit="g" />
        </div>

        <!-- Meal list -->
        <ul class="space-y-2">
          <li v-for="meal in dayMeals" :key="meal.id" class="card flex items-start gap-3">
            <div class="shrink-0 bg-gray-50 rounded-xl px-2 py-1 min-w-[48px] text-center">
              <p class="text-xs font-semibold text-gray-700">{{ formatTime(meal.logged_at) }}</p>
            </div>
            <div class="flex-1 min-w-0">
              <p class="text-sm font-medium text-gray-800 truncate">{{ meal.display_name }}</p>
              <p class="text-xs text-gray-400">{{ meal.quantity }} {{ meal.unit }}</p>
              <div class="flex gap-3 mt-1">
                <span class="text-[11px] text-blue-600">P {{ meal.protein_g.toFixed(1) }}g</span>
                <span class="text-[11px] text-amber-600">C {{ meal.carbs_g.toFixed(1) }}g</span>
                <span class="text-[11px] text-rose-500">F {{ meal.fat_g.toFixed(1) }}g</span>
              </div>
            </div>
            <div class="shrink-0 text-right">
              <p class="text-sm font-bold text-gray-800">{{ meal.calories.toFixed(0) }}</p>
              <p class="text-[10px] text-gray-400">kcal</p>
            </div>
          </li>
        </ul>
      </template>
    </div>

    <!-- Monthly summary -->
    <div v-if="monthSummary.days > 0" class="card bg-gray-50 border-gray-100">
      <h3 class="font-semibold text-gray-700 mb-3">{{ monthLabel }} summary</h3>
      <div class="grid grid-cols-2 gap-3 text-sm">
        <div class="flex justify-between">
          <span class="text-gray-500">Days logged</span>
          <span class="font-semibold">{{ monthSummary.days }}</span>
        </div>
        <div class="flex justify-between">
          <span class="text-gray-500">Avg kcal</span>
          <span class="font-semibold">{{ monthSummary.avgCal.toFixed(0) }}</span>
        </div>
        <div class="flex justify-between">
          <span class="text-gray-500">Avg protein</span>
          <span class="font-semibold text-blue-700">{{ monthSummary.avgProt.toFixed(0) }}g</span>
        </div>
        <div class="flex justify-between">
          <span class="text-gray-500">Avg carbs</span>
          <span class="font-semibold text-amber-600">{{ monthSummary.avgCarb.toFixed(0) }}g</span>
        </div>
        <div class="flex justify-between col-span-2">
          <span class="text-gray-500">Avg fat</span>
          <span class="font-semibold text-rose-500">{{ monthSummary.avgFat.toFixed(0) }}g</span>
        </div>
      </div>
    </div>

  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { supabase } from '@/lib/supabase'
import { useAuthStore } from '@/stores/auth'
import MacroBar from '@/components/MacroBar.vue'

const auth = useAuthStore()

const dayHeaders = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su']

// Current month/year being viewed
const viewYear  = ref(new Date().getFullYear())
const viewMonth = ref(new Date().getMonth()) // 0-indexed

const selectedDay = ref(null)
const dayMeals    = ref([])
const loadingDay  = ref(false)

// All meal_log rows for the viewed month, grouped by day
const monthData = ref({}) // { 'YYYY-MM-DD': [meals] }

const targets = ref({
  prot_max_g: 160,
  carb_max_g: 250,
  fat_max_g:  80,
  target_kcal: 2000,
})

// ── computed ──────────────────────────────────────────────────────────────────

const monthLabel = computed(() =>
  new Date(viewYear.value, viewMonth.value, 1)
    .toLocaleDateString('el-GR', { month: 'long', year: 'numeric' })
)

const isCurrentMonth = computed(() => {
  const now = new Date()
  return viewYear.value === now.getFullYear() && viewMonth.value === now.getMonth()
})

const daysInMonth = computed(() => {
  return new Date(viewYear.value, viewMonth.value + 1, 0).getDate()
})

// Monday-based offset (0=Mon … 6=Sun)
const firstDayOffset = computed(() => {
  const d = new Date(viewYear.value, viewMonth.value, 1).getDay()
  return (d + 6) % 7 // convert Sun=0 to Mon=0
})

const selectedDateLabel = computed(() => {
  if (!selectedDay.value) return ''
  return new Date(viewYear.value, viewMonth.value, selectedDay.value)
    .toLocaleDateString('el-GR', { weekday: 'long', day: '2-digit', month: '2-digit', year: 'numeric' })
})

const dayTotals = computed(() => {
  const meals = dayMeals.value
  return {
    calories: meals.reduce((s, m) => s + (m.calories  ?? 0), 0),
    protein:  meals.reduce((s, m) => s + (m.protein_g ?? 0), 0),
    carbs:    meals.reduce((s, m) => s + (m.carbs_g   ?? 0), 0),
    fat:      meals.reduce((s, m) => s + (m.fat_g     ?? 0), 0),
  }
})

const monthSummary = computed(() => {
  const days = Object.values(monthData.value)
  if (!days.length) return { days: 0, avgCal: 0, avgProt: 0, avgCarb: 0, avgFat: 0 }
  const totals = days.map(meals => ({
    cal:  meals.reduce((s, m) => s + (m.calories  ?? 0), 0),
    prot: meals.reduce((s, m) => s + (m.protein_g ?? 0), 0),
    carb: meals.reduce((s, m) => s + (m.carbs_g   ?? 0), 0),
    fat:  meals.reduce((s, m) => s + (m.fat_g     ?? 0), 0),
  }))
  const n = totals.length
  return {
    days:    n,
    avgCal:  totals.reduce((s, t) => s + t.cal,  0) / n,
    avgProt: totals.reduce((s, t) => s + t.prot, 0) / n,
    avgCarb: totals.reduce((s, t) => s + t.carb, 0) / n,
    avgFat:  totals.reduce((s, t) => s + t.fat,  0) / n,
  }
})

// ── helpers ───────────────────────────────────────────────────────────────────

function dateKey(year, month, day) {
  return `${year}-${String(month + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`
}

function hasData(day) {
  return !!monthData.value[dateKey(viewYear.value, viewMonth.value, day)]?.length
}

function isToday(day) {
  const now = new Date()
  return now.getFullYear() === viewYear.value &&
         now.getMonth()    === viewMonth.value &&
         now.getDate()     === day
}

function formatTime(iso) {
  return new Date(iso).toLocaleTimeString('el-GR', { hour: '2-digit', minute: '2-digit', hour12: false })
}

// ── navigation ────────────────────────────────────────────────────────────────

function prevMonth() {
  if (viewMonth.value === 0) { viewMonth.value = 11; viewYear.value-- }
  else viewMonth.value--
  selectedDay.value = null
  dayMeals.value = []
}

function nextMonth() {
  if (isCurrentMonth.value) return
  if (viewMonth.value === 11) { viewMonth.value = 0; viewYear.value++ }
  else viewMonth.value++
  selectedDay.value = null
  dayMeals.value = []
}

// ── data loading ──────────────────────────────────────────────────────────────

async function loadMonth() {
  monthData.value = {}
  const start = new Date(viewYear.value, viewMonth.value, 1)
  const end   = new Date(viewYear.value, viewMonth.value + 1, 0, 23, 59, 59, 999)

  const { data } = await supabase
    .from('meal_log')
    .select(`
      id, logged_at, quantity, unit, note, calories, protein_g, carbs_g, fat_g,
      recipes ( name ), ingredients ( name )
    `)
    .eq('user_id', auth.user.id)
    .gte('logged_at', start.toISOString())
    .lte('logged_at', end.toISOString())
    .order('logged_at', { ascending: true })

  const grouped = {}
  ;(data ?? []).forEach(m => {
    const key = m.logged_at.slice(0, 10)
    if (!grouped[key]) grouped[key] = []
    grouped[key].push({
      ...m,
      display_name: m.note || m.recipes?.name || m.ingredients?.name || '—',
    })
  })
  monthData.value = grouped
}

async function selectDay(day) {
  selectedDay.value = day
  loadingDay.value = true
  const key = dateKey(viewYear.value, viewMonth.value, day)
  dayMeals.value = monthData.value[key] ?? []
  loadingDay.value = false
}

async function loadTargets() {
  const { data } = await supabase
    .from('user_targets')
    .select('target_kcal, prot_max_pct, carb_max_pct, fat_max_pct')
    .eq('user_id', auth.user.id)
    .maybeSingle()

  if (data) {
    targets.value = {
      target_kcal: data.target_kcal ?? 2000,
      prot_max_g: Math.round((data.target_kcal * data.prot_max_pct / 100) / 4),
      carb_max_g: Math.round((data.target_kcal * data.carb_max_pct / 100) / 4),
      fat_max_g:  Math.round((data.target_kcal * data.fat_max_pct  / 100) / 9),
    }
  }
}

watch([viewYear, viewMonth], loadMonth)

onMounted(() => {
  loadTargets()
  loadMonth()
  // Auto-select today if viewing current month
  const now = new Date()
  if (viewYear.value === now.getFullYear() && viewMonth.value === now.getMonth()) {
    selectDay(now.getDate())
  }
})
</script>
