<template>
  <div class="flex flex-col h-full">

    <!-- Search bar -->
    <div class="sticky top-0 bg-gray-50 px-4 pt-4 pb-3 z-10">
      <div class="relative">
        <span class="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 text-lg">🔍</span>
        <input
          v-model="query"
          type="search"
          placeholder="Search ingredients or recipes…"
          class="input-field pl-10"
          autofocus
          @input="onSearch"
        />
      </div>

      <!-- Tabs -->
      <div class="flex gap-2 mt-3">
        <button
          v-for="tab in tabs"
          :key="tab.key"
          @click="activeTab = tab.key"
          :class="[
            'flex-1 py-2 text-sm font-medium rounded-xl transition-colors',
            activeTab === tab.key
              ? 'bg-green-600 text-white'
              : 'bg-white text-gray-500 border border-gray-200'
          ]"
        >
          {{ tab.label }}
        </button>
      </div>
    </div>

    <!-- Results list -->
    <div class="flex-1 overflow-y-auto px-4 pb-4">

      <div v-if="query.length < 2" class="py-12 text-center">
        <p class="text-3xl mb-2">🥗</p>
        <p class="text-sm text-gray-400">Type at least 2 characters to search</p>
      </div>

      <div v-else-if="loading" class="py-12 text-center text-sm text-gray-400">
        Searching…
      </div>

      <div v-else-if="results.length === 0" class="py-12 text-center">
        <p class="text-sm text-gray-400">No results for "<strong>{{ query }}</strong>"</p>
      </div>

      <ul v-else class="space-y-2 mt-2">
        <li
          v-for="item in results"
          :key="`${item.type}-${item.id}`"
          @click="selectItem(item)"
          class="card cursor-pointer active:bg-green-50 transition-colors"
        >
          <div class="flex items-center justify-between">
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2">
                <span class="text-[10px] font-medium px-2 py-0.5 rounded-full"
                  :class="item.type === 'recipe'
                    ? 'bg-purple-100 text-purple-700'
                    : 'bg-blue-100 text-blue-700'"
                >
                  {{ item.type === 'recipe' ? 'Recipe' : item.category || 'Food' }}
                </span>
                <p class="text-sm font-medium text-gray-800 truncate">{{ item.name }}</p>
              </div>
              <p class="text-xs text-gray-400 mt-0.5">
                {{ item.type === 'recipe'
                  ? item.unit === 'pc'
                    ? `${item.servings ?? '?'} pieces total`
                    : `${item.total_weight_g ?? '?'}g total`
                  : `per ${item.ref_quantity}${item.unit}`
                }}
              </p>
            </div>
            <div class="text-right ml-3 shrink-0">
              <p class="text-sm font-bold text-gray-800">{{ macroCalories(item).toFixed(0) }}</p>
              <p class="text-[10px] text-gray-400">kcal</p>
            </div>
          </div>

          <div class="flex gap-3 mt-2">
            <span class="text-[11px] text-blue-600">P {{ macroPer(item, 'protein').toFixed(1) }}g</span>
            <span class="text-[11px] text-amber-600">C {{ macroPer(item, 'carbs').toFixed(1) }}g</span>
            <span class="text-[11px] text-rose-500">F {{ macroPer(item, 'fat').toFixed(1) }}g</span>
          </div>
        </li>
      </ul>
    </div>

    <!-- Quantity bottom sheet -->
    <Transition name="sheet">
      <div v-if="selected" class="fixed inset-0 z-50 flex flex-col justify-end">
        <div class="absolute inset-0 bg-black/40" @click="selected = null" />

        <div class="relative bg-white rounded-t-2xl p-5 space-y-4 max-w-md w-full mx-auto">
          <div class="w-10 h-1 bg-gray-200 rounded-full mx-auto" />

          <div>
            <p class="text-xs text-gray-400 mb-0.5">
              {{ selected.type === 'recipe' ? 'Recipe' : selected.category }}
            </p>
            <h3 class="text-base font-semibold text-gray-900">{{ selected.name }}</h3>
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">
              Quantity
              <span class="text-gray-400 font-normal">
                ({{ selected.type === 'recipe' ? selected.unit : selected.unit }})
              </span>
            </label>
            <input
              v-model.number="quantity"
              type="number"
              min="0.1"
              step="0.1"
              class="input-field text-lg font-semibold"
              ref="qtyInput"
            />
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Time</label>
            <input v-model="logTime" type="time" class="input-field" />
          </div>

          <!-- Live macro preview -->
          <div class="bg-gray-50 rounded-xl p-3 grid grid-cols-4 gap-2 text-center">
            <div>
              <p class="text-base font-bold text-gray-800">{{ previewCalories.toFixed(0) }}</p>
              <p class="text-[10px] text-gray-400">kcal</p>
            </div>
            <div>
              <p class="text-base font-bold text-blue-700">{{ previewProtein.toFixed(1) }}</p>
              <p class="text-[10px] text-gray-400">prot g</p>
            </div>
            <div>
              <p class="text-base font-bold text-amber-600">{{ previewCarbs.toFixed(1) }}</p>
              <p class="text-[10px] text-gray-400">carbs g</p>
            </div>
            <div>
              <p class="text-base font-bold text-rose-500">{{ previewFat.toFixed(1) }}</p>
              <p class="text-[10px] text-gray-400">fat g</p>
            </div>
          </div>

          <input
            v-model="note"
            type="text"
            placeholder="Note (optional)"
            class="input-field text-sm"
          />

          <p v-if="errorMsg" class="text-sm text-red-600 bg-red-50 rounded-lg px-3 py-2">
            {{ errorMsg }}
          </p>

          <button
            @click="logMeal"
            class="btn-primary"
            :disabled="saving || !quantity || quantity <= 0"
          >
            {{ saving ? 'Saving…' : 'Log meal' }}
          </button>
        </div>
      </div>
    </Transition>

  </div>
</template>

<script setup>
import { ref, computed, nextTick, watch, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '@/lib/supabase'
import { useAuthStore } from '@/stores/auth'
import { useUserPrefs } from '@/composables/useUserPrefs'

const auth  = useAuthStore()
const router = useRouter()
const prefs = useUserPrefs()

const query = ref('')
const activeTab = ref('all')
const loading = ref(false)
const results = ref([])
const selected = ref(null)
const quantity = ref(1)
const note = ref('')
const saving = ref(false)
const errorMsg = ref('')
const qtyInput = ref(null)

const tabs = [
  { key: 'all',        label: 'All'         },
  { key: 'ingredient', label: 'Ingredients' },
  { key: 'recipe',     label: 'Recipes'     },
]

const nowTime = () => {
  const d = new Date()
  return `${String(d.getHours()).padStart(2,'0')}:${String(d.getMinutes()).padStart(2,'0')}`
}
const logTime = ref(nowTime())

let searchTimer = null

function onSearch() {
  clearTimeout(searchTimer)
  if (query.value.length < 2) { results.value = []; return }
  searchTimer = setTimeout(doSearch, 300)
}

async function doSearch() {
  loading.value = true
  results.value = []
  const q = query.value.trim()
  const promises = []

  if (activeTab.value !== 'recipe') {
    let qb = supabase
      .from('ingredients')
      .select('id, name, category, unit, ref_quantity, calories, protein_g, carbs_g, fat_g')
      .ilike('name', `%${q}%`)
      .limit(30)
    if (!prefs.showPublicFoods.value) qb = qb.eq('owner_user_id', auth.user.id)
    promises.push(qb.then(({ data }) => (data ?? []).map(r => ({ ...r, type: 'ingredient' }))))
  }

  if (activeTab.value !== 'ingredient') {
    let qb = supabase
      .from('recipes')
      .select('id, name, total_weight_g, servings, unit, calories_total, protein_total, carbs_total, fat_total, calories_per_unit, protein_per_unit, carbs_per_unit, fat_per_unit')
      .ilike('name', `%${q}%`)
      .limit(20)
    if (!prefs.showPublicFoods.value) qb = qb.eq('owner_user_id', auth.user.id)
    promises.push(qb.then(({ data }) => (data ?? []).map(r => ({ ...r, type: 'recipe' }))))
  }

  const all = (await Promise.all(promises)).flat()
  all.sort((a, b) => {
    const aq = a.name.toLowerCase().startsWith(q.toLowerCase()) ? 0 : 1
    const bq = b.name.toLowerCase().startsWith(q.toLowerCase()) ? 0 : 1
    return aq - bq || a.name.localeCompare(b.name, 'el')
  })

  results.value = all
  loading.value = false
}

watch(activeTab, () => { if (query.value.length >= 2) doSearch() })

function macroPer(item, macro) {
  if (item.type === 'recipe') {
    const map = { protein: 'protein_total', carbs: 'carbs_total', fat: 'fat_total' }
    return item[map[macro]] ?? 0
  }
  const map = { protein: 'protein_g', carbs: 'carbs_g', fat: 'fat_g' }
  return item[map[macro]] ?? 0
}

function macroCalories(item) {
  if (item.type === 'recipe') return item.calories_total ?? 0
  return item.calories ?? 0
}

async function selectItem(item) {
  selected.value = item
  // Default quantity: full batch weight for gr recipes, 1 piece for pc recipes, ref_quantity for ingredients
  if (item.type === 'recipe') {
    quantity.value = item.unit === 'pc' ? item.servings ?? 1 : item.total_weight_g ?? 100
  } else {
    quantity.value = item.ref_quantity ?? 100
  }
  note.value = ''
  errorMsg.value = ''
  logTime.value = nowTime()

  // Seed per-unit cache from pre-computed columns
  if (item.type === 'recipe' && !item._totalsLoaded) {
    item._calPerUnit   = item.calories_per_unit  ?? 0
    item._protPerUnit  = item.protein_per_unit   ?? 0
    item._carbsPerUnit = item.carbs_per_unit     ?? 0
    item._fatPerUnit   = item.fat_per_unit       ?? 0
    item._totalsLoaded = true
  }

  await nextTick()
  qtyInput.value?.focus()
  qtyInput.value?.select()
}

const previewCalories = computed(() => {
  if (!selected.value || !quantity.value) return 0
  const item = selected.value
  const qty = quantity.value
  if (item.type === 'recipe') return (item._calPerUnit ?? 0) * qty
  return (item.calories ?? 0) / (item.ref_quantity ?? 100) * qty
})

function calcMacro(macro) {
  if (!selected.value || !quantity.value) return 0
  const item = selected.value
  const qty = quantity.value
  if (item.type === 'recipe') {
    const map = { protein: '_protPerUnit', carbs: '_carbsPerUnit', fat: '_fatPerUnit' }
    return (item[map[macro]] ?? 0) * qty
  }
  const map = { protein: 'protein_g', carbs: 'carbs_g', fat: 'fat_g' }
  return (item[map[macro]] ?? 0) / (item.ref_quantity ?? 100) * qty
}

const previewProtein = computed(() => calcMacro('protein'))
const previewCarbs   = computed(() => calcMacro('carbs'))
const previewFat     = computed(() => calcMacro('fat'))

async function logMeal() {
  if (!quantity.value || quantity.value <= 0) return
  saving.value = true
  errorMsg.value = ''

  const item = selected.value
  const qty = quantity.value
  const [hh, mm] = logTime.value.split(':')
  const loggedAt = new Date()
  loggedAt.setHours(parseInt(hh), parseInt(mm), 0, 0)

  const row = {
    user_id:       auth.user.id,
    logged_at:     loggedAt.toISOString(),
    quantity:      qty,
    unit:          item.unit,
    note:          note.value || null,
    calories:      parseFloat(previewCalories.value.toFixed(2)),
    protein_g:     parseFloat(previewProtein.value.toFixed(2)),
    carbs_g:       parseFloat(previewCarbs.value.toFixed(2)),
    fat_g:         parseFloat(previewFat.value.toFixed(2)),
    recipe_id:     item.type === 'recipe'     ? item.id : null,
    ingredient_id: item.type === 'ingredient' ? item.id : null,
  }

  const { error } = await supabase.from('meal_log').insert(row)

  if (error) {
    errorMsg.value = error.message
    saving.value = false
    return
  }

  saving.value = false
  selected.value = null
  router.push({ name: 'Today' })
}

onMounted(() => prefs.load())
</script>

<style scoped>
.sheet-enter-active, .sheet-leave-active { transition: opacity 0.2s ease; }
.sheet-enter-active .relative, .sheet-leave-active .relative { transition: transform 0.25s ease; }
.sheet-enter-from, .sheet-leave-to { opacity: 0; }
.sheet-enter-from .relative { transform: translateY(100%); }
</style>

