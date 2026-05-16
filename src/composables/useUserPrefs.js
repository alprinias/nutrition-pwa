import { ref } from 'vue'
import { supabase } from '@/lib/supabase'
import { useAuthStore } from '@/stores/auth'

// Module-level cache so all views share the same state
const showPublicFoods = ref(true)
const loaded = ref(false)

export function useUserPrefs() {
  const auth = useAuthStore()

  async function load() {
    if (loaded.value) return
    const { data } = await supabase
      .from('user_targets')
      .select('show_public_foods')
      .eq('user_id', auth.user.id)
      .maybeSingle()
    if (data) showPublicFoods.value = data.show_public_foods ?? true
    loaded.value = true
  }

  async function setShowPublicFoods(val) {
    showPublicFoods.value = val
    await supabase
      .from('user_targets')
      .update({ show_public_foods: val })
      .eq('user_id', auth.user.id)
  }

  function reset() {
    loaded.value = false
    showPublicFoods.value = true
  }

  return { showPublicFoods, load, setShowPublicFoods, reset }
}
