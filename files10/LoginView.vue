<template>
  <div class="min-h-screen bg-gradient-to-b from-green-50 to-white flex flex-col justify-center px-6 py-12">

    <!-- Logo / title -->
    <div class="text-center mb-10">
      <div class="text-5xl mb-3">🥗</div>
      <h1 class="text-2xl font-bold text-gray-900">Διατροφή</h1>
      <p class="text-sm text-gray-500 mt-1">Your personal nutrition tracker</p>
    </div>

    <!-- Form card -->
    <div class="card max-w-sm w-full mx-auto">
      <h2 class="text-lg font-semibold text-gray-800 mb-5">Sign in</h2>

      <form @submit.prevent="handleLogin" class="flex flex-col gap-4">
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
          <div class="flex items-center justify-between mb-1">
            <label class="block text-sm font-medium text-gray-700">Password</label>
            <RouterLink to="/forgot-password" class="text-xs text-green-600">Forgot password?</RouterLink>
          </div>
          <input
            v-model="password"
            type="password"
            autocomplete="current-password"
            placeholder="••••••••"
            class="input-field"
            required
          />
        </div>

        <p v-if="errorMsg" class="text-sm text-red-600 bg-red-50 rounded-lg px-3 py-2">
          {{ errorMsg }}
        </p>

        <button type="submit" class="btn-primary mt-1" :disabled="loading">
          <span v-if="loading">Signing in…</span>
          <span v-else>Sign in</span>
        </button>
      </form>

      <p class="text-center text-sm text-gray-500 mt-5">
        No account?
        <RouterLink to="/register" class="text-green-600 font-medium">Register</RouterLink>
      </p>
    </div>

  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter, RouterLink } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const auth = useAuthStore()
const router = useRouter()

const email = ref('')
const password = ref('')
const loading = ref(false)
const errorMsg = ref('')

async function handleLogin() {
  errorMsg.value = ''
  loading.value = true
  try {
    await auth.login(email.value, password.value)
    router.push({ name: 'Today' })
  } catch (err) {
    errorMsg.value = err.message ?? 'Login failed. Please try again.'
  } finally {
    loading.value = false
  }
}
</script>
