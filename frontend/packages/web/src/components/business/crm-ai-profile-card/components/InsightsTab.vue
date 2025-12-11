<template>
  <div v-if="insights.length > 0" class="insights-list">
    <NList hoverable clickable>
      <NListItem v-for="(insight, index) in insights" :key="index">
        <template #prefix>
          <ConfidenceIndicator :confidence="insight.confidence" />
        </template>
        <NThing :title="insight.title" :description="insight.description">
          <template #footer>
            <NSpace size="small">
              <NTag v-if="insight.source" size="small" :bordered="false">
                {{ t('aiProfile.insights.source') }}: {{ insight.source }}
              </NTag>
              <NTag size="small" :bordered="false" :type="getConfidenceType(insight.confidence)">
                {{ t('aiProfile.insights.confidence') }}: {{ Math.round(insight.confidence * 100) }}%
              </NTag>
            </NSpace>
          </template>
        </NThing>
      </NListItem>
    </NList>
  </div>
  <NEmpty v-else :description="t('aiProfile.insights.empty')" />
</template>

<script lang="ts" setup>
  import { useI18n } from '@lib/shared/hooks/useI18n';
  import type { BusinessInsight } from '@lib/shared/models/ai';

  import ConfidenceIndicator from './ConfidenceIndicator.vue';

  defineProps<{
    insights: BusinessInsight[];
  }>();

  const { t } = useI18n();

  function getConfidenceType(confidence: number): 'success' | 'warning' | 'default' {
    if (confidence >= 0.7) return 'success';
    if (confidence >= 0.4) return 'warning';
    return 'default';
  }
</script>

<style lang="less" scoped>
  .insights-list {
    padding: 8px 0;
  }
</style>
