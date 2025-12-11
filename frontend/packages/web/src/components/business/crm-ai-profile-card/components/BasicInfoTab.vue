<template>
  <NDescriptions v-if="info" :column="2" label-placement="left" bordered>
    <NDescriptionsItem :label="t('aiProfile.basicInfo.industry')">
      {{ info.industry || '-' }}
    </NDescriptionsItem>
    <NDescriptionsItem :label="t('aiProfile.basicInfo.scale')">
      {{ info.scale || '-' }}
    </NDescriptionsItem>
    <NDescriptionsItem :label="t('aiProfile.basicInfo.mainProducts')" :span="2">
      {{ info.mainProducts || '-' }}
    </NDescriptionsItem>
    <NDescriptionsItem :label="t('aiProfile.basicInfo.foundedYear')">
      {{ info.foundedYear || '-' }}
    </NDescriptionsItem>
    <NDescriptionsItem :label="t('aiProfile.basicInfo.employeeCount')">
      {{ info.employeeCount || '-' }}
    </NDescriptionsItem>
    <NDescriptionsItem :label="t('aiProfile.basicInfo.annualRevenue')" :span="2">
      {{ info.annualRevenue || '-' }}
    </NDescriptionsItem>
  </NDescriptions>
  <NEmpty v-else :description="t('aiProfile.tab.basicInfo')" />
</template>

<script lang="ts" setup>
  import { useI18n } from '@lib/shared/hooks/useI18n';
  import type { PortraitBasicInfo } from '@lib/shared/models/ai';

  defineProps<{
    info?: PortraitBasicInfo;
  }>();

  const { t } = useI18n();
</script>
