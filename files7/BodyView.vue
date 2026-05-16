<template>
  <div class="p-4 space-y-4">

    <!-- Today's entry -->
    <div class="card space-y-3">
      <div class="flex items-center justify-between">
        <h2 class="font-semibold text-gray-800">Today's measurement</h2>
        <span class="text-xs text-gray-400">{{ todayLabel }}</span>
      </div>

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
        {{ saving ? 'Saving…' : todayEntry ? 'Update' : 'Save measurement' }}
      </button>
    </div>

    <!-- Latest stats -->
    <div v-if="latest" class="grid grid-cols-3 gap-3">
      <div class="card text-center">
        <p class="text-xs text-gray-400 mb-1">Weight</p>
        <p class="text-2xl font-bold text-gray-800">{{ latest.weight_kg ?? '—' }}</p>
        <p class="text-[10px] text-gray-400">kg</p>
      </div>
      <div class="card text-center">
        <p class="text-xs text-gray-400 mb-1">Fat</p>
        <p class="text-2xl font-bold text-orange-500">{{ latest.fat_pct ?? '—' }}</p>
        <p class="text-[10px] text-gray-400">%</p>
      </div>
      <div class="card text-center">
        <p class="text-xs text-gray-400 mb-1">Water</p>
        <p class="text-2xl font-bold text-blue-500">{{ latest.water_pct ?? '—' }}</p>
        <p class="text-[10px] text-gray-400">%</p>
      </div>
    </div>

    <!-- History list -->
    <div class="card">
      <h2 class="font-semibold text-gray-800 mb-3">Recent measurements</h2>

      <div v-if="loadingHistory" class="py-6 text-center text-sm text-gray-400">Loading…</div>

      <div v-else-if="history.length === 0" class="py-6 text-center text-sm text-gray-400">
        No measurements yet.
      </div>

      <ul v-else class="divide-y divide-gray-50">
        <li v-for="m in history" :key="m.id"
          class="py-3 flex items-center justify-between"
        >
          <div>
            <p class="text-sm font-medium text-gray-800">{{ formatDate(m.measured_at) }}</p>
            <p v-if="m.note" class="text-xs text-gray-400">{{ m.note }}</p>
          </div>
          <div class="flex gap-4 text-sm text-right">
            <div>
              <p class="font-semibold text-gray-800">{{ m.weight_kg ?? '—' }}</p>
              <p class="text-[10px] text-gray-400">kg</p>
            </div>
            <div>
              <p class="font-semibold text-orange-500">{{ m.fat_pct ?? '—' }}</p>
              <p class="text-[10px] text-gray-400">fat%</p>
            </div>
            <div>
              <p class="font-semibold text-blue-500">{{ m.water_pct ?? '—' }}</p>
              <p class="text-[10px] text-gray-400">H₂O%</p>
            </div>
          </div>
        </li>
      </ul>
    </div>

  </div>
</template>

<script setup>
import { ref, computed, reactive, onMounted } from 'vue'
import { supabase } from '@/lib/supabase'
import { useAuthStore } from '@/stores/auth'

const auth = useAuthStore()

const today = new Date().toISOString().slice(0, 10)
const todayLabel = new Date().toLocaleDateString('el-GR', { weekday: 'long', day: 'numeric', month: 'long' })

const form = reactive({ weight_kg: null, fat_pct: null, water_pct: null, note: '' })
const todayEntry  = ref(null)
const history     = ref([])
const latest      = ref(null)
const saving      = ref(false)
const loadingHistory = ref(true)
const errorMsg    = ref('')
const successMsg  = ref('')

const hasAnyValue = computed(() =>
  form.weight_kg != null || form.fat_pct != null || form.water_pct != null
)

function formatDate(dateStr) {
  return new Date(dateStr + 'T12:00:00').toLocaleDateString('el-GR', {
    weekday: 'short', day: 'numeric', month: 'short', year: 'numeric'
  })
}

async function load() {
  loadingHistory.value = true

  const { data } = await supabase
    .from('body_measurements')
    .select('*')
    .eq('user_id', auth.user.id)
    .order('measured_at', { ascending: false })
    .limit(30)

  history.value = data ?? []
  latest.value = history.value.find(m => m.weight_kg || m.fat_pct || m.water_pct) ?? null

  // Pre-fill today's form if entry exists
  const existing = history.value.find(m => m.measured_at === today)
  if (existing) {
    todayEntry.value = existing
    form.weight_kg = existing.weight_kg
    form.fat_pct   = existing.fat_pct
    form.water_pct = existing.water_pct
    form.note      = existing.note ?? ''
  }

  loadingHistory.value = false
}

async function save() {
  saving.value = true
  errorMsg.value = ''
  successMsg.value = ''

  const row = {
    user_id:     auth.user.id,
    measured_at: today,
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
    successMsg.value = 'Saved!'
    setTimeout(() => successMsg.value = '', 3000)
    load()
  }
  saving.value = false
}

onMounted(load)
</script>
