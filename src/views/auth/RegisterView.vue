<template>
  <div class="min-h-screen bg-gradient-to-b from-green-50 to-white flex flex-col justify-center px-6 py-12">

    <div class="text-center mb-10">
      <div class="text-5xl mb-3">🥗</div>
      <h1 class="text-2xl font-bold text-gray-900">Διατροφή</h1>
      <p class="text-sm text-gray-500 mt-1">Create your account</p>
    </div>

    <div class="card max-w-sm w-full mx-auto">
      <h2 class="text-lg font-semibold text-gray-800 mb-5">Register</h2>

      <!-- Success state -->
      <div v-if="success" class="text-center py-4">
        <div class="text-4xl mb-3">📧</div>
        <p class="font-medium text-gray-800">Check your email</p>
        <p class="text-sm text-gray-500 mt-1">
          We sent a confirmation link to <strong>{{ email }}</strong>.
          Click it to activate your account, then sign in.
        </p>
        <RouterLink to="/login" class="btn-primary mt-5 inline-block text-center">
          Back to sign in
        </RouterLink>
      </div>

      <!-- Form -->
      <form v-else @submit.prevent="handleRegister" class="flex flex-col gap-4">
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

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Password</label>
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

        <button type="submit" class="btn-primary mt-1" :disabled="loading">
          <span v-if="loading">Creating account…</span>
          <span v-else>Create account</span>
        </button>
      </form>

      <p v-if="!success" class="text-center text-sm text-gray-500 mt-5">
        Already have an account?
        <RouterLink to="/login" class="text-green-600 font-medium">Sign in</RouterLink>
      </p>
    </div>

  </div>
</template>

<script setup>
import { ref } from 'vue'
import { RouterLink } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const auth = useAuthStore()

const email = ref('')
const password = ref('')
const confirmPassword = ref('')
const loading = ref(false)
const errorMsg = ref('')
const success = ref(false)

async function handleRegister() {
  errorMsg.value = ''

  if (password.value !== confirmPassword.value) {
    errorMsg.value = 'Passwords do not match.'
    return
  }

  loading.value = true
  try {
    await auth.register(email.value, password.value)
    success.value = true
  } catch (err) {
    errorMsg.value = err.message ?? 'Registration failed. Please try again.'
  } finally {
    loading.value = false
  }
}
</script>
