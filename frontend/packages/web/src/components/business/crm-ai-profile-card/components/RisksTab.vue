<template>
  <div v-if="risks.length > 0" class="risks-container">
    <!-- 高风险 -->
    <div v-if="highRisks.length > 0" class="risk-group">
      <div class="risk-group-header high">
        <NIcon size="18"><WarningOutline /></NIcon>
        <span>{{ t('aiProfile.risks.high') }}</span>
      </div>
      <NAlert
        v-for="(risk, index) in highRisks"
        :key="`high-${index}`"
        type="error"
        :title="risk.title"
        class="risk-alert"
      >
        {{ risk.description }}
      </NAlert>
    </div>

    <!-- 中风险 -->
    <div v-if="mediumRisks.length > 0" class="risk-group">
      <div class="risk-group-header medium">
        <NIcon size="18"><AlertCircleOutline /></NIcon>
        <span>{{ t('aiProfile.risks.medium') }}</span>
      </div>
      <NAlert
        v-for="(risk, index) in mediumRisks"
        :key="`medium-${index}`"
        type="warning"
        :title="risk.title"
        class="risk-alert"
      >
        {{ risk.description }}
      </NAlert>
    </div>

    <!-- 低风险 -->
    <div v-if="lowRisks.length > 0" class="risk-group">
      <div class="risk-group-header low">
        <NIcon size="18"><InformationCircleOutline /></NIcon>
        <span>{{ t('aiProfile.risks.low') }}</span>
      </div>
      <NAlert
        v-for="(risk, index) in lowRisks"
        :key="`low-${index}`"
        type="info"
        :title="risk.title"
        class="risk-alert"
      >
        {{ risk.description }}
      </NAlert>
    </div>
  </div>
  <NEmpty v-else :description="t('aiProfile.risks.empty')" />
</template>

<script lang="ts" setup>
  import { AlertCircleOutline, InformationCircleOutline, WarningOutline } from '@vicons/ionicons5';

  import { useI18n } from '@lib/shared/hooks/useI18n';
  import type { RiskAlert } from '@lib/shared/models/ai';

  const props = defineProps<{
    risks: RiskAlert[];
  }>();

  const { t } = useI18n();

  const highRisks = computed(() => props.risks.filter((r) => r.level === 'high'));
  const mediumRisks = computed(() => props.risks.filter((r) => r.level === 'medium'));
  const lowRisks = computed(() => props.risks.filter((r) => r.level === 'low'));
</script>

<style lang="less" scoped>
  .risks-container {
    padding: 8px 0;
  }
  .risk-group {
    margin-bottom: 16px;
    &:last-child {
      margin-bottom: 0;
    }
  }
  .risk-group-header {
    display: flex;
    align-items: center;
    margin-bottom: 8px;
    font-size: 14px;
    font-weight: 600;
    gap: 4px;
    &.high {
      color: var(--error-color);
    }
    &.medium {
      color: var(--warning-color);
    }
    &.low {
      color: var(--info-color);
    }
  }
  .risk-alert {
    margin-bottom: 8px;
    &:last-child {
      margin-bottom: 0;
    }
  }
</style>
