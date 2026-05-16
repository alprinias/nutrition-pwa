<template>
  <div class="p-4 space-y-4">

    <!-- Controls -->
    <div class="card space-y-3">

      <!-- Granularity tabs -->
      <div class="flex gap-2">
        <button
          v-for="g in granularities"
          :key="g.key"
          @click="granularity = g.key"
          :class="[
            'flex-1 py-2 text-sm font-medium rounded-xl transition-colors',
            granularity === g.key
              ? 'bg-green-600 text-white'
              : 'bg-gray-100 text-gray-500'
          ]"
        >{{ g.label }}</button>
      </div>

      <!-- Date range -->
      <div class="grid grid-cols-2 gap-3">
        <div>
          <label class="block text-xs text-gray-500 mb-1">From</label>
          <input v-model="dateFrom" type="date" class="input-field text-sm py-2" :max="dateTo" />
        </div>
        <div>
          <label class="block text-xs text-gray-500 mb-1">To</label>
          <input v-model="dateTo" type="date" class="input-field text-sm py-2" :min="dateFrom" :max="today" />
        </div>
      </div>

      <button @click="loadData" class="btn-primary py-2 text-sm" :disabled="loading">
        {{ loading ? 'Loading…' : 'Apply' }}
      </button>
    </div>

    <div v-if="loading" class="py-12 text-center text-sm text-gray-400">Loading data…</div>

    <template v-else-if="chartPoints.length > 0">

      <!-- Summary stats -->
      <div class="grid grid-cols-2 gap-3">
        <div class="card text-center">
          <p class="text-xs text-gray-400 mb-1">Avg kcal</p>
          <p class="text-xl font-bold text-gray-800">{{ avg('calories').toFixed(0) }}</p>
        </div>
        <div class="card text-center">
          <p class="text-xs text-gray-400 mb-1">Avg protein</p>
          <p class="text-xl font-bold text-blue-700">{{ avg('protein').toFixed(0) }}g</p>
        </div>
        <div class="card text-center">
          <p class="text-xs text-gray-400 mb-1">Avg carbs</p>
          <p class="text-xl font-bold text-amber-600">{{ avg('carbs').toFixed(0) }}g</p>
        </div>
        <div class="card text-center">
          <p class="text-xs text-gray-400 mb-1">Avg fat</p>
          <p class="text-xl font-bold text-rose-500">{{ avg('fat').toFixed(0) }}g</p>
        </div>
      </div>

      <!-- Charts -->
      <LineChart
        title="Calories (kcal)"
        :points="chartPoints"
        metric="calories"
        color="#16a34a"
        :target="targets.target_kcal"
        :labels="chartLabels"
      />
      <LineChart
        title="Protein (g)"
        :points="chartPoints"
        metric="protein"
        color="#3b82f6"
        :target="targets.prot_max_g"
        :labels="chartLabels"
      />
      <LineChart
        title="Carbohydrates (g)"
        :points="chartPoints"
        metric="carbs"
        color="#f59e0b"
        :target="targets.carb_max_g"
        :labels="chartLabels"
      />
      <LineChart
        title="Fat (g)"
        :points="chartPoints"
        metric="fat"
        color="#f43f5e"
        :target="targets.fat_max_g"
        :labels="chartLabels"
      />

      <!-- Body measurement charts -->
      <template v-if="bodyPoints.length > 0">
        <div class="flex items-center gap-2 mt-2">
          <div class="flex-1 h-px bg-gray-200" />
          <p class="text-xs font-medium text-gray-400 shrink-0">Body measurements</p>
          <div class="flex-1 h-px bg-gray-200" />
        </div>

        <LineChart
          title="Weight (kg)"
          :points="bodyPoints"
          metric="weight_kg"
          color="#8b5cf6"
          :labels="bodyLabels"
        />
        <LineChart
          title="Body fat (%)"
          :points="bodyPoints"
          metric="fat_pct"
          color="#f97316"
          :labels="bodyLabels"
        />
        <LineChart
          title="Water (%)"
          :points="bodyPoints"
          metric="water_pct"
          color="#06b6d4"
          :labels="bodyLabels"
        />
      </template>

    </template>

    <div v-else-if="!loading" class="card py-10 text-center">
      <p class="text-3xl mb-2">📈</p>
      <p class="text-sm text-gray-400">No data for the selected period.</p>
    </div>

  </div>
</template>

<script setup>
import { ref, computed, onMounted, defineComponent, h } from 'vue'
import { supabase } from '@/lib/supabase'
import { useAuthStore } from '@/stores/auth'

const auth = useAuthStore()

// ── LineChart inline component ────────────────────────────────────────────────

const LineChart = defineComponent({
  name: 'LineChart',
  props: {
    title:   String,
    points:  Array,   // [{ calories, protein, carbs, fat }]
    metric:  String,
    color:   String,
    target:  Number,
    labels:  Array,   // x-axis labels
  },
  setup(props) {
    const W = 340, H = 140, PAD = { t: 10, r: 10, b: 28, l: 40 }
    const IW = W - PAD.l - PAD.r
    const IH = H - PAD.t - PAD.b

    return () => {
      const vals = props.points.map(p => p[props.metric]).filter(v => v != null)
      if (!vals.length) return null

      const dataMin = Math.min(...vals)
      const dataMax = Math.max(...vals)
      const spread  = dataMax - dataMin || dataMax || 1
      const minVal  = Math.max(0, dataMin - spread * 0.1)
      const maxVal  = Math.max(dataMax + spread * 0.1, minVal + 1)

      const toX = i => PAD.l + (i / Math.max(vals.length - 1, 1)) * IW
      const toY = v => PAD.t + IH - ((v - minVal) / (maxVal - minVal)) * IH

      // Line path
      const pathD = vals
        .map((v, i) => `${i === 0 ? 'M' : 'L'}${toX(i).toFixed(1)},${toY(v).toFixed(1)}`)
        .join(' ')

      // Area path
      const areaD = pathD +
        ` L${toX(vals.length - 1).toFixed(1)},${(PAD.t + IH).toFixed(1)}` +
        ` L${toX(0).toFixed(1)},${(PAD.t + IH).toFixed(1)} Z`

      // Y-axis ticks
      const yTicks = [0, 0.25, 0.5, 0.75, 1].map(f => ({
        val: Math.round(minVal + f * (maxVal - minVal)),
        y:   toY(minVal + f * (maxVal - minVal)),
      }))

      // X-axis labels — show at most 6, evenly spaced
      const step = Math.ceil(vals.length / 6)
      const xLabels = vals
        .map((_, i) => i)
        .filter(i => i % step === 0 || i === vals.length - 1)

      // Target line
      const targetY = props.target ? toY(props.target) : null

      return h('div', { class: 'card' }, [
        h('p', { class: 'text-xs font-semibold text-gray-600 mb-2' }, props.title),
        h('svg', {
          viewBox: `0 0 ${W} ${H}`,
          class: 'w-full overflow-visible',
          style: 'font-size:9px',
        }, [
          // Gradient def
          h('defs', {}, [
            h('linearGradient', { id: `grad-${props.metric}`, x1: '0', y1: '0', x2: '0', y2: '1' }, [
              h('stop', { offset: '0%',   'stop-color': props.color, 'stop-opacity': '0.25' }),
              h('stop', { offset: '100%', 'stop-color': props.color, 'stop-opacity': '0.02' }),
            ]),
          ]),

          // Y gridlines + labels
          ...yTicks.map(t => [
            h('line', { x1: PAD.l, y1: t.y, x2: W - PAD.r, y2: t.y,
              stroke: '#e5e7eb', 'stroke-width': '1' }),
            h('text', { x: PAD.l - 4, y: t.y + 3, 'text-anchor': 'end', fill: '#9ca3af' }, t.val),
          ]).flat(),

          // Target line
          ...(targetY != null ? [
            h('line', {
              x1: PAD.l, y1: targetY, x2: W - PAD.r, y2: targetY,
              stroke: props.color, 'stroke-width': '1', 'stroke-dasharray': '4 3', opacity: '0.5',
            }),
            h('text', { x: W - PAD.r + 2, y: targetY + 3, fill: props.color, opacity: '0.7' }, 'T'),
          ] : []),

          // Area fill
          h('path', { d: areaD, fill: `url(#grad-${props.metric})` }),

          // Line
          h('path', { d: pathD, fill: 'none', stroke: props.color, 'stroke-width': '2',
            'stroke-linejoin': 'round', 'stroke-linecap': 'round' }),

          // Dots (only if ≤30 points)
          ...(vals.length <= 30 ? vals.map((v, i) =>
            h('circle', { cx: toX(i), cy: toY(v), r: '3', fill: props.color })
          ) : []),

          // X labels
          ...xLabels.map(i =>
            h('text', {
              x: toX(i), y: H - 4,
              'text-anchor': 'middle', fill: '#9ca3af',
            }, props.labels?.[i] ?? '')
          ),
        ]),
      ])
    }
  },
})

// ── Controls ──────────────────────────────────────────────────────────────────

const granularities = [
  { key: 'day',   label: 'Day'   },
  { key: 'week',  label: 'Week'  },
  { key: 'month', label: 'Month' },
]

const today = new Date().toISOString().slice(0, 10)

// Default: last 30 days
const dateFrom = ref((() => {
  const d = new Date(); d.setDate(d.getDate() - 30); return d.toISOString().slice(0, 10)
})())
const dateTo   = ref(today)
const granularity = ref('day')
const loading  = ref(false)

// Raw daily totals from DB
const rawDaily = ref([]) // [{ date, calories, protein, carbs, fat }]
const rawBody  = ref([]) // [{ measured_at, weight_kg, fat_pct, water_pct }]

const targets = ref({
  target_kcal: 1850,
  prot_max_g: 120,
  carb_max_g: 250,
  fat_max_g:  78,
})

// ── Data loading ──────────────────────────────────────────────────────────────

async function loadData() {
  loading.value = true
  rawDaily.value = []
  rawBody.value  = []

  const start = new Date(dateFrom.value + 'T00:00:00')
  const end   = new Date(dateTo.value   + 'T23:59:59')

  const [mealsRes, bodyRes] = await Promise.all([
    supabase
      .from('meal_log')
      .select('logged_at, calories, protein_g, carbs_g, fat_g')
      .eq('user_id', auth.user.id)
      .gte('logged_at', start.toISOString())
      .lte('logged_at', end.toISOString())
      .order('logged_at', { ascending: true }),
    supabase
      .from('body_measurements')
      .select('measured_at, weight_kg, fat_pct, water_pct')
      .eq('user_id', auth.user.id)
      .gte('measured_at', dateFrom.value)
      .lte('measured_at', dateTo.value)
      .order('measured_at', { ascending: true }),
  ])

  // Group meals into daily buckets
  const dayMap = {}
  ;(mealsRes.data ?? []).forEach(m => {
    const key = m.logged_at.slice(0, 10)
    if (!dayMap[key]) dayMap[key] = { date: key, calories: 0, protein: 0, carbs: 0, fat: 0 }
    dayMap[key].calories += m.calories  ?? 0
    dayMap[key].protein  += m.protein_g ?? 0
    dayMap[key].carbs    += m.carbs_g   ?? 0
    dayMap[key].fat      += m.fat_g     ?? 0
  })
  rawDaily.value = Object.values(dayMap).sort((a, b) => a.date.localeCompare(b.date))

  rawBody.value = (bodyRes.data ?? []).map(r => ({
    date:      r.measured_at,
    weight_kg: r.weight_kg,
    fat_pct:   r.fat_pct,
    water_pct: r.water_pct,
  }))

  loading.value = false
}

async function loadTargets() {
  const { data } = await supabase
    .from('user_targets')
    .select('target_kcal, prot_min_g, carb_max_pct, fat_max_pct')
    .eq('user_id', auth.user.id)
    .maybeSingle()

  if (data) {
    targets.value = {
      target_kcal: data.target_kcal ?? 1850,
      prot_max_g:  data.prot_min_g ?? 120,
      carb_max_g:  Math.round((data.target_kcal * data.carb_max_pct / 100) / 4),
      fat_max_g:   Math.round((data.target_kcal * data.fat_max_pct  / 100) / 9),
    }
  }
}

// ── Aggregation ───────────────────────────────────────────────────────────────

function isoWeek(dateStr) {
  const d = new Date(dateStr)
  const day = d.getUTCDay() || 7
  d.setUTCDate(d.getUTCDate() + 4 - day)
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1))
  const week = Math.ceil((((d - yearStart) / 86400000) + 1) / 7)
  return `${d.getUTCFullYear()}-W${String(week).padStart(2, '0')}`
}

function isoMonth(dateStr) {
  return dateStr.slice(0, 7)
}

const chartPoints = computed(() => {
  if (!rawDaily.value.length) return []
  if (granularity.value === 'day') return rawDaily.value

  // Group by week or month, take averages
  const groupKey = granularity.value === 'week' ? isoWeek : isoMonth
  const groups = {}
  rawDaily.value.forEach(d => {
    const k = groupKey(d.date)
    if (!groups[k]) groups[k] = { key: k, calories: 0, protein: 0, carbs: 0, fat: 0, n: 0 }
    groups[k].calories += d.calories
    groups[k].protein  += d.protein
    groups[k].carbs    += d.carbs
    groups[k].fat      += d.fat
    groups[k].n++
  })

  return Object.values(groups)
    .sort((a, b) => a.key.localeCompare(b.key))
    .map(g => ({
      date:     g.key,
      calories: g.calories / g.n,
      protein:  g.protein  / g.n,
      carbs:    g.carbs    / g.n,
      fat:      g.fat      / g.n,
    }))
})

const chartLabels = computed(() => {
  return chartPoints.value.map(p => {
    if (granularity.value === 'day') {
      const d = new Date(p.date + 'T12:00:00')
      return d.toLocaleDateString('el-GR', { day: '2-digit', month: '2-digit' })
    }
    if (granularity.value === 'week') return p.date.replace('-', ' ')
    // month
    const [y, m] = p.date.split('-')
    return new Date(parseInt(y), parseInt(m) - 1, 1)
      .toLocaleDateString('el-GR', { month: 'short' })
  })
})

function avg(metric) {
  if (!chartPoints.value.length) return 0
  return chartPoints.value.reduce((s, p) => s + (p[metric] ?? 0), 0) / chartPoints.value.length
}

// Body measurements — aggregate by week/month if needed
const bodyPoints = computed(() => {
  if (!rawBody.value.length) return []
  if (granularity.value === 'day') return rawBody.value

  const groupKey = granularity.value === 'week' ? isoWeek : isoMonth
  const groups = {}
  rawBody.value.forEach(d => {
    const k = groupKey(d.date)
    if (!groups[k]) groups[k] = { key: k, weight_kg: [], fat_pct: [], water_pct: [] }
    if (d.weight_kg != null) groups[k].weight_kg.push(d.weight_kg)
    if (d.fat_pct   != null) groups[k].fat_pct.push(d.fat_pct)
    if (d.water_pct != null) groups[k].water_pct.push(d.water_pct)
  })

  const avgArr = arr => arr.length ? arr.reduce((a, b) => a + b, 0) / arr.length : null

  return Object.values(groups)
    .sort((a, b) => a.key.localeCompare(b.key))
    .map(g => ({
      date:      g.key,
      weight_kg: avgArr(g.weight_kg),
      fat_pct:   avgArr(g.fat_pct),
      water_pct: avgArr(g.water_pct),
    }))
})

const bodyLabels = computed(() => {
  return bodyPoints.value.map(p => {
    if (granularity.value === 'day') {
      const d = new Date(p.date + 'T12:00:00')
      return d.toLocaleDateString('el-GR', { day: '2-digit', month: '2-digit' })
    }
    if (granularity.value === 'week') return p.date.replace('-', ' ')
    const [y, m] = p.date.split('-')
    return new Date(parseInt(y), parseInt(m) - 1, 1)
      .toLocaleDateString('el-GR', { month: 'short' })
  })
})

onMounted(() => {
  loadTargets()
  loadData()
})
</script>
