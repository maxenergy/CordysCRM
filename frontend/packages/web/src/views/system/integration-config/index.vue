<template>
  <div class="integration-config-page">
    <div class="page-header">
      <h2>{{ t('integrationConfig.title') }}</h2>
    </div>

    <div class="page-content">
      <NTabs type="line" animated>
        <!-- 爱企查配置 -->
        <NTabPane :name="'iqicha'" :tab="t('integrationConfig.tab.iqicha')">
          <NCard>
            <NForm ref="iqichaFormRef" :model="iqichaConfig" label-placement="left" label-width="120">
              <NFormItem :label="t('integrationConfig.iqicha.cookie')">
                <NInput
                  v-model:value="iqichaConfig.cookie"
                  type="password"
                  show-password-on="click"
                  :placeholder="t('integrationConfig.iqicha.cookiePlaceholder')"
                />
              </NFormItem>
              <NFormItem>
                <NSpace>
                  <NButton :loading="testingIqicha" @click="handleTestIqicha">
                    {{ t('integrationConfig.testConnection') }}
                  </NButton>
                  <NButton type="primary" :loading="savingIqicha" @click="handleSaveIqicha">
                    {{ t('integrationConfig.save') }}
                  </NButton>
                </NSpace>
              </NFormItem>
            </NForm>
            <NAlert type="info" :title="t('integrationConfig.iqicha.cookieTip')" />
          </NCard>
        </NTabPane>

        <!-- AI 服务配置 -->
        <NTabPane :name="'ai'" :tab="t('integrationConfig.tab.ai')">
          <NCard>
            <NForm ref="aiFormRef" :model="aiConfig" label-placement="left" label-width="120">
              <NFormItem :label="t('integrationConfig.ai.provider')">
                <NSelect
                  v-model:value="aiConfig.provider"
                  :options="providerOptions"
                  :placeholder="t('integrationConfig.ai.providerPlaceholder')"
                  @update:value="handleProviderChange"
                />
              </NFormItem>

              <NFormItem :label="t('integrationConfig.ai.apiKey')">
                <NInput
                  v-model:value="aiConfig.apiKey"
                  type="password"
                  show-password-on="click"
                  :placeholder="t('integrationConfig.ai.apiKeyPlaceholder')"
                />
              </NFormItem>

              <NFormItem :label="t('integrationConfig.ai.model')">
                <NSelect
                  v-model:value="aiConfig.model"
                  :options="modelOptions"
                  :placeholder="t('integrationConfig.ai.modelPlaceholder')"
                />
              </NFormItem>

              <NFormItem :label="t('integrationConfig.ai.temperature')">
                <div class="slider-container">
                  <NSlider v-model:value="aiConfig.temperature" :min="0" :max="2" :step="0.1" :tooltip="true" />
                  <span class="slider-value">{{ aiConfig.temperature }}</span>
                </div>
              </NFormItem>
              <NFormItem>
                <NText depth="3" class="form-tip">
                  {{ t('integrationConfig.ai.temperatureTip') }}
                </NText>
              </NFormItem>

              <NFormItem :label="t('integrationConfig.ai.maxTokens')">
                <NInputNumber
                  v-model:value="aiConfig.maxTokens"
                  :min="100"
                  :max="32000"
                  :step="100"
                  style="width: 200px"
                />
              </NFormItem>
              <NFormItem>
                <NText depth="3" class="form-tip">
                  {{ t('integrationConfig.ai.maxTokensTip') }}
                </NText>
              </NFormItem>

              <NFormItem>
                <NSpace>
                  <NButton :loading="testingAI" @click="handleTestAI">
                    {{ t('integrationConfig.testConnection') }}
                  </NButton>
                  <NButton type="primary" :loading="savingAI" @click="handleSaveAI">
                    {{ t('integrationConfig.save') }}
                  </NButton>
                </NSpace>
              </NFormItem>
            </NForm>
          </NCard>
        </NTabPane>
      </NTabs>
    </div>
  </div>
</template>

<script lang="ts" setup>
  import { useMessage } from 'naive-ui';

  import { useI18n } from '@lib/shared/hooks/useI18n';

  const { t } = useI18n();
  const message = useMessage();

  // 爱企查配置
  const iqichaConfig = ref({
    cookie: '',
  });
  const testingIqicha = ref(false);
  const savingIqicha = ref(false);

  // AI 配置
  const aiConfig = ref({
    provider: 'openai',
    apiKey: '',
    model: 'gpt-4',
    temperature: 0.7,
    maxTokens: 4096,
  });
  const testingAI = ref(false);
  const savingAI = ref(false);

  // 提供商选项
  const providerOptions = computed(() => [
    { label: t('integrationConfig.provider.openai'), value: 'openai' },
    { label: t('integrationConfig.provider.claude'), value: 'claude' },
    { label: t('integrationConfig.provider.maxkb'), value: 'maxkb' },
    { label: t('integrationConfig.provider.local'), value: 'local' },
  ]);

  // 模型选项（根据提供商动态变化）
  const modelOptions = computed(() => {
    switch (aiConfig.value.provider) {
      case 'openai':
        return [
          { label: 'GPT-4', value: 'gpt-4' },
          { label: 'GPT-4 Turbo', value: 'gpt-4-turbo' },
          { label: 'GPT-3.5 Turbo', value: 'gpt-3.5-turbo' },
        ];
      case 'claude':
        return [
          { label: 'Claude 3 Opus', value: 'claude-3-opus' },
          { label: 'Claude 3 Sonnet', value: 'claude-3-sonnet' },
          { label: 'Claude 3 Haiku', value: 'claude-3-haiku' },
        ];
      case 'maxkb':
        return [{ label: 'MaxKB Default', value: 'maxkb-default' }];
      case 'local':
        return [
          { label: 'Llama 3', value: 'llama-3' },
          { label: 'Qwen 2', value: 'qwen-2' },
          { label: 'ChatGLM 4', value: 'chatglm-4' },
        ];
      default:
        return [];
    }
  });

  // 延迟函数
  function delay(ms: number): Promise<void> {
    return new Promise((resolve) => {
      setTimeout(resolve, ms);
    });
  }

  // 提供商变化时重置模型
  function handleProviderChange() {
    aiConfig.value.model = modelOptions.value[0]?.value || '';
  }

  // 测试爱企查连接
  async function handleTestIqicha() {
    if (!iqichaConfig.value.cookie) {
      message.warning(t('integrationConfig.iqicha.cookiePlaceholder'));
      return;
    }

    testingIqicha.value = true;
    try {
      // TODO: 调用 API 测试连接
      await delay(1000);
      message.success(t('integrationConfig.testSuccess'));
    } catch {
      message.error(t('integrationConfig.testFailed'));
    } finally {
      testingIqicha.value = false;
    }
  }

  // 保存爱企查配置
  async function handleSaveIqicha() {
    savingIqicha.value = true;
    try {
      // TODO: 调用 API 保存配置
      await delay(500);
      message.success(t('integrationConfig.saveSuccess'));
    } catch {
      message.error(t('integrationConfig.saveFailed'));
    } finally {
      savingIqicha.value = false;
    }
  }

  // 测试 AI 连接
  async function handleTestAI() {
    if (!aiConfig.value.apiKey) {
      message.warning(t('integrationConfig.ai.apiKeyPlaceholder'));
      return;
    }

    testingAI.value = true;
    try {
      // TODO: 调用 API 测试连接
      await delay(1000);
      message.success(t('integrationConfig.testSuccess'));
    } catch {
      message.error(t('integrationConfig.testFailed'));
    } finally {
      testingAI.value = false;
    }
  }

  // 保存 AI 配置
  async function handleSaveAI() {
    savingAI.value = true;
    try {
      // TODO: 调用 API 保存配置
      await delay(500);
      message.success(t('integrationConfig.saveSuccess'));
    } catch {
      message.error(t('integrationConfig.saveFailed'));
    } finally {
      savingAI.value = false;
    }
  }

  // 加载配置
  async function loadConfig() {
    // TODO: 调用 API 获取配置
    // 敏感字段显示为 ******
  }

  onMounted(() => {
    loadConfig();
  });
</script>

<style lang="less" scoped>
  .integration-config-page {
    display: flex;
    padding: 16px;
    height: 100%;
    background: var(--bg-color);
    flex-direction: column;
  }
  .page-header {
    margin-bottom: 16px;
    h2 {
      margin: 0;
      font-size: 18px;
      font-weight: 600;
    }
  }
  .page-content {
    overflow: auto;
    padding: 16px;
    border-radius: 8px;
    background: var(--card-color);
    flex: 1;
  }
  .slider-container {
    display: flex;
    align-items: center;
    gap: 16px;
    width: 100%;
    max-width: 400px;
    .n-slider {
      flex: 1;
    }
    .slider-value {
      width: 40px;
      font-weight: 500;
      text-align: right;
    }
  }
  .form-tip {
    margin-top: -8px;
    font-size: 12px;
  }
</style>
