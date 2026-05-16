<template>
  <div class="p-4 space-y-4">

    <div v-if="!admin.isAdmin" class="card py-12 text-center">
      <p class="text-3xl mb-2">🔒</p>
      <p class="text-sm text-gray-400">Admin access only.</p>
    </div>

    <template v-else>

      <!-- Pending requests -->
      <div class="card">
        <div class="flex items-center justify-between mb-3">
          <h2 class="font-semibold text-gray-800">Pending review</h2>
          <span class="text-xs bg-amber-100 text-amber-700 font-medium px-2 py-0.5 rounded-full">
            {{ pending.length }}</span>
        </div>

        <div v-if="loading" class="py-8 text-center text-sm text-gray-400">Loading…</div>

        <div v-else-if="pending.length === 0" class="py-8 text-center text-sm text-gray-400">
          No pending requests. 🎉
        </div>

        <ul v-else class="space-y-3">
          <li v-for="req in pending" :key="req.id"
            class="border border-gray-100 rounded-xl p-3 space-y-2">
            <!-- Item info -->
            <div class="flex items-start justify-between gap-2">
              <div class="flex-1 min-w-0">
                <div class="flex items-center gap-2">
                  <span :class="['text-[10px] font-medium px-2 py-0.5 rounded-full',
                    req.entity_type === 'recipe' ? 'bg-purple-100 text-purple-700' : 'bg-blue-100 text-blue-700']">
                    {{ req.entity_type }}</span>
                  <p class="text-sm font-semibold text-gray-800 truncate">{{ req.item_name }}</p>
                </div>
                <p class="text-xs text-gray-400 mt-0.5">
                  by {{ req.user_email }} · {{ formatDate(req.created_at) }}</p>
                <p v-if="req.note" class="text-xs text-gray-600 mt-1 italic">"{{ req.note }}"</p>
              </div>
            </div>

            <!-- Macro summary -->
            <div v-if="req.macros" class="flex gap-3 text-xs bg-gray-50 rounded-lg px-3 py-2">
              <span class="text-gray-700 font-medium">{{ req.macros.calories?.toFixed(0) }} kcal</span>
              <span class="text-blue-600">P {{ req.macros.protein?.toFixed(1) }}g</span>
              <span class="text-amber-600">C {{ req.macros.carbs?.toFixed(1) }}g</span>
              <span class="text-rose-500">F {{ req.macros.fat?.toFixed(1) }}g</span>
              <span class="text-gray-400 ml-auto">per {{ req.macros.ref_quantity }}{{ req.macros.unit }}</span>
            </div>

            <!-- Actions -->
            <div v-if="req.id === actionTarget?.id && actionMode === 'reject'" class="space-y-2">
              <textarea v-model="rejectNote" class="input-field text-sm" rows="2"
                placeholder="Reason for rejection (shown to user)…" />
              <div class="flex gap-2">
                <button @click="actionTarget = null" class="btn-secondary py-2 text-sm">Cancel</button>
                <button @click="doReject(req)" class="flex-1 py-2 text-sm bg-red-500 text-white rounded-xl"
                  :disabled="actionSaving">{{ actionSaving ? 'Rejecting…' : 'Confirm reject' }}</button>
              </div>
            </div>
            <div v-else class="flex gap-2">
              <button @click="doApprove(req)"
                class="flex-1 py-2 text-sm bg-green-600 text-white font-medium rounded-xl active:bg-green-700"
                :disabled="actionSaving && actionTarget?.id === req.id">
                ✅ Approve</button>
              <button @click="startReject(req)"
                class="flex-1 py-2 text-sm bg-red-50 text-red-600 font-medium rounded-xl active:bg-red-100">
                ❌ Reject</button>
            </div>
          </li>
        </ul>
      </div>

      <!-- Recently reviewed -->
      <div class="card">
        <h2 class="font-semibold text-gray-800 mb-3">Recently reviewed</h2>

        <div v-if="reviewed.length === 0" class="py-4 text-center text-sm text-gray-400">
          None yet.
        </div>

        <ul v-else class="divide-y divide-gray-50">
          <li v-for="req in reviewed" :key="req.id" class="py-2.5 flex items-start justify-between gap-2">
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2">
                <span :class="['text-[10px] font-medium px-2 py-0.5 rounded-full',
                  req.status === 'approved' ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-600']">
                  {{ req.status === 'approved' ? '✅ Approved' : '❌ Rejected' }}</span>
                <p class="text-sm text-gray-700 truncate">{{ req.item_name }}</p>
              </div>
              <p class="text-xs text-gray-400 mt-0.5">
                {{ req.user_email }} · {{ formatDate(req.reviewed_at) }}</p>
              <p v-if="req.admin_note" class="text-xs text-gray-500 italic mt-0.5">"{{ req.admin_note }}"</p>
            </div>
          </li>
        </ul>
      </div>

    </template>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { supabase } from '@/lib/supabase'
import { useAdminStore } from '@/stores/admin'
import { useAuthStore } from '@/stores/auth'

const admin = useAdminStore()
const auth  = useAuthStore()

const requests = ref([])
const loading  = ref(true)
const actionTarget = ref(null)
const actionMode   = ref('')
const rejectNote   = ref('')
const actionSaving = ref(false)

const pending  = computed(() => requests.value.filter(r => r.status === 'pending'))
const reviewed = computed(() => requests.value.filter(r => r.status !== 'pending').slice(0, 20))

function formatDate(iso) {
  return new Date(iso).toLocaleDateString('el-GR', { day: '2-digit', month: '2-digit', year: 'numeric' })
}

async function load() {
  loading.value = true

  const { data: reqs } = await supabase
    .from('moderation_requests')
    .select('*, profiles:user_id ( email )')
    .order('created_at', { ascending: false })
    .limit(50)

  if (!reqs) { loading.value = false; return }

  // Fetch item details for each request
  const ingIds = reqs.filter(r => r.entity_type === 'ingredient').map(r => r.entity_id)
  const recIds = reqs.filter(r => r.entity_type === 'recipe').map(r => r.entity_id)

  const [ings, recs] = await Promise.all([
    ingIds.length
      ? supabase.from('ingredients').select('id, name, calories, protein_g, carbs_g, fat_g, ref_quantity, unit').in('id', ingIds)
      : { data: [] },
    recIds.length
      ? supabase.from('recipes').select('id, name, calories_total, protein_total, carbs_total, fat_total').in('id', recIds)
      : { data: [] },
  ])

  const ingMap = Object.fromEntries((ings.data ?? []).map(i => [i.id, i]))
  const recMap = Object.fromEntries((recs.data ?? []).map(r => [r.id, r]))

  // Also get user emails via auth.users (need to use service role or store emails separately)
  // We'll fetch emails using a workaround via auth admin API or store in profiles
  // For simplicity, use user_id as fallback display
  requests.value = reqs.map(r => {
    const item = r.entity_type === 'ingredient' ? ingMap[r.entity_id] : recMap[r.entity_id]
    const macros = r.entity_type === 'ingredient' && item ? {
      calories: item.calories, protein: item.protein_g,
      carbs: item.carbs_g, fat: item.fat_g,
      ref_quantity: item.ref_quantity, unit: item.unit,
    } : r.entity_type === 'recipe' && item ? {
      calories: item.calories_total, protein: item.protein_total,
      carbs: item.carbs_total, fat: item.fat_total,
      ref_quantity: null, unit: null,
    } : null
    return {
      ...r,
      item_name: item?.name ?? `[deleted] #${r.entity_id}`,
      user_email: r.user_id.slice(0, 8) + '…', // UUID prefix as fallback
      macros,
    }
  })

  loading.value = false
}

async function doApprove(req) {
  actionSaving.value = true; actionTarget.value = req

  // Set is_public = true on the item
  const table = req.entity_type === 'ingredient' ? 'ingredients' : 'recipes'
  await supabase.from(table).update({ is_public: true }).eq('id', req.entity_id)

  // Update request status
  await supabase.from('moderation_requests').update({
    status: 'approved',
    reviewed_at: new Date().toISOString(),
    reviewed_by: auth.user.id,
  }).eq('id', req.id)

  actionSaving.value = false; actionTarget.value = null
  load()
}

function startReject(req) {
  actionTarget.value = req; actionMode.value = 'reject'; rejectNote.value = ''
}

async function doReject(req) {
  actionSaving.value = true

  await supabase.from('moderation_requests').update({
    status: 'rejected',
    admin_note: rejectNote.value || null,
    reviewed_at: new Date().toISOString(),
    reviewed_by: auth.user.id,
  }).eq('id', req.id)

  actionSaving.value = false; actionTarget.value = null; rejectNote.value = ''
  load()
}

onMounted(async () => {
  await admin.init()
  if (admin.isAdmin) load()
})
</script>
