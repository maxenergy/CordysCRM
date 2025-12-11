<template>
  <div v-if="opinions.length > 0" class="opinions-container">
    <NTimeline>
      <NTimelineItem
        v-for="(opinion, index) in opinions"
        :key="index"
        :type="getSentimentType(opinion.sentiment)"
        :title="opinion.title"
        :time="opinion.publishDate"
      >
        <template #icon>
          <NIcon :color="getSentimentColor(opinion.sentiment)">
            <ThumbsUpOutline v-if="opinion.sentiment === 'positive'" />
            <ThumbsDownOutline v-else-if="opinion.sentiment === 'negative'" />
            <RemoveOutline v-else />
          </NIcon>
        </template>
        <NSpace size="small">
          <NTag size="small" :bordered="false">
            {{ opinion.source }}
          </NTag>
          <NTag
            size="small"
            :bordered="false"
            :type="getSentimentTagType(opinion.sentiment)"
          >
            {{ getSentimentLabel(opinion.sentiment) }}
          </NTag>
        </NSpace>
      </NTimelineItem>
    </NTimeline>
  </div>
  <NEmpty v-else :description="t('aiProfile.opinions.empty')" />
</template>

<script lang="ts" setup>
  import { ThumbsUpOutline, ThumbsDownOutline, RemoveOutline } from '@vicons/ionicons5';
  import { useI18n } from '@lib/shared/hooks/useI18n';
  import type { PublicOpinion, Sentiment } from '@lib/shared/models/ai';

  defineProps<{
    opinions: PublicOpinion[];
  }>();

  const { t } = useI18n();

  function getSentimentType(sentiment: Sentiment): 'success' | 'error' | 'default' {
    switch (sentiment) {
      case 'positive':
        return 'success';
      case 'negative':
        return 'error';
      default:
        return 'default';
    }
  }

  function getSentimentTagType(sentiment: Sentiment): 'success' | 'error' | 'default' {
    return getSentimentType(sentiment);
  }

  function getSentimentColor(sentiment: Sentiment): string {
    switch (sentiment) {
      case 'positive':
        return 'var(--success-color)';
      case 'negative':
        return 'var(--error-color)';
      default:
        return 'var(--text-n5)';
    }
  }

  function getSentimentLabel(sentiment: Sentiment): string {
    switch (sentiment) {
      case 'positive':
        return t('aiProfile.opinions.positive');
      case 'negative':
        return t('aiProfile.opinions.negative');
      default:
        return t('aiProfile.opinions.neutral');
    }
  }
</script>

<style lang="less" scoped>
  .opinions-container {
    padding: 16px 0;
  }
</style>
