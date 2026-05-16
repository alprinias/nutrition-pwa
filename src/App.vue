<template>
  <div v-if="auth.loading" class="min-h-screen flex items-center justify-center bg-gray-50">
    <div class="flex flex-col items-center gap-3">
      <div class="w-10 h-10 border-3 border-green-600 border-t-transparent rounded-full animate-spin" />
      <p class="text-sm text-gray-500">Loading…</p>
    </div>
  </div>
  <RouterView v-else />
</template>

<script setup>
import { RouterView } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const auth = useAuthStore()
auth.init()
</script>
