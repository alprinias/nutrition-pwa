<template>
  <div class="flex flex-col h-full">

    <!-- Search + tabs -->
    <div class="sticky top-0 bg-gray-50 px-4 pt-4 pb-3 z-10">
      <div class="flex gap-2 mb-3">
        <div class="relative flex-1">
          <span class="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400">🔍</span>
          <input v-model="query" type="search" placeholder="Search…"
            class="input-field pl-10" @input="onSearch" />
        </div>
        <!-- Admin: new item button -->
        <button v-if="admin.isAdmin" @click="openNew"
          class="shrink-0 px-3 py-2 bg-green-600 text-white rounded-xl text-lg font-bold active:bg-green-700">
          ＋
        </button>
      </div>

      <div class="flex gap-2">
        <button v-for="tab in tabs" :key="tab.key" @click="switchTab(tab.key)"
          :class="['flex-1 py-2 text-sm font-medium rounded-xl transition-colors',
            activeTab === tab.key ? 'bg-green-600 text-white' : 'bg-white text-gray-500 border border-gray-200']">
          {{ tab.label }}
        </button>
      </div>

      <!-- Category filter (ingredients) -->
      <div v-if="activeTab === 'ingredient' && categories.length"
        class="flex gap-2 mt-2 overflow-x-auto pb-1 scrollbar-hide">
        <button @click="activeCategory = ''"
          :class="['shrink-0 text-xs px-3 py-1.5 rounded-full font-medium transition-colors',
            activeCategory === '' ? 'bg-green-600 text-white' : 'bg-white text-gray-500 border border-gray-200']">
          All</button>
        <button v-for="cat in categories" :key="cat" @click="activeCategory = cat"
          :class="['shrink-0 text-xs px-3 py-1.5 rounded-full font-medium transition-colors',
            activeCategory === cat ? 'bg-green-600 text-white' : 'bg-white text-gray-500 border border-gray-200']">
          {{ cat }}</button>
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
        <li v-for="item in items" :key="item.id" @click="select(item)"
          class="card cursor-pointer active:bg-green-50 transition-colors">
          <template v-if="activeTab === 'ingredient'">
            <div class="flex items-start justify-between gap-3">
              <div class="flex-1 min-w-0">
                <div class="flex items-center gap-2 flex-wrap">
                  <span class="text-[10px] font-medium px-2 py-0.5 rounded-full bg-blue-100 text-blue-700 shrink-0">
                    {{ item.category || '—' }}</span>
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
          <template v-else>
            <div class="flex items-start justify-between gap-3">
              <div class="flex-1 min-w-0">
                <div class="flex items-center gap-2">
                  <span class="text-[10px] font-medium px-2 py-0.5 rounded-full bg-purple-100 text-purple-700 shrink-0">
                    {{ item.unit === 'pc' ? 'pieces' : 'by weight' }}</span>
                  <p class="text-sm font-medium text-gray-800">{{ item.name }}</p>
                </div>
                <p class="text-xs text-gray-400 mt-0.5">
                  {{ item.unit === 'pc' ? `${item.servings} pc total` : `${item.total_weight_g ?? '?'}g total` }}</p>
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
      <div v-if="hasMore && !loading" class="mt-4 text-center">
        <button @click="loadMore" class="btn-secondary" :disabled="loadingMore">
          {{ loadingMore ? 'Loading…' : 'Load more' }}</button>
      </div>
    </div>

    <!-- ── DETAIL SHEET ── -->
    <Transition name="sheet">
      <div v-if="selected" class="fixed inset-0 z-50 flex flex-col justify-end">
        <div class="absolute inset-0 bg-black/40" @click="selected = null" />
        <div class="relative bg-white rounded-t-2xl p-5 w-full max-w-md mx-auto space-y-4 max-h-[85vh] overflow-y-auto">
          <div class="w-10 h-1 bg-gray-200 rounded-full mx-auto" />

          <!-- Header with admin actions -->
          <div class="flex items-start justify-between gap-3">
            <div class="flex-1 min-w-0">
              <span class="text-xs font-medium px-2 py-0.5 rounded-full"
                :class="activeTab === 'recipe' ? 'bg-purple-100 text-purple-700' : 'bg-blue-100 text-blue-700'">
                {{ activeTab === 'recipe' ? 'Recipe' : selected.category }}</span>
              <h3 class="text-lg font-semibold text-gray-900 mt-1">{{ selected.name }}</h3>
              <p class="text-sm text-gray-400">
                {{ activeTab === 'ingredient'
                  ? `per ${selected.ref_quantity}${selected.unit}`
                  : selected.unit === 'pc'
                    ? `${selected.servings} pieces total`
                    : `${selected.total_weight_g ?? '?'}g total` }}
              </p>
            </div>
            <!-- Admin edit/delete buttons -->
            <div v-if="admin.isAdmin" class="flex gap-2 shrink-0">
              <button @click="openEdit(selected)"
                class="px-3 py-1.5 text-xs font-medium bg-blue-50 text-blue-700 rounded-lg active:bg-blue-100">
                ✏️ Edit</button>
              <button @click="confirmDelete(selected)"
                class="px-3 py-1.5 text-xs font-medium bg-red-50 text-red-600 rounded-lg active:bg-red-100">
                🗑️</button>
            </div>
          </div>

          <!-- Macro grid -->
          <div class="grid grid-cols-2 gap-3">
            <div class="bg-gray-50 rounded-xl p-3 text-center">
              <p class="text-xl font-bold text-gray-900">
                {{ activeTab === 'ingredient' ? (selected.calories ?? 0).toFixed(0) : (selected.calories_total ?? 0).toFixed(0) }}</p>
              <p class="text-xs text-gray-400 mt-0.5">kcal</p>
            </div>
            <div class="bg-blue-50 rounded-xl p-3 text-center">
              <p class="text-xl font-bold text-blue-700">
                {{ activeTab === 'ingredient' ? (selected.protein_g ?? 0).toFixed(1) : (selected.protein_total ?? 0).toFixed(1) }}g</p>
              <p class="text-xs text-gray-400 mt-0.5">protein</p>
            </div>
            <div class="bg-amber-50 rounded-xl p-3 text-center">
              <p class="text-xl font-bold text-amber-600">
                {{ activeTab === 'ingredient' ? (selected.carbs_g ?? 0).toFixed(1) : (selected.carbs_total ?? 0).toFixed(1) }}g</p>
              <p class="text-xs text-gray-400 mt-0.5">carbs</p>
            </div>
            <div class="bg-rose-50 rounded-xl p-3 text-center">
              <p class="text-xl font-bold text-rose-500">
                {{ activeTab === 'ingredient' ? (selected.fat_g ?? 0).toFixed(1) : (selected.fat_total ?? 0).toFixed(1) }}g</p>
              <p class="text-xs text-gray-400 mt-0.5">fat</p>
            </div>
          </div>

          <!-- Recipe per-unit + ingredients -->
          <template v-if="activeTab === 'recipe'">
            <div class="bg-gray-50 rounded-xl p-3">
              <p class="text-xs font-medium text-gray-600 mb-2">Per {{ selected.unit === 'pc' ? 'piece' : '100g' }}</p>
              <div class="grid grid-cols-4 gap-2 text-center">
                <div>
                  <p class="text-sm font-bold text-gray-800">
                    {{ selected.unit === 'pc' ? (selected.calories_per_unit ?? 0).toFixed(0) : ((selected.calories_per_unit ?? 0) * 100).toFixed(0) }}</p>
                  <p class="text-[10px] text-gray-400">kcal</p>
                </div>
                <div>
                  <p class="text-sm font-bold text-blue-700">
                    {{ selected.unit === 'pc' ? (selected.protein_per_unit ?? 0).toFixed(1) : ((selected.protein_per_unit ?? 0) * 100).toFixed(1) }}g</p>
                  <p class="text-[10px] text-gray-400">prot</p>
                </div>
                <div>
                  <p class="text-sm font-bold text-amber-600">
                    {{ selected.unit === 'pc' ? (selected.carbs_per_unit ?? 0).toFixed(1) : ((selected.carbs_per_unit ?? 0) * 100).toFixed(1) }}g</p>
                  <p class="text-[10px] text-gray-400">carbs</p>
                </div>
                <div>
                  <p class="text-sm font-bold text-rose-500">
                    {{ selected.unit === 'pc' ? (selected.fat_per_unit ?? 0).toFixed(1) : ((selected.fat_per_unit ?? 0) * 100).toFixed(1) }}g</p>
                  <p class="text-[10px] text-gray-400">fat</p>
                </div>
              </div>
            </div>
            <div>
              <p class="text-xs font-medium text-gray-600 mb-2">Ingredients</p>
              <div v-if="loadingIngredients" class="text-sm text-gray-400 text-center py-3">Loading…</div>
              <ul v-else class="space-y-1.5">
                <li v-for="ri in recipeIngredients" :key="ri.id"
                  class="flex items-center justify-between text-sm">
                  <span class="text-gray-700">{{ ri.ingredients.name }}</span>
                  <span class="text-gray-400 text-xs">{{ ri.quantity }}{{ ri.unit }}</span>
                </li>
              </ul>
            </div>
          </template>

          <RouterLink :to="{ name: 'AddMeal' }" @click="selected = null" class="btn-primary text-center block">
            Log this</RouterLink>
        </div>
      </div>
    </Transition>

    <!-- ── INGREDIENT FORM SHEET ── -->
    <Transition name="sheet">
      <div v-if="ingForm.open" class="fixed inset-0 z-50 flex flex-col justify-end">
        <div class="absolute inset-0 bg-black/40" @click="ingForm.open = false" />
        <div class="relative bg-white rounded-t-2xl p-5 w-full max-w-md mx-auto space-y-3 max-h-[90vh] overflow-y-auto">
          <div class="w-10 h-1 bg-gray-200 rounded-full mx-auto" />
          <h3 class="font-semibold text-gray-900">{{ ingForm.id ? 'Edit ingredient' : 'New ingredient' }}</h3>

          <div>
            <label class="block text-xs text-gray-500 mb-1">Name *</label>
            <input v-model="ingForm.name" type="text" class="input-field" placeholder="e.g. Κοτόπουλο Στήθος" />
          </div>
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="block text-xs text-gray-500 mb-1">Category</label>
              <input v-model="ingForm.category" type="text" class="input-field" placeholder="e.g. Πουλερικά" list="cat-list" />
              <datalist id="cat-list">
                <option v-for="c in categories" :key="c" :value="c" />
              </datalist>
            </div>
            <div>
              <label class="block text-xs text-gray-500 mb-1">Unit</label>
              <select v-model="ingForm.unit" class="input-field">
                <option value="gr">gr</option>
                <option value="slc">slc</option>
                <option value="pc">pc</option>
              </select>
            </div>
          </div>
          <div>
            <label class="block text-xs text-gray-500 mb-1">Reference quantity</label>
            <input v-model.number="ingForm.ref_quantity" type="number" class="input-field" />
          </div>

          <p class="text-xs font-medium text-gray-500 uppercase tracking-wide pt-1">
            Macros per reference quantity</p>
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="block text-xs text-gray-500 mb-1">Calories (kcal)</label>
              <input v-model.number="ingForm.calories" type="number" step="0.1" class="input-field" />
            </div>
            <div>
              <label class="block text-xs text-gray-500 mb-1">Protein (g)</label>
              <input v-model.number="ingForm.protein_g" type="number" step="0.1" class="input-field" />
            </div>
            <div>
              <label class="block text-xs text-gray-500 mb-1">Carbs (g)</label>
              <input v-model.number="ingForm.carbs_g" type="number" step="0.1" class="input-field" />
            </div>
            <div>
              <label class="block text-xs text-gray-500 mb-1">Fat (g)</label>
              <input v-model.number="ingForm.fat_g" type="number" step="0.1" class="input-field" />
            </div>
            <div>
              <label class="block text-xs text-gray-500 mb-1">Sodium (mg)</label>
              <input v-model.number="ingForm.sodium_mg" type="number" step="1" class="input-field" />
            </div>
          </div>

          <p v-if="formError" class="text-sm text-red-600 bg-red-50 rounded-lg px-3 py-2">{{ formError }}</p>
          <div class="flex gap-3 pt-1">
            <button @click="ingForm.open = false" class="btn-secondary">Cancel</button>
            <button @click="saveIngredient" class="btn-primary" :disabled="formSaving">
              {{ formSaving ? 'Saving…' : 'Save' }}</button>
          </div>
        </div>
      </div>
    </Transition>

    <!-- ── RECIPE FORM SHEET ── -->
    <Transition name="sheet">
      <div v-if="recForm.open" class="fixed inset-0 z-50 flex flex-col justify-end">
        <div class="absolute inset-0 bg-black/40" @click="recForm.open = false" />
        <div class="relative bg-white rounded-t-2xl p-5 w-full max-w-md mx-auto space-y-3 max-h-[90vh] overflow-y-auto">
          <div class="w-10 h-1 bg-gray-200 rounded-full mx-auto" />
          <h3 class="font-semibold text-gray-900">{{ recForm.id ? 'Edit recipe' : 'New recipe' }}</h3>

          <div>
            <label class="block text-xs text-gray-500 mb-1">Name *</label>
            <input v-model="recForm.name" type="text" class="input-field" placeholder="e.g. Κοτόπουλο Κόκκινο" />
          </div>
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="block text-xs text-gray-500 mb-1">Unit</label>
              <select v-model="recForm.unit" class="input-field">
                <option value="gr">By weight (gr)</option>
                <option value="pc">By pieces (pc)</option>
              </select>
            </div>
            <div>
              <label class="block text-xs text-gray-500 mb-1">
                {{ recForm.unit === 'pc' ? 'Total pieces' : 'Total weight (g)' }}
              </label>
              <input v-model.number="recForm.total_weight_g" type="number" class="input-field" />
            </div>
          </div>

          <!-- Ingredient lines -->
          <div>
            <div class="flex items-center justify-between mb-2">
              <p class="text-xs font-medium text-gray-500 uppercase tracking-wide">Ingredients</p>
              <button @click="addIngLine" class="text-xs text-green-600 font-medium">+ Add</button>
            </div>
            <div v-for="(line, idx) in recForm.items" :key="idx" class="flex gap-2 mb-2 items-center">
              <div class="flex-1 relative">
                <input
                  v-model="line.search"
                  type="text"
                  class="input-field text-sm py-2"
                  placeholder="Search ingredient…"
                  @input="searchIngredient(line)"
                  @focus="line.showDropdown = true"
                />
                <!-- Dropdown -->
                <ul v-if="line.showDropdown && line.suggestions.length"
                  class="absolute z-10 w-full bg-white border border-gray-200 rounded-xl shadow-lg max-h-40 overflow-y-auto mt-1">
                  <li v-for="s in line.suggestions" :key="s.id"
                    @mousedown.prevent="pickIngredient(line, s)"
                    class="px-3 py-2 text-sm hover:bg-green-50 cursor-pointer">
                    {{ s.name }}
                    <span class="text-xs text-gray-400 ml-1">{{ s.ref_quantity }}{{ s.unit }}</span>
                  </li>
                </ul>
              </div>
              <input v-model.number="line.quantity" type="number" step="0.1"
                class="input-field text-sm py-2 w-20 text-center" placeholder="qty" />
              <span class="text-xs text-gray-400 w-6 shrink-0">{{ line.unit || 'gr' }}</span>
              <button @click="recForm.items.splice(idx, 1)" class="text-gray-300 active:text-red-500 text-lg">✕</button>
            </div>
          </div>

          <!-- Live macro preview -->
          <div v-if="recipePreview.calories > 0" class="bg-gray-50 rounded-xl p-3 grid grid-cols-4 gap-2 text-center">
            <div>
              <p class="text-sm font-bold text-gray-800">{{ recipePreview.calories.toFixed(0) }}</p>
              <p class="text-[10px] text-gray-400">kcal</p>
            </div>
            <div>
              <p class="text-sm font-bold text-blue-700">{{ recipePreview.protein.toFixed(1) }}g</p>
              <p class="text-[10px] text-gray-400">prot</p>
            </div>
            <div>
              <p class="text-sm font-bold text-amber-600">{{ recipePreview.carbs.toFixed(1) }}g</p>
              <p class="text-[10px] text-gray-400">carbs</p>
            </div>
            <div>
              <p class="text-sm font-bold text-rose-500">{{ recipePreview.fat.toFixed(1) }}g</p>
              <p class="text-[10px] text-gray-400">fat</p>
            </div>
          </div>

          <p v-if="formError" class="text-sm text-red-600 bg-red-50 rounded-lg px-3 py-2">{{ formError }}</p>
          <div class="flex gap-3 pt-1">
            <button @click="recForm.open = false" class="btn-secondary">Cancel</button>
            <button @click="saveRecipe" class="btn-primary" :disabled="formSaving">
              {{ formSaving ? 'Saving…' : 'Save' }}</button>
          </div>
        </div>
      </div>
    </Transition>

    <!-- ── DELETE CONFIRM ── -->
    <Transition name="sheet">
      <div v-if="deleteTarget" class="fixed inset-0 z-50 flex items-end justify-center">
        <div class="absolute inset-0 bg-black/40" @click="deleteTarget = null" />
        <div class="relative bg-white rounded-t-2xl p-5 w-full max-w-md mx-auto space-y-4">
          <div class="w-10 h-1 bg-gray-200 rounded-full mx-auto" />
          <p class="font-semibold text-gray-900 text-center">Delete "{{ deleteTarget.name }}"?</p>
          <p class="text-sm text-gray-500 text-center">This cannot be undone.</p>
          <p v-if="deleteError" class="text-sm text-red-600 bg-red-50 rounded-lg px-3 py-2 text-center">{{ deleteError }}</p>
          <div class="flex gap-3">
            <button @click="deleteTarget = null" class="btn-secondary">Cancel</button>
            <button @click="doDelete"
              class="flex-1 py-3 px-4 bg-red-500 text-white font-medium rounded-xl active:bg-red-600"
              :disabled="deleteLoading">
              {{ deleteLoading ? 'Deleting…' : 'Delete' }}</button>
          </div>
        </div>
      </div>
    </Transition>

  </div>
</template>

<script setup>
import { ref, reactive, computed, watch, onMounted } from 'vue'
import { RouterLink } from 'vue-router'
import { supabase } from '@/lib/supabase'
import { useAdminStore } from '@/stores/admin'

const admin = useAdminStore()

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

// ── Fetch list ────────────────────────────────────────────────────────────────
async function fetchItems(reset = true) {
  if (reset) { offset.value = 0; items.value = []; loading.value = true }
  else loadingMore.value = true

  const q = query.value.trim()
  let data = []

  if (activeTab.value === 'ingredient') {
    let qb = supabase.from('ingredients')
      .select('id, name, category, unit, ref_quantity, calories, protein_g, carbs_g, fat_g')
      .order('name').range(offset.value, offset.value + PAGE_SIZE - 1)
    if (q) qb = qb.ilike('name', `%${q}%`)
    if (activeCategory.value) qb = qb.eq('category', activeCategory.value)
    const res = await qb; data = res.data ?? []
  } else {
    let qb = supabase.from('recipes')
      .select('id, name, unit, total_weight_g, servings, calories_total, protein_total, carbs_total, fat_total, calories_per_unit, protein_per_unit, carbs_per_unit, fat_per_unit')
      .order('name').range(offset.value, offset.value + PAGE_SIZE - 1)
    if (q) qb = qb.ilike('name', `%${q}%`)
    const res = await qb; data = res.data ?? []
  }

  hasMore.value = data.length === PAGE_SIZE
  offset.value += data.length
  items.value = reset ? data : [...items.value, ...data]
  loading.value = false; loadingMore.value = false
}

async function loadCategories() {
  const { data } = await supabase.from('ingredients').select('category').neq('category', null).order('category')
  categories.value = [...new Set((data ?? []).map(r => r.category).filter(Boolean))]
}

function loadMore() { fetchItems(false) }

let searchTimer = null
function onSearch() {
  clearTimeout(searchTimer)
  searchTimer = setTimeout(() => fetchItems(true), 300)
}
function switchTab(key) { activeTab.value = key; activeCategory.value = ''; query.value = ''; fetchItems(true) }
watch(activeCategory, () => fetchItems(true))

async function select(item) {
  selected.value = item; recipeIngredients.value = []
  if (activeTab.value === 'recipe') {
    loadingIngredients.value = true
    const { data } = await supabase.from('recipe_items')
      .select('id, quantity, unit, ingredients ( name )')
      .eq('recipe_id', item.id).order('id')
    recipeIngredients.value = data ?? []
    loadingIngredients.value = false
  }
}

// ── Ingredient form ───────────────────────────────────────────────────────────
const ingForm = reactive({
  open: false, id: null,
  name: '', category: '', unit: 'gr', ref_quantity: 100,
  calories: 0, protein_g: 0, carbs_g: 0, fat_g: 0, sodium_mg: null,
})
const formError  = ref('')
const formSaving = ref(false)

function openNew() {
  formError.value = ''
  if (activeTab.value === 'ingredient') {
    Object.assign(ingForm, { open: true, id: null, name: '', category: '', unit: 'gr',
      ref_quantity: 100, calories: 0, protein_g: 0, carbs_g: 0, fat_g: 0, sodium_mg: null })
  } else {
    Object.assign(recForm, { open: true, id: null, name: '', unit: 'gr', total_weight_g: null, items: [] })
  }
}

function openEdit(item) {
  selected.value = null; formError.value = ''
  if (activeTab.value === 'ingredient') {
    Object.assign(ingForm, { open: true, ...item })
  } else {
    Object.assign(recForm, {
      open: true, id: item.id, name: item.name, unit: item.unit,
      total_weight_g: item.unit === 'pc' ? item.servings : item.total_weight_g,
      items: recipeIngredients.value.map(ri => ({
        ingredient_id: ri.ingredients?.id ?? null,
        search: ri.ingredients?.name ?? '',
        quantity: ri.quantity, unit: ri.unit,
        suggestions: [], showDropdown: false,
        _ing: ri.ingredients,
      }))
    })
  }
}

async function saveIngredient() {
  if (!ingForm.name.trim()) { formError.value = 'Name is required.'; return }
  formSaving.value = true; formError.value = ''
  const row = {
    name: ingForm.name.trim(), category: ingForm.category || null,
    unit: ingForm.unit, ref_quantity: ingForm.ref_quantity,
    calories: ingForm.calories, protein_g: ingForm.protein_g,
    carbs_g: ingForm.carbs_g, fat_g: ingForm.fat_g,
    sodium_mg: ingForm.sodium_mg || null,
  }
  const { error } = ingForm.id
    ? await supabase.from('ingredients').update(row).eq('id', ingForm.id)
    : await supabase.from('ingredients').insert(row)
  if (error) { formError.value = error.message }
  else { ingForm.open = false; fetchItems(true); loadCategories() }
  formSaving.value = false
}

// ── Recipe form ───────────────────────────────────────────────────────────────
const recForm = reactive({ open: false, id: null, name: '', unit: 'gr', total_weight_g: null, items: [] })

const recipePreview = computed(() => {
  let cal = 0, prot = 0, carbs = 0, fat = 0
  recForm.items.forEach(line => {
    if (!line._ing || !line.quantity) return
    const factor = line.quantity / (line._ing.ref_quantity ?? 100)
    cal   += (line._ing.calories  ?? 0) * factor
    prot  += (line._ing.protein_g ?? 0) * factor
    carbs += (line._ing.carbs_g   ?? 0) * factor
    fat   += (line._ing.fat_g     ?? 0) * factor
  })
  return { calories: cal, protein: prot, carbs, fat }
})

function addIngLine() {
  recForm.items.push({ ingredient_id: null, search: '', quantity: null, unit: 'gr', suggestions: [], showDropdown: false, _ing: null })
}

let ingSearchTimers = {}
async function searchIngredient(line) {
  line.ingredient_id = null; line._ing = null
  const q = line.search.trim()
  if (q.length < 2) { line.suggestions = []; return }
  clearTimeout(ingSearchTimers[line])
  ingSearchTimers[line] = setTimeout(async () => {
    const { data } = await supabase.from('ingredients')
      .select('id, name, unit, ref_quantity, calories, protein_g, carbs_g, fat_g')
      .ilike('name', `%${q}%`).limit(8)
    line.suggestions = data ?? []
  }, 250)
}

function pickIngredient(line, ing) {
  line.ingredient_id = ing.id; line._ing = ing
  line.search = ing.name; line.unit = ing.unit
  line.suggestions = []; line.showDropdown = false
}

async function saveRecipe() {
  if (!recForm.name.trim()) { formError.value = 'Name is required.'; return }
  formSaving.value = true; formError.value = ''

  const isPC = recForm.unit === 'pc'
  const totalVal = recForm.total_weight_g ?? 0
  const preview = recipePreview.value
  const perUnit = totalVal > 0
    ? { cal: preview.calories / totalVal, prot: preview.protein / totalVal,
        carb: preview.carbs   / totalVal, fat:  preview.fat    / totalVal }
    : { cal: 0, prot: 0, carb: 0, fat: 0 }

  const recipeRow = {
    name: recForm.name.trim(),
    unit: recForm.unit,
    total_weight_g: isPC ? null : totalVal,
    servings:       isPC ? totalVal : 1,
    calories_total:  preview.calories,
    protein_total:   preview.protein,
    carbs_total:     preview.carbs,
    fat_total:       preview.fat,
    calories_per_unit: perUnit.cal,
    protein_per_unit:  perUnit.prot,
    carbs_per_unit:    perUnit.carb,
    fat_per_unit:      perUnit.fat,
  }

  let recipeId = recForm.id
  if (recipeId) {
    const { error } = await supabase.from('recipes').update(recipeRow).eq('id', recipeId)
    if (error) { formError.value = error.message; formSaving.value = false; return }
    await supabase.from('recipe_items').delete().eq('recipe_id', recipeId)
  } else {
    const { data, error } = await supabase.from('recipes').insert(recipeRow).select('id').single()
    if (error) { formError.value = error.message; formSaving.value = false; return }
    recipeId = data.id
  }

  // Insert recipe_items
  const validLines = recForm.items.filter(l => l.ingredient_id && l.quantity)
  if (validLines.length) {
    const { error } = await supabase.from('recipe_items').insert(
      validLines.map(l => ({ recipe_id: recipeId, ingredient_id: l.ingredient_id, quantity: l.quantity, unit: l.unit }))
    )
    if (error) { formError.value = error.message; formSaving.value = false; return }
  }

  recForm.open = false; fetchItems(true)
  formSaving.value = false
}

// ── Delete ────────────────────────────────────────────────────────────────────
const deleteTarget  = ref(null)
const deleteError   = ref('')
const deleteLoading = ref(false)

function confirmDelete(item) { selected.value = null; deleteTarget.value = item; deleteError.value = '' }

async function doDelete() {
  deleteLoading.value = true; deleteError.value = ''
  const table = activeTab.value === 'ingredient' ? 'ingredients' : 'recipes'
  const { error } = await supabase.from(table).delete().eq('id', deleteTarget.value.id)
  if (error) {
    deleteError.value = error.message.includes('foreign key')
      ? 'Cannot delete — this item is used in meal logs or recipes.'
      : error.message
  } else {
    deleteTarget.value = null; fetchItems(true)
  }
  deleteLoading.value = false
}

onMounted(() => { admin.init(); loadCategories(); fetchItems(true) })
</script>

<style scoped>
.sheet-enter-active, .sheet-leave-active { transition: opacity 0.2s ease; }
.sheet-enter-from, .sheet-leave-to { opacity: 0; }
.scrollbar-hide { -ms-overflow-style: none; scrollbar-width: none; }
.scrollbar-hide::-webkit-scrollbar { display: none; }
</style>
