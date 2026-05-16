<template>
  <div class="p-4 space-y-4">

    <!-- Entry form -->
    <div class="card space-y-3">
      <div class="flex items-center justify-between">
        <h2 class="font-semibold text-gray-800">Log measurement</h2>
        <span v-if="isToday" class="text-xs text-green-600 font-medium">Today</span>
      </div>

      <!-- Date picker -->
      <div>
        <label class="block text-xs font-medium text-gray-500 mb-1">Date</label>
        <input
          v-model="selectedDate"
          type="date"
          :max="today"
          class="input-field"
          @change="onDateChange"
        />
      </div>

      <!-- Measurements -->
      <div class="grid grid-cols-3 gap-3">
        <div>
          <label class="block text-xs font-medium text-gray-500 mb-1">Weight (kg)</label>
          <input v-model.number="form.weight_kg" type="number" step="0.1" min="30" max="300"
            class="input-field text-center font-semibold" placeholder="—" />
        </div>
        <div>
          <label class="block text-xs font-medium text-gray-500 mb-1">Fat (%)</label>
          <input v-model.number="form.fat_pct" type="number" step="0.1" min="1" max="70"
            class="input-field text-center font-semibold" placeholder="—" />
        </div>
        <div>
          <label class="block text-xs font-medium text-gray-500 mb-1">Water (%)</label>
          <input v-model.number="form.water_pct" type="number" step="0.1" min="1" max="80"
            class="input-field text-center font-semibold" placeholder="—" />
        </div>
      </div>

      <input v-model="form.note" type="text" placeholder="Note (optional)" class="input-field text-sm" />

      <p v-if="errorMsg"   class="text-sm text-red-600 bg-red-50 rounded-lg px-3 py-2">{{ errorMsg }}</p>
      <p v-if="successMsg" class="text-sm text-green-700 bg-green-50 rounded-lg px-3 py-2">{{ successMsg }}</p>

      <button @click="save" class="btn-primary" :disabled="saving || !hasAnyValue">
        {{ saving ? 'Saving…' : existingEntry ? 'Update' : 'Save measurement' }}
      </button>
    </div>

    <!-- Latest stats -->
    <div v-if="latest" class="grid grid-cols-3 gap-3">
      <div class="card text-center">
        <p class="text-xs text-gray-400 mb-1">Latest weight</p>
        <p class="text-2xl font-bold text-gray-800">{{ latest.weight_kg ?? '—' }}</p>
        <p class="text-[10px] text-gray-400">kg · {{ formatDate(latest.measured_at) }}</p>
      </div>
      <div class="card text-center">
        <p class="text-xs text-gray-400 mb-1">Latest fat</p>
        <p class="text-2xl font-bold text-orange-500">{{ latest.fat_pct ?? '—' }}</p>
        <p class="text-[10px] text-gray-400">%</p>
      </div>
      <div class="card text-center">
        <p class="text-xs text-gray-400 mb-1">Latest water</p>
        <p class="text-2xl font-bold text-blue-500">{{ latest.water_pct ?? '—' }}</p>
        <p class="text-[10px] text-gray-400">%</p>
      </div>
    </div>

    <!-- History list -->
    <div class="card">
      <div class="flex items-center justify-between mb-3">
        <h2 class="font-semibold text-gray-800">History</h2>
        <span class="text-xs text-gray-400">{{ history.length }} entries</span>
      </div>

      <div v-if="loadingHistory" class="py-6 text-center text-sm text-gray-400">Loading…</div>

      <div v-else-if="history.length === 0" class="py-6 text-center text-sm text-gray-400">
        No measurements yet.
      </div>

      <ul v-else class="divide-y divide-gray-50">
        <li
          v-for="m in history"
          :key="m.id"
          @click="editEntry(m)"
          class="py-3 flex items-center justify-between cursor-pointer active:bg-gray-50 rounded-lg px-1 transition-colors"
        >
          <div>
            <p class="text-sm font-medium text-gray-800">{{ formatDate(m.measured_at) }}</p>
            <p v-if="m.note" class="text-xs text-gray-400">{{ m.note }}</p>
            <p v-if="m.measured_at === selectedDate" class="text-xs text-green-600 font-medium">editing</p>
          </div>
          <div class="flex gap-4 text-sm text-right">
            <div v-if="m.weight_kg != null">
              <p class="font-semibold text-gray-800">{{ m.weight_kg }}</p>
              <p class="text-[10px] text-gray-400">kg</p>
            </div>
            <div v-if="m.fat_pct != null">
              <p class="font-semibold text-orange-500">{{ m.fat_pct }}</p>
              <p class="text-[10px] text-gray-400">fat%</p>
            </div>
            <div v-if="m.water_pct != null">
              <p class="font-semibold text-blue-500">{{ m.water_pct }}</p>
              <p class="text-[10px] text-gray-400">H₂O%</p>
            </div>
          </div>
        </li>
      </ul>

      <!-- Load more -->
      <button v-if="hasMore" @click="loadMore" class="btn-secondary mt-3 text-sm py-2" :disabled="loadingMore">
        {{ loadingMore ? 'Loading…' : 'Load more' }}
      </button>
    </div>

  </div>
</template>

<script setup>
import { ref, computed, reactive, onMounted } from 'vue'
import { supabase } from '@/lib/supabase'
import { useAuthStore } from '@/stores/auth'

const auth = useAuthStore()

const today = new Date().toISOString().slice(0, 10)
const selectedDate = ref(today)

const form = reactive({ weight_kg: null, fat_pct: null, water_pct: null, note: '' })
const existingEntry = ref(null)
const history       = ref([])
const latest        = ref(null)
const saving        = ref(false)
const loadingHistory = ref(true)
const loadingMore   = ref(false)
const hasMore       = ref(false)
const offset        = ref(0)
const PAGE = 20
const errorMsg    = ref('')
const successMsg  = ref('')

const isToday    = computed(() => selectedDate.value === today)
const hasAnyValue = computed(() =>
  form.weight_kg != null || form.fat_pct != null || form.water_pct != null
)

function formatDate(dateStr) {
  return new Date(dateStr + 'T12:00:00').toLocaleDateString('el-GR', {
    weekday: 'short', day: 'numeric', month: 'short', year: 'numeric',
  })
}

function resetForm() {
  form.weight_kg = null
  form.fat_pct   = null
  form.water_pct = null
  form.note      = ''
  existingEntry.value = null
}

function fillForm(entry) {
  form.weight_kg = entry.weight_kg
  form.fat_pct   = entry.fat_pct
  form.water_pct = entry.water_pct
  form.note      = entry.note ?? ''
  existingEntry.value = entry
}

// Called when date picker changes — check if an entry exists for that date
async function onDateChange() {
  errorMsg.value = ''
  successMsg.value = ''
  resetForm()

  // Check history cache first
  const cached = history.value.find(m => m.measured_at === selectedDate.value)
  if (cached) { fillForm(cached); return }

  // Otherwise query DB
  const { data } = await supabase
    .from('body_measurements')
    .select('*')
    .eq('user_id', auth.user.id)
    .eq('measured_at', selectedDate.value)
    .maybeSingle()

  if (data) fillForm(data)
}

// Tap a history row to edit it
function editEntry(m) {
  selectedDate.value = m.measured_at
  fillForm(m)
  errorMsg.value = ''
  successMsg.value = ''
  window.scrollTo({ top: 0, behavior: 'smooth' })
}

async function load(reset = true) {
  if (reset) {
    offset.value = 0
    history.value = []
    loadingHistory.value = true
  } else {
    loadingMore.value = true
  }

  const { data } = await supabase
    .from('body_measurements')
    .select('*')
    .eq('user_id', auth.user.id)
    .order('measured_at', { ascending: false })
    .range(offset.value, offset.value + PAGE - 1)

  const rows = data ?? []
  hasMore.value = rows.length === PAGE
  offset.value += rows.length

  if (reset) {
    history.value = rows
    latest.value = rows.find(m => m.weight_kg || m.fat_pct || m.water_pct) ?? null

    // Pre-fill form if today already has an entry
    const todayEntry = rows.find(m => m.measured_at === today)
    if (todayEntry) fillForm(todayEntry)
  } else {
    history.value = [...history.value, ...rows]
  }

  loadingHistory.value = false
  loadingMore.value = false
}

function loadMore() { load(false) }

async function save() {
  saving.value = true
  errorMsg.value = ''
  successMsg.value = ''

  const row = {
    user_id:     auth.user.id,
    measured_at: selectedDate.value,
    weight_kg:   form.weight_kg  || null,
    fat_pct:     form.fat_pct    || null,
    water_pct:   form.water_pct  || null,
    note:        form.note       || null,
  }

  const { error } = await supabase
    .from('body_measurements')
    .upsert(row, { onConflict: 'user_id,measured_at' })

  if (error) {
    errorMsg.value = error.message
  } else {
    successMsg.value = `Saved for ${formatDate(selectedDate.value)}`
    setTimeout(() => successMsg.value = '', 3000)
    load(true)
  }
  saving.value = false
}

onMounted(() => load(true))
</script>
