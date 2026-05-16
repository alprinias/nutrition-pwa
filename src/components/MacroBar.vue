<template>
  <div class="flex items-center gap-2">
    <span class="text-[11px] text-gray-500 w-12 shrink-0">{{ label }}</span>
    <div class="flex-1 h-1.5 bg-gray-100 rounded-full overflow-hidden">
      <div
        :class="['h-full rounded-full transition-all duration-500', color]"
        :style="{ width: `${Math.min(100, (value / max) * 100)}%` }"
      />
    </div>
    <span class="text-[11px] font-medium text-gray-700 w-14 text-right">
      {{ value.toFixed(0) }}/{{ max }}{{ unit }}
    </span>
  </div>
</template>

<script setup>
defineProps({
  label: String,
  value: { type: Number, default: 0 },
  max:   { type: Number, default: 100 },
  color: { type: String, default: 'bg-green-500' },
  unit:  { type: String, default: 'g' },
})
</script>
