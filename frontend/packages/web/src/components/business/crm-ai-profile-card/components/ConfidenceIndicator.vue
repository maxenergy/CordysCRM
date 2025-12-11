<template>
  <NProgress
    type="circle"
    :percentage="Math.round(confidence * 100)"
    :stroke-width="8"
    :show-indicator="true"
    :status="status"
    style="width: 48px; height: 48px"
  />
</template>

<script lang="ts" setup>
  const props = defineProps<{
    confidence: number;
  }>();

  const status = computed(() => {
    if (props.confidence >= 0.7) return 'success';
    if (props.confidence >= 0.4) return 'warning';
    return 'default';
  });
</script>
