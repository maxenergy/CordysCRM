<template>
  <CrmCard :title="t('aiProfile.title')" class="ai-profile-card">
    <template #header-extra>
      <NButton v-if="portrait" size="small" quaternary :loading="loading" @click="handleRefresh">
        <template #icon>
          <NIcon><RefreshOutline /></NIcon>
        </template>
        {{ t('aiProfile.refresh') }}
      </NButton>
    </template>

    <!-- 空状态 -->
    <div v-if="!portrait && !loading" class="empty-state">
      <NEmpty :description="t('aiProfile.empty')">
        <template #extra>
          <p class="empty-tip">{{ t('aiProfile.emptyTip') }}</p>
          <NButton type="primary" @click="handleGenerate">
            <template #icon>
              <NIcon><SparklesOutline /></NIcon>
            </template>
            {{ t('aiProfile.generate') }}
          </NButton>
        </template>
      </NEmpty>
    </div>

    <!-- 加载状态 -->
    <div v-else-if="loading" class="loading-state">
      <NSpin size="large" />
      <p class="loading-text">{{ t('aiProfile.generating') }}</p>
    </div>

    <!-- 错误状态 -->
    <div v-else-if="error" class="error-state">
      <NResult status="error" :title="t('aiProfile.generateFailed')">
        <template #footer>
          <NButton @click="handleGenerate">{{ t('aiProfile.retry') }}</NButton>
        </template>
      </NResult>
    </div>

    <!-- 内容展示 -->
    <NTabs v-else type="line" animated>
      <!-- 基本信息 -->
      <NTabPane :name="'basicInfo'" :tab="t('aiProfile.tab.basicInfo')">
        <BasicInfoTab :info="portrait?.basicInfo" />
      </NTabPane>

      <!-- 商机洞察 -->
      <NTabPane :name="'insights'" :tab="t('aiProfile.tab.insights')">
        <InsightsTab :insights="portrait?.insights || []" />
      </NTabPane>

      <!-- 风险提示 -->
      <NTabPane :name="'risks'" :tab="t('aiProfile.tab.risks')">
        <RisksTab :risks="portrait?.risks || []" />
      </NTabPane>

      <!-- 相关舆情 -->
      <NTabPane :name="'opinions'" :tab="t('aiProfile.tab.opinions')">
        <OpinionsTab :opinions="portrait?.opinions || []" />
      </NTabPane>
    </NTabs>
  </CrmCard>
</template>

<script lang="ts" setup>
  import { RefreshOutline, SparklesOutline } from '@vicons/ionicons5';

  import { useI18n } from '@lib/shared/hooks/useI18n';
  import type { CompanyPortrait } from '@lib/shared/models/ai';

  import CrmCard from '@/components/pure/crm-card/index.vue';
  import BasicInfoTab from './components/BasicInfoTab.vue';
  import InsightsTab from './components/InsightsTab.vue';
  import OpinionsTab from './components/OpinionsTab.vue';
  import RisksTab from './components/RisksTab.vue';

  const props = defineProps<{
    customerId: string;
  }>();

  const emit = defineEmits<{
    (e: 'generate'): void;
    (e: 'refresh'): void;
  }>();

  const { t } = useI18n();

  const loading = ref(false);
  const error = ref(false);
  const portrait = ref<CompanyPortrait | null>(null);

  // 延迟函数
  function delay(ms: number): Promise<void> {
    return new Promise((resolve) => {
      setTimeout(resolve, ms);
    });
  }

  // 模拟数据
  function getMockPortrait(): CompanyPortrait {
    return {
      id: '1',
      customerId: props.customerId,
      basicInfo: {
        industry: '信息技术/软件开发',
        scale: '中型企业（100-500人）',
        mainProducts: '企业管理软件、CRM系统、ERP系统',
        foundedYear: '2015',
        employeeCount: '200-300人',
        annualRevenue: '5000万-1亿',
      },
      insights: [
        {
          title: '数字化转型需求强烈',
          description: '该企业近期在招聘数字化相关岗位，表明有数字化转型需求',
          confidence: 0.85,
          source: '招聘信息分析',
        },
        {
          title: '业务扩张迹象',
          description: '近半年新增多个分支机构，业务规模持续扩大',
          confidence: 0.72,
          source: '工商信息',
        },
        {
          title: 'IT预算充足',
          description: '根据行业平均水平和企业规模推测，IT预算较为充足',
          confidence: 0.65,
          source: '行业分析',
        },
      ],
      risks: [
        {
          title: '应收账款周期较长',
          description: '行业平均回款周期为60天，需注意账期管理',
          level: 'medium',
        },
        {
          title: '竞争对手活跃',
          description: '该客户所在区域竞争对手较为活跃，需加强关系维护',
          level: 'low',
        },
      ],
      opinions: [
        {
          title: '获得行业创新奖',
          source: '行业媒体',
          sentiment: 'positive',
          publishDate: '2024-11-15',
        },
        {
          title: '参与行业标准制定',
          source: '官方公告',
          sentiment: 'positive',
          publishDate: '2024-10-20',
        },
      ],
      generatedAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };
  }

  // 生成画像
  async function handleGenerate() {
    loading.value = true;
    error.value = false;
    try {
      // TODO: 调用 API 生成画像
      await delay(2000);
      portrait.value = getMockPortrait();
      emit('generate');
    } catch {
      error.value = true;
    } finally {
      loading.value = false;
    }
  }

  // 刷新画像
  async function handleRefresh() {
    loading.value = true;
    error.value = false;
    try {
      // TODO: 调用 API 刷新画像
      await delay(2000);
      portrait.value = getMockPortrait();
      emit('refresh');
    } catch {
      error.value = true;
    } finally {
      loading.value = false;
    }
  }

  // 加载画像
  async function loadPortrait() {
    if (!props.customerId) return;

    loading.value = true;
    try {
      // TODO: 调用 API 获取画像
      await delay(500);
      if (Math.random() > 0.5) {
        portrait.value = getMockPortrait();
      }
    } finally {
      loading.value = false;
    }
  }

  // 监听 customerId 变化
  watch(
    () => props.customerId,
    () => {
      loadPortrait();
    },
    { immediate: true }
  );

  // 暴露方法
  defineExpose({
    refresh: handleRefresh,
    generate: handleGenerate,
  });
</script>

<style lang="less" scoped>
  .ai-profile-card {
    :deep(.n-card__content) {
      min-height: 300px;
    }
  }
  .empty-state {
    display: flex;
    justify-content: center;
    align-items: center;
    padding: 48px 24px;
    flex-direction: column;
    .empty-tip {
      margin-bottom: 16px;
      font-size: 14px;
      color: var(--text-n5);
    }
  }
  .loading-state {
    display: flex;
    justify-content: center;
    align-items: center;
    padding: 48px 24px;
    flex-direction: column;
    .loading-text {
      margin-top: 16px;
      color: var(--text-n5);
    }
  }
  .error-state {
    padding: 24px;
  }
</style>
