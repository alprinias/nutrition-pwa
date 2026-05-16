<template>
  <div class="min-h-screen bg-gradient-to-b from-green-50 to-white flex flex-col justify-center px-6 py-12">

    <div class="text-center mb-10">
      <div class="text-5xl mb-3">🥗</div>
      <h1 class="text-2xl font-bold text-gray-900">Διατροφή</h1>
      <p class="text-sm text-gray-500 mt-1">Reset your password</p>
    </div>

    <div class="card max-w-sm w-full mx-auto">
      <h2 class="text-lg font-semibold text-gray-800 mb-2">Forgot password</h2>
      <p class="text-sm text-gray-500 mb-5">
        Enter your email and we'll send you a link to reset your password.
      </p>

      <!-- Success state -->
      <div v-if="success" class="text-center py-4">
        <div class="text-4xl mb-3">📧</div>
        <p class="font-medium text-gray-800">Check your email</p>
        <p class="text-sm text-gray-500 mt-1">
          We sent a password reset link to <strong>{{ email }}</strong>.
        </p>
        <RouterLink to="/login" class="btn-primary mt-5 inline-block text-center">
          Back to sign in
        </RouterLink>
      </div>

      <!-- Form -->
      <form v-else @submit.prevent="handleSubmit" class="flex flex-col gap-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Email</label>
          <input
            v-model="email"
            type="email"
            autocomplete="email"
            placeholder="you@example.com"
            class="input-field"
            required
          />
        </div>

        <p v-if="errorMsg" class="text-sm text-red-600 bg-red-50 rounded-lg px-3 py-2">
          {{ errorMsg }}
        </p>

        <button type="submit" class="btn-primary" :disabled="loading">
          {{ loading ? 'Sending…' : 'Send reset link' }}
        </button>
      </form>

      <p v-if="!success" class="text-center text-sm text-gray-500 mt-5">
        <RouterLink to="/login" class="text-green-600 font-medium">Back to sign in</RouterLink>
      </p>
    </div>

  </div>
</template>

<script setup>
import { ref } from 'vue'
import { RouterLink } from 'vue-router'
import { supabase } from '@/lib/supabase'

const email    = ref('')
const loading  = ref(false)
const errorMsg = ref('')
const success  = ref(false)

async function handleSubmit() {
  loading.value  = true
  errorMsg.value = ''

  const { error } = await supabase.auth.resetPasswordForEmail(email.value, {
    redirectTo: `${window.location.origin}/reset-password`,
  })

  if (error) {
    errorMsg.value = error.message
  } else {
    success.value = true
  }
  loading.value = false
}
</script>
