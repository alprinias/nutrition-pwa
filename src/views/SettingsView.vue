<template>
  <div class="p-4 space-y-4">

    <!-- Profile -->
    <div class="card">
      <h2 class="font-semibold text-gray-800 mb-1">Account</h2>
      <p class="text-sm text-gray-500">{{ auth.user.email }}</p>
    </div>

    <!-- Macro targets -->
    <div class="card space-y-4">
      <div class="flex items-center justify-between">
        <h2 class="font-semibold text-gray-800">Macro targets</h2>
        <button
          v-if="!editing"
          @click="editing = true"
          class="text-sm text-green-600 font-medium"
        >Edit</button>
        <div v-else class="flex gap-3">
          <button @click="cancel" class="text-sm text-gray-400">Cancel</button>
          <button @click="save" class="text-sm text-green-600 font-medium" :disabled="saving">
            {{ saving ? 'Saving…' : 'Save' }}
          </button>
        </div>
      </div>

      <!-- Daily calorie target -->
      <div>
        <label class="block text-xs font-medium text-gray-500 mb-1">Daily calorie target (kcal)</label>
        <input
          v-model.number="form.target_kcal"
          type="number"
          min="500" max="6000" step="50"
          class="input-field"
          :disabled="!editing"
        />
      </div>

      <!-- Minimum carbs -->
      <div>
        <label class="block text-xs font-medium text-gray-500 mb-1">Minimum carbs (g/day)</label>
        <input
          v-model.number="form.carb_min_g"
          type="number"
          min="0" max="500" step="5"
          class="input-field"
          :disabled="!editing"
        />
      </div>

      <div class="border-t border-gray-100 pt-3 space-y-3">
        <p class="text-xs font-medium text-gray-500 uppercase tracking-wide">% of daily calories</p>

        <!-- Protein range -->
        <MacroRangeRow
          label="Protein"
          color="blue"
          :min-val="form.prot_min_pct"
          :max-val="form.prot_max_pct"
          :editing="editing"
          @update:min-val="form.prot_min_pct = $event"
          @update:max-val="form.prot_max_pct = $event"
        />

        <!-- Carbs range -->
        <MacroRangeRow
          label="Carbs"
          color="amber"
          :min-val="form.carb_min_pct"
          :max-val="form.carb_max_pct"
          :editing="editing"
          @update:min-val="form.carb_min_pct = $event"
          @update:max-val="form.carb_max_pct = $event"
        />

        <!-- Fat range -->
        <MacroRangeRow
          label="Fat"
          color="rose"
          :min-val="form.fat_min_pct"
          :max-val="form.fat_max_pct"
          :editing="editing"
          @update:min-val="form.fat_min_pct = $event"
          @update:max-val="form.fat_max_pct = $event"
        />
      </div>

      <p v-if="errorMsg" class="text-sm text-red-600 bg-red-50 rounded-lg px-3 py-2">{{ errorMsg }}</p>
      <p v-if="successMsg" class="text-sm text-green-700 bg-green-50 rounded-lg px-3 py-2">{{ successMsg }}</p>
    </div>

    <!-- Current targets summary -->
    <div class="card bg-gray-50 border-gray-100">
      <p class="text-xs font-medium text-gray-500 uppercase tracking-wide mb-3">Current targets at {{ form.target_kcal }} kcal</p>
      <div class="space-y-2">
        <TargetSummaryRow label="Protein" color="blue"
          :min-g="pctToG(form.prot_min_pct, 4)"
          :max-g="pctToG(form.prot_max_pct, 4)"
          :min-pct="form.prot_min_pct"
          :max-pct="form.prot_max_pct"
        />
        <TargetSummaryRow label="Carbs" color="amber"
          :min-g="pctToG(form.carb_min_pct, 4)"
          :max-g="pctToG(form.carb_max_pct, 4)"
          :min-pct="form.carb_min_pct"
          :max-pct="form.carb_max_pct"
        />
        <TargetSummaryRow label="Fat" color="rose"
          :min-g="pctToG(form.fat_min_pct, 9)"
          :max-g="pctToG(form.fat_max_pct, 9)"
          :min-pct="form.fat_min_pct"
          :max-pct="form.fat_max_pct"
        />
      </div>
    </div>

    <!-- Admin panel link -->
    <RouterLink v-if="adminStore.isAdmin" to="/admin"
      class="card flex items-center justify-between active:bg-gray-50">
      <div>
        <p class="font-medium text-gray-800">Admin — moderation queue</p>
        <p class="text-xs text-gray-400 mt-0.5">Review submitted ingredients & recipes</p>
      </div>
      <span class="text-gray-400">›</span>
    </RouterLink>

    <!-- Food visibility preference -->
    <div class="card space-y-3">
      <h2 class="font-semibold text-gray-800">Food library</h2>
      <div class="flex items-center justify-between gap-4">
        <div class="flex-1">
          <p class="text-sm font-medium text-gray-700">Show public ingredients & recipes</p>
          <p class="text-xs text-gray-400 mt-0.5">When off, only your personal items appear in Foods and search.</p>
        </div>
        <button
          @click="togglePublicFoods"
          :class="[
            'relative shrink-0 w-12 h-6 rounded-full transition-colors duration-200',
            prefs.showPublicFoods.value ? 'bg-green-600' : 'bg-gray-300'
          ]"
        >
          <span :class="[
            'absolute top-0.5 left-0.5 w-5 h-5 bg-white rounded-full shadow transition-transform duration-200',
            prefs.showPublicFoods.value ? 'translate-x-6' : 'translate-x-0'
          ]" />
        </button>
      </div>
    </div>

    <!-- Sign out -->
    <button @click="handleLogout" class="btn-secondary text-red-500 border-red-100">
      Sign out
    </button>

  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue'
import { useRouter, RouterLink } from 'vue-router'
import { supabase } from '@/lib/supabase'
import { useAuthStore } from '@/stores/auth'
import { useAdminStore } from '@/stores/admin'
import { useUserPrefs } from '@/composables/useUserPrefs'

// Inline sub-components to keep things in one file
import { defineComponent, h } from 'vue'

const MacroRangeRow = defineComponent({
  props: {
    label: String,
    color: String,
    minVal: Number,
    maxVal: Number,
    editing: Boolean,
  },
  emits: ['update:minVal', 'update:maxVal'],
  setup(props, { emit }) {
    const colorMap = {
      blue:  'text-blue-700',
      amber: 'text-amber-600',
      rose:  'text-rose-500',
    }
    return () => h('div', { class: 'flex items-center gap-3' }, [
      h('span', { class: `text-xs font-medium w-12 ${colorMap[props.color]}` }, props.label),
      h('div', { class: 'flex-1 flex items-center gap-2' }, [
        h('input', {
          type: 'number', min: 0, max: 100, step: 1,
          value: props.minVal,
          disabled: !props.editing,
          onInput: e => emit('update:minVal', parseFloat(e.target.value)),
          class: 'input-field text-center text-sm py-1.5 px-2',
        }),
        h('span', { class: 'text-xs text-gray-400 shrink-0' }, '% – '),
        h('input', {
          type: 'number', min: 0, max: 100, step: 1,
          value: props.maxVal,
          disabled: !props.editing,
          onInput: e => emit('update:maxVal', parseFloat(e.target.value)),
          class: 'input-field text-center text-sm py-1.5 px-2',
        }),
        h('span', { class: 'text-xs text-gray-400 shrink-0' }, '%'),
      ]),
    ])
  },
})

const TargetSummaryRow = defineComponent({
  props: {
    label: String,
    color: String,
    minG: Number,
    maxG: Number,
    minPct: Number,
    maxPct: Number,
  },
  setup(props) {
    const colorMap = {
      blue:  'text-blue-700',
      amber: 'text-amber-600',
      rose:  'text-rose-500',
    }
    return () => h('div', { class: 'flex items-center justify-between text-sm' }, [
      h('span', { class: `font-medium ${colorMap[props.color]} w-14` }, props.label),
      h('span', { class: 'text-gray-600' },
        `${props.minPct}–${props.maxPct}% → ${props.minG.toFixed(0)}–${props.maxG.toFixed(0)}g`
      ),
    ])
  },
})

const auth = useAuthStore()
const router = useRouter()
const prefs = useUserPrefs()
const adminStore = useAdminStore()

async function togglePublicFoods() {
  await prefs.setShowPublicFoods(!prefs.showPublicFoods.value)
}

const editing = ref(false)
const saving = ref(false)
const errorMsg = ref('')
const successMsg = ref('')

const defaults = {
  target_kcal:  2000,
  carb_min_g:   135,
  prot_min_pct: 25,
  prot_max_pct: 35,
  carb_min_pct: 40,
  carb_max_pct: 50,
  fat_min_pct:  20,
  fat_max_pct:  35,
}

const form = reactive({ ...defaults })
let original = { ...defaults }

function pctToG(pct, kcalPerG) {
  return (form.target_kcal * pct / 100) / kcalPerG
}

async function loadTargets() {
  const { data } = await supabase
    .from('user_targets')
    .select('*')
    .eq('user_id', auth.user.id)
    .maybeSingle()

  if (data) {
    Object.assign(form, data)
    original = { ...form }
  }
}

function cancel() {
  Object.assign(form, original)
  editing.value = false
  errorMsg.value = ''
}

async function save() {
  saving.value = true
  errorMsg.value = ''
  successMsg.value = ''

  const { error } = await supabase
    .from('user_targets')
    .upsert({
      user_id:      auth.user.id,
      target_kcal:  form.target_kcal,
      carb_min_g:   form.carb_min_g,
      prot_min_pct: form.prot_min_pct,
      prot_max_pct: form.prot_max_pct,
      carb_min_pct: form.carb_min_pct,
      carb_max_pct: form.carb_max_pct,
      fat_min_pct:  form.fat_min_pct,
      fat_max_pct:  form.fat_max_pct,
      updated_at:   new Date().toISOString(),
    }, { onConflict: 'user_id' })

  if (error) {
    errorMsg.value = error.message
  } else {
    original = { ...form }
    editing.value = false
    successMsg.value = 'Targets saved.'
    setTimeout(() => successMsg.value = '', 3000)
  }
  saving.value = false
}

async function handleLogout() {
  await auth.logout()
  router.push({ name: 'Login' })
}

onMounted(() => { loadTargets(); prefs.load(); adminStore.init() })
</script>
