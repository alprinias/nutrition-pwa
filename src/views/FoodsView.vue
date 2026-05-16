<template>
  <div class="flex flex-col h-full">

    <!-- Search + tabs -->
    <div class="sticky top-0 bg-gray-50 px-4 pt-4 pb-3 z-10">
      <div class="relative">
        <span class="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 text-lg">🔍</span>
        <input
          v-model="query"
          type="search"
          placeholder="Search ingredients or recipes…"
          class="input-field pl-10"
          @input="onSearch"
        />
      </div>
      <div class="flex gap-2 mt-3">
        <button
          v-for="tab in tabs"
          :key="tab.key"
          @click="switchTab(tab.key)"
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

      <!-- Category filter (ingredients only) -->
      <div v-if="activeTab === 'ingredient' && categories.length" class="flex gap-2 mt-2 overflow-x-auto pb-1 scrollbar-hide">
        <button
          @click="activeCategory = ''"
          :class="[
            'shrink-0 text-xs px-3 py-1.5 rounded-full font-medium transition-colors',
            activeCategory === '' ? 'bg-green-600 text-white' : 'bg-white text-gray-500 border border-gray-200'
          ]"
        >All</button>
        <button
          v-for="cat in categories"
          :key="cat"
          @click="activeCategory = cat"
          :class="[
            'shrink-0 text-xs px-3 py-1.5 rounded-full font-medium transition-colors',
            activeCategory === cat ? 'bg-green-600 text-white' : 'bg-white text-gray-500 border border-gray-200'
          ]"
        >{{ cat }}</button>
      </div>
    </div>

    <!-- List -->
    <div class="flex-1 overflow-y-auto px-4 pb-4">
      <div v-if="loading" class="py-12 text-center text-sm text-gray-400">Loading…</div>

      <div v-else-if="items.length === 0" class="py-12 text-center">
        <p class="text-3xl mb-2">🥗</p>
        <p class="text-sm text-gray-400">No results found.</p>
      </div>

      <ul v-else class="space-y-2 mt-2">
        <li
          v-for="item in items"
          :key="item.id"
          @click="select(item)"
          class="card cursor-pointer active:bg-green-50 transition-colors"
        >
          <!-- Ingredient row -->
          <template v-if="activeTab === 'ingredient'">
            <div class="flex items-start justify-between gap-3">
              <div class="flex-1 min-w-0">
                <div class="flex items-center gap-2 flex-wrap">
                  <span class="text-[10px] font-medium px-2 py-0.5 rounded-full bg-blue-100 text-blue-700 shrink-0">
                    {{ item.category || '—' }}
                  </span>
                  <p class="text-sm font-medium text-gray-800">{{ item.name }}</p>
                </div>
                <p class="text-xs text-gray-400 mt-0.5">per {{ item.ref_quantity }}{{ item.unit }}</p>
                <div class="flex gap-3 mt-1.5">
                  <span class="text-[11px] text-blue-600">P {{ item.protein_g.toFixed(1) }}g</span>
                  <span class="text-[11px] text-amber-600">C {{ item.carbs_g.toFixed(1) }}g</span>
                  <span class="text-[11px] text-rose-500">F {{ item.fat_g.toFixed(1) }}g</span>
                </div>
              </div>
              <div class="text-right shrink-0">
                <p class="text-sm font-bold text-gray-800">{{ item.calories.toFixed(0) }}</p>
                <p class="text-[10px] text-gray-400">kcal</p>
              </div>
            </div>
          </template>

          <!-- Recipe row -->
          <template v-else>
            <div class="flex items-start justify-between gap-3">
              <div class="flex-1 min-w-0">
                <div class="flex items-center gap-2">
                  <span class="text-[10px] font-medium px-2 py-0.5 rounded-full bg-purple-100 text-purple-700 shrink-0">
                    {{ item.unit === 'pc' ? 'pieces' : 'by weight' }}
                  </span>
                  <p class="text-sm font-medium text-gray-800">{{ item.name }}</p>
                </div>
                <p class="text-xs text-gray-400 mt-0.5">
                  {{ item.unit === 'pc'
                    ? `${item.servings} pc total`
                    : `${item.total_weight_g ?? '?'}g total` }}
                </p>
                <div class="flex gap-3 mt-1.5">
                  <span class="text-[11px] text-blue-600">P {{ (item.protein_total ?? 0).toFixed(1) }}g</span>
                  <span class="text-[11px] text-amber-600">C {{ (item.carbs_total ?? 0).toFixed(1) }}g</span>
                  <span class="text-[11px] text-rose-500">F {{ (item.fat_total ?? 0).toFixed(1) }}g</span>
                </div>
              </div>
              <div class="text-right shrink-0">
                <p class="text-sm font-bold text-gray-800">{{ (item.calories_total ?? 0).toFixed(0) }}</p>
                <p class="text-[10px] text-gray-400">kcal total</p>
              </div>
            </div>
          </template>
        </li>
      </ul>

      <!-- Load more -->
      <div v-if="hasMore && !loading" class="mt-4 text-center">
        <button @click="loadMore" class="btn-secondary" :disabled="loadingMore">
          {{ loadingMore ? 'Loading…' : 'Load more' }}
        </button>
      </div>
    </div>

    <!-- Detail bottom sheet -->
    <Transition name="sheet">
      <div v-if="selected" class="fixed inset-0 z-50 flex flex-col justify-end">
        <div class="absolute inset-0 bg-black/40" @click="selected = null" />
        <div class="relative bg-white rounded-t-2xl p-5 w-full max-w-md mx-auto space-y-4 max-h-[80vh] overflow-y-auto">
          <div class="w-10 h-1 bg-gray-200 rounded-full mx-auto" />

          <!-- Header -->
          <div>
            <span class="text-xs font-medium px-2 py-0.5 rounded-full"
              :class="activeTab === 'recipe' ? 'bg-purple-100 text-purple-700' : 'bg-blue-100 text-blue-700'"
            >
              {{ activeTab === 'recipe' ? 'Recipe' : selected.category }}
            </span>
            <h3 class="text-lg font-semibold text-gray-900 mt-1">{{ selected.name }}</h3>
            <p class="text-sm text-gray-400" v-if="activeTab === 'ingredient'">
              per {{ selected.ref_quantity }}{{ selected.unit }}
            </p>
            <p class="text-sm text-gray-400" v-else>
              {{ selected.unit === 'pc'
                ? `${selected.servings} pieces total`
                : `${selected.total_weight_g ?? '?'}g total` }}
            </p>
          </div>

          <!-- Macro grid -->
          <div class="grid grid-cols-2 gap-3">
            <div class="bg-gray-50 rounded-xl p-3 text-center">
              <p class="text-xl font-bold text-gray-900">
                {{ activeTab === 'ingredient'
                  ? (selected.calories ?? 0).toFixed(0)
                  : (selected.calories_total ?? 0).toFixed(0) }}
              </p>
              <p class="text-xs text-gray-400 mt-0.5">kcal</p>
            </div>
            <div class="bg-blue-50 rounded-xl p-3 text-center">
              <p class="text-xl font-bold text-blue-700">
                {{ activeTab === 'ingredient'
                  ? (selected.protein_g ?? 0).toFixed(1)
                  : (selected.protein_total ?? 0).toFixed(1) }}g
              </p>
              <p class="text-xs text-gray-400 mt-0.5">protein</p>
            </div>
            <div class="bg-amber-50 rounded-xl p-3 text-center">
              <p class="text-xl font-bold text-amber-600">
                {{ activeTab === 'ingredient'
                  ? (selected.carbs_g ?? 0).toFixed(1)
                  : (selected.carbs_total ?? 0).toFixed(1) }}g
              </p>
              <p class="text-xs text-gray-400 mt-0.5">carbs</p>
            </div>
            <div class="bg-rose-50 rounded-xl p-3 text-center">
              <p class="text-xl font-bold text-rose-500">
                {{ activeTab === 'ingredient'
                  ? (selected.fat_g ?? 0).toFixed(1)
                  : (selected.fat_total ?? 0).toFixed(1) }}g
              </p>
              <p class="text-xs text-gray-400 mt-0.5">fat</p>
            </div>
          </div>

          <!-- Per-unit breakdown for recipes -->
          <div v-if="activeTab === 'recipe'" class="bg-gray-50 rounded-xl p-3">
            <p class="text-xs font-medium text-gray-600 mb-2">
              Per {{ selected.unit === 'pc' ? 'piece' : '100g' }}
            </p>
            <div class="grid grid-cols-4 gap-2 text-center">
              <div>
                <p class="text-sm font-bold text-gray-800">
                  {{ selected.unit === 'pc'
                    ? (selected.calories_per_unit ?? 0).toFixed(0)
                    : ((selected.calories_per_unit ?? 0) * 100).toFixed(0) }}
                </p>
                <p class="text-[10px] text-gray-400">kcal</p>
              </div>
              <div>
                <p class="text-sm font-bold text-blue-700">
                  {{ selected.unit === 'pc'
                    ? (selected.protein_per_unit ?? 0).toFixed(1)
                    : ((selected.protein_per_unit ?? 0) * 100).toFixed(1) }}g
                </p>
                <p class="text-[10px] text-gray-400">prot</p>
              </div>
              <div>
                <p class="text-sm font-bold text-amber-600">
                  {{ selected.unit === 'pc'
                    ? (selected.carbs_per_unit ?? 0).toFixed(1)
                    : ((selected.carbs_per_unit ?? 0) * 100).toFixed(1) }}g
                </p>
                <p class="text-[10px] text-gray-400">carbs</p>
              </div>
              <div>
                <p class="text-sm font-bold text-rose-500">
                  {{ selected.unit === 'pc'
                    ? (selected.fat_per_unit ?? 0).toFixed(1)
                    : ((selected.fat_per_unit ?? 0) * 100).toFixed(1) }}g
                </p>
                <p class="text-[10px] text-gray-400">fat</p>
              </div>
            </div>
          </div>

          <!-- Recipe ingredients list -->
          <div v-if="activeTab === 'recipe'">
            <p class="text-xs font-medium text-gray-600 mb-2">Ingredients</p>
            <div v-if="loadingIngredients" class="text-sm text-gray-400 text-center py-3">Loading…</div>
            <ul v-else class="space-y-1.5">
              <li
                v-for="ri in recipeIngredients"
                :key="ri.id"
                class="flex items-center justify-between text-sm"
              >
                <span class="text-gray-700">{{ ri.ingredients.name }}</span>
                <span class="text-gray-400 text-xs">{{ ri.quantity }}{{ ri.unit }}</span>
              </li>
            </ul>
          </div>

          <!-- Log this button -->
          <RouterLink
            :to="{ name: 'AddMeal' }"
            @click="selected = null"
            class="btn-primary text-center block"
          >
            Log this
          </RouterLink>
        </div>
      </div>
    </Transition>

  </div>
</template>

<script setup>
import { ref, watch, onMounted } from 'vue'
import { RouterLink } from 'vue-router'
import { supabase } from '@/lib/supabase'

const PAGE_SIZE = 30

const query = ref('')
const activeTab = ref('ingredient')
const activeCategory = ref('')
const items = ref([])
const categories = ref([])
const loading = ref(true)
const loadingMore = ref(false)
const hasMore = ref(false)
const offset = ref(0)
const selected = ref(null)
const recipeIngredients = ref([])
const loadingIngredients = ref(false)

const tabs = [
  { key: 'ingredient', label: 'Ingredients' },
  { key: 'recipe',     label: 'Recipes'     },
]

// ── load categories ───────────────────────────────────────────────────────────
async function loadCategories() {
  const { data } = await supabase
    .from('ingredients')
    .select('category')
    .neq('category', null)
    .order('category')
  const unique = [...new Set((data ?? []).map(r => r.category).filter(Boolean))]
  categories.value = unique
}

// ── fetch ─────────────────────────────────────────────────────────────────────
async function fetch(reset = true) {
  if (reset) {
    offset.value = 0
    items.value = []
    loading.value = true
  } else {
    loadingMore.value = true
  }

  const q = query.value.trim()

  let data = []

  if (activeTab.value === 'ingredient') {
    let qb = supabase
      .from('ingredients')
      .select('id, name, category, unit, ref_quantity, calories, protein_g, carbs_g, fat_g')
      .order('name')
      .range(offset.value, offset.value + PAGE_SIZE - 1)

    if (q) qb = qb.ilike('name', `%${q}%`)
    if (activeCategory.value) qb = qb.eq('category', activeCategory.value)

    const res = await qb
    data = res.data ?? []
  } else {
    let qb = supabase
      .from('recipes')
      .select('id, name, unit, total_weight_g, servings, calories_total, protein_total, carbs_total, fat_total, calories_per_unit, protein_per_unit, carbs_per_unit, fat_per_unit')
      .order('name')
      .range(offset.value, offset.value + PAGE_SIZE - 1)

    if (q) qb = qb.ilike('name', `%${q}%`)

    const res = await qb
    data = res.data ?? []
  }

  hasMore.value = data.length === PAGE_SIZE
  offset.value += data.length

  if (reset) {
    items.value = data
  } else {
    items.value = [...items.value, ...data]
  }

  loading.value = false
  loadingMore.value = false
}

function loadMore() { fetch(false) }

// ── search debounce ───────────────────────────────────────────────────────────
let searchTimer = null
function onSearch() {
  clearTimeout(searchTimer)
  searchTimer = setTimeout(() => fetch(true), 300)
}

function switchTab(key) {
  activeTab.value = key
  activeCategory.value = ''
  query.value = ''
  fetch(true)
}

watch(activeCategory, () => fetch(true))

// ── detail sheet ──────────────────────────────────────────────────────────────
async function select(item) {
  selected.value = item
  recipeIngredients.value = []

  if (activeTab.value === 'recipe') {
    loadingIngredients.value = true
    const { data } = await supabase
      .from('recipe_items')
      .select('id, quantity, unit, ingredients ( name )')
      .eq('recipe_id', item.id)
      .order('id')
    recipeIngredients.value = data ?? []
    loadingIngredients.value = false
  }
}

onMounted(() => {
  loadCategories()
  fetch(true)
})
</script>

<style scoped>
.sheet-enter-active, .sheet-leave-active { transition: opacity 0.2s ease; }
.sheet-enter-from, .sheet-leave-to { opacity: 0; }
.scrollbar-hide { -ms-overflow-style: none; scrollbar-width: none; }
.scrollbar-hide::-webkit-scrollbar { display: none; }
</style>
