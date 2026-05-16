import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { supabase } from '@/lib/supabase'
import { useAuthStore } from '@/stores/auth'

export const useAdminStore = defineStore('admin', () => {
  const adminUserId = ref(null)
  const loaded = ref(false)

  const auth = useAuthStore()
  const isAdmin = computed(() =>
    loaded.value && !!adminUserId.value && auth.user?.id === adminUserId.value
  )

  async function init() {
    if (loaded.value) return
    const { data } = await supabase
      .from('app_config')
      .select('value')
      .eq('key', 'admin_user_id')
      .maybeSingle()
    adminUserId.value = data?.value ?? null
    loaded.value = true
  }

  return { isAdmin, init }
})
