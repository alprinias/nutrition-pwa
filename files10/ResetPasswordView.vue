<template>
  <div class="min-h-screen bg-gradient-to-b from-green-50 to-white flex flex-col justify-center px-6 py-12">

    <div class="text-center mb-10">
      <div class="text-5xl mb-3">🥗</div>
      <h1 class="text-2xl font-bold text-gray-900">Διατροφή</h1>
      <p class="text-sm text-gray-500 mt-1">Set a new password</p>
    </div>

    <div class="card max-w-sm w-full mx-auto">
      <h2 class="text-lg font-semibold text-gray-800 mb-5">New password</h2>

      <!-- Invalid / expired link -->
      <div v-if="invalidLink" class="text-center py-4">
        <div class="text-4xl mb-3">⚠️</div>
        <p class="font-medium text-gray-800">Link expired or invalid</p>
        <p class="text-sm text-gray-500 mt-1">Please request a new password reset link.</p>
        <RouterLink to="/forgot-password" class="btn-primary mt-5 inline-block text-center">
          Request new link
        </RouterLink>
      </div>

      <!-- Success state -->
      <div v-else-if="success" class="text-center py-4">
        <div class="text-4xl mb-3">✅</div>
        <p class="font-medium text-gray-800">Password updated!</p>
        <p class="text-sm text-gray-500 mt-1">You can now sign in with your new password.</p>
        <RouterLink to="/login" class="btn-primary mt-5 inline-block text-center">
          Sign in
        </RouterLink>
      </div>

      <!-- Form -->
      <form v-else @submit.prevent="handleSubmit" class="flex flex-col gap-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">New password</label>
          <input
            v-model="password"
            type="password"
            autocomplete="new-password"
            placeholder="at least 8 characters"
            class="input-field"
            minlength="8"
            required
          />
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Confirm password</label>
          <input
            v-model="confirmPassword"
            type="password"
            autocomplete="new-password"
            placeholder="••••••••"
            class="input-field"
            required
          />
        </div>

        <p v-if="errorMsg" class="text-sm text-red-600 bg-red-50 rounded-lg px-3 py-2">
          {{ errorMsg }}
        </p>

        <button type="submit" class="btn-primary" :disabled="loading">
          {{ loading ? 'Updating…' : 'Update password' }}
        </button>
      </form>
    </div>

  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { RouterLink } from 'vue-router'
import { supabase } from '@/lib/supabase'

const password        = ref('')
const confirmPassword = ref('')
const loading         = ref(false)
const errorMsg        = ref('')
const success         = ref(false)
const invalidLink     = ref(false)

onMounted(() => {
  // Supabase puts the session tokens in the URL hash when redirecting
  // from the reset email. If there's no session/token, the link is bad.
  const hash = window.location.hash
  if (!hash.includes('access_token') && !hash.includes('type=recovery')) {
    // Check if we already have a valid recovery session
    supabase.auth.getSession().then(({ data }) => {
      if (!data.session) invalidLink.value = true
    })
  }
})

async function handleSubmit() {
  errorMsg.value = ''

  if (password.value !== confirmPassword.value) {
    errorMsg.value = 'Passwords do not match.'
    return
  }

  loading.value = true

  const { error } = await supabase.auth.updateUser({ password: password.value })

  if (error) {
    errorMsg.value = error.message
  } else {
    success.value = true
    // Sign out so the user has to log in fresh with the new password
    await supabase.auth.signOut()
  }

  loading.value = false
}
</script>
