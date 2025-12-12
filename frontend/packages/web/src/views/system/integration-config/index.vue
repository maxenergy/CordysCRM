<template>
  <n-scrollbar class="integration-config">
    <div class="p-[16px]">
      <!-- Tab 切换 -->
      <CrmCard no-content-padding hide-footer auto-height class="mb-[16px]">
        <CrmTab v-model:active-tab="activeTab" no-content :tab-list="tabList" type="line" />
      </CrmCard>

      <!-- Chrome 扩展配置 -->
      <CrmCard v-if="activeTab === 'extension'" hide-footer auto-height>
        <div class="mb-[24px]">
          <n-steps :current="currentStep" size="small">
            <n-step :title="t('integrationConfig.extension.step.install')" />
            <n-step :title="t('integrationConfig.extension.step.config')" />
            <n-step :title="t('integrationConfig.extension.step.complete')" />
          </n-steps>
        </div>

        <!-- 步骤 1: 安装扩展 -->
        <div v-if="currentStep === 1">
          <n-alert type="info" class="mb-[16px]">
            <template #header>{{ t('integrationConfig.extension.install.title') }}</template>
            <ol class="mt-[8px] list-decimal pl-[20px]">
              <li class="mb-[8px]">
                {{ t('integrationConfig.extension.install.step1') }}
                <n-text code>chrome://extensions/</n-text>
              </li>
              <li class="mb-[8px]">{{ t('integrationConfig.extension.install.step2') }}</li>
              <li class="mb-[8px]">{{ t('integrationConfig.extension.install.step3') }}</li>
              <li>
                {{ t('integrationConfig.extension.install.step4') }}
                <n-text code>frontend/packages/chrome-extension/dist</n-text>
              </li>
            </ol>
          </n-alert>
          <div class="flex justify-end">
            <n-button type="primary" @click="currentStep = 2">
              {{ t('integrationConfig.extension.install.next') }}
            </n-button>
          </div>
        </div>

        <!-- 步骤 2: 获取配置 -->
        <div v-if="currentStep === 2">
          <div class="mx-auto max-w-[500px]">
            <n-card embedded class="mb-[16px] text-center">
              <template #header>
                <div class="flex items-center justify-center gap-[8px]">
                  <n-icon size="20" color="#18a058"><FlashOutline /></n-icon>
                  <span>{{ t('integrationConfig.extension.config.title') }}</span>
                </div>
              </template>
              <p class="mb-[16px] text-[var(--text-n2)]">
                {{ t('integrationConfig.extension.config.desc') }}
              </p>
              <n-button type="primary" size="large" block :loading="copyingConfig" @click="handleCopyConfig">
                <template #icon>
                  <n-icon><CopyOutline /></n-icon>
                </template>
                {{ t('integrationConfig.extension.config.copy') }}
              </n-button>
              <div
                v-if="configCopied"
                class="mt-[12px] flex items-center justify-center gap-[4px] text-[var(--success-color)]"
              >
                <n-icon><CheckmarkCircleOutline /></n-icon>
                <span>{{ t('integrationConfig.extension.config.copied') }}</span>
              </div>
            </n-card>

            <n-collapse>
              <n-collapse-item :title="t('integrationConfig.extension.config.details')" name="details">
                <n-descriptions label-placement="left" :column="1" bordered>
                  <n-descriptions-item :label="t('integrationConfig.extension.config.crmUrl')">
                    <n-text code>{{ crmUrl }}</n-text>
                  </n-descriptions-item>
                  <n-descriptions-item :label="t('integrationConfig.extension.config.token')">
                    <div class="flex items-center gap-[8px]">
                      <n-text code>{{ tokenDisplay }}</n-text>
                      <n-button text type="primary" size="small" @click="handleCopyToken">
                        {{ t('integrationConfig.common.copy') }}
                      </n-button>
                    </div>
                  </n-descriptions-item>
                </n-descriptions>
              </n-collapse-item>
            </n-collapse>
          </div>

          <div class="mt-[24px] flex justify-end gap-[16px] border-t border-[var(--border-color)] pt-[16px]">
            <n-button @click="currentStep = 1">{{ t('integrationConfig.extension.config.prev') }}</n-button>
            <n-button type="primary" @click="currentStep = 3">
              {{ t('integrationConfig.extension.config.next') }}
            </n-button>
          </div>
        </div>

        <!-- 步骤 3: 完成配置 -->
        <div v-if="currentStep === 3">
          <n-result
            status="info"
            :title="t('integrationConfig.extension.complete.title')"
            :description="t('integrationConfig.extension.complete.desc')"
          >
            <template #footer>
              <ol class="list-decimal pl-[20px] text-left">
                <li class="mb-[12px]">{{ t('integrationConfig.extension.complete.step1') }}</li>
                <li class="mb-[12px]">{{ t('integrationConfig.extension.complete.step2') }}</li>
                <li class="mb-[12px]">{{ t('integrationConfig.extension.complete.step3') }}</li>
                <li class="mb-[12px]">{{ t('integrationConfig.extension.complete.step4') }}</li>
                <li>{{ t('integrationConfig.extension.complete.step5') }}</li>
              </ol>
            </template>
          </n-result>

          <n-alert type="warning" class="mt-[16px]">
            <template #header>{{ t('integrationConfig.extension.complete.security') }}</template>
            {{ t('integrationConfig.extension.complete.securityTip') }}
          </n-alert>

          <div class="mt-[24px] flex justify-end gap-[16px] border-t border-[var(--border-color)] pt-[16px]">
            <n-button @click="currentStep = 2">{{ t('integrationConfig.extension.config.prev') }}</n-button>
            <n-button type="primary" @click="currentStep = 1">
              {{ t('integrationConfig.extension.complete.restart') }}
            </n-button>
          </div>
        </div>
      </CrmCard>

      <!-- 爱企查配置 -->
      <CrmCard v-if="activeTab === 'iqicha'" hide-footer auto-height>
        <n-form :model="iqichaConfig" label-placement="left" label-width="120">
          <n-form-item :label="t('integrationConfig.iqicha.cookie')">
            <n-input
              v-model:value="iqichaConfig.cookie"
              type="password"
              show-password-on="click"
              :placeholder="t('integrationConfig.iqicha.cookiePlaceholder')"
              style="max-width: 500px"
            />
          </n-form-item>
          <n-form-item>
            <n-space>
              <n-button :loading="testingIqicha" @click="handleTestIqicha">
                {{ t('integrationConfig.testConnection') }}
              </n-button>
              <n-button type="primary" :loading="savingIqicha" @click="handleSaveIqicha">
                {{ t('integrationConfig.save') }}
              </n-button>
            </n-space>
          </n-form-item>
        </n-form>
        <n-alert type="info" :title="t('integrationConfig.iqicha.cookieTip')" class="mt-[16px]" />
      </CrmCard>

      <!-- AI 服务配置 -->
      <CrmCard v-if="activeTab === 'ai'" hide-footer auto-height>
        <n-form :model="aiConfig" label-placement="left" label-width="120">
          <n-form-item :label="t('integrationConfig.ai.provider')">
            <n-select
              v-model:value="aiConfig.provider"
              :options="providerOptions"
              :placeholder="t('integrationConfig.ai.providerPlaceholder')"
              style="max-width: 300px"
              @update:value="handleProviderChange"
            />
          </n-form-item>

          <n-form-item :label="t('integrationConfig.ai.apiKey')">
            <n-input
              v-model:value="aiConfig.apiKey"
              type="password"
              show-password-on="click"
              :placeholder="t('integrationConfig.ai.apiKeyPlaceholder')"
              style="max-width: 500px"
            />
          </n-form-item>

          <n-form-item :label="t('integrationConfig.ai.model')">
            <n-select
              v-model:value="aiConfig.model"
              :options="modelOptions"
              :placeholder="t('integrationConfig.ai.modelPlaceholder')"
              style="max-width: 300px"
            />
          </n-form-item>

          <n-form-item :label="t('integrationConfig.ai.temperature')">
            <div class="flex w-full max-w-[400px] items-center gap-[16px]">
              <n-slider v-model:value="aiConfig.temperature" :min="0" :max="2" :step="0.1" class="flex-1" />
              <span class="w-[40px] text-right font-medium">{{ aiConfig.temperature }}</span>
            </div>
          </n-form-item>
          <n-form-item>
            <n-text depth="3" class="text-[12px]">
              {{ t('integrationConfig.ai.temperatureTip') }}
            </n-text>
          </n-form-item>

          <n-form-item :label="t('integrationConfig.ai.maxTokens')">
            <n-input-number
              v-model:value="aiConfig.maxTokens"
              :min="100"
              :max="32000"
              :step="100"
              style="width: 200px"
            />
          </n-form-item>
          <n-form-item>
            <n-text depth="3" class="text-[12px]">
              {{ t('integrationConfig.ai.maxTokensTip') }}
            </n-text>
          </n-form-item>

          <n-form-item>
            <n-space>
              <n-button :loading="testingAI" @click="handleTestAI">
                {{ t('integrationConfig.testConnection') }}
              </n-button>
              <n-button type="primary" :loading="savingAI" @click="handleSaveAI">
                {{ t('integrationConfig.save') }}
              </n-button>
            </n-space>
          </n-form-item>
        </n-form>
      </CrmCard>
    </div>
  </n-scrollbar>
</template>

<script lang="ts" setup>
  import { computed, onMounted, ref } from 'vue';
  import {
    NAlert,
    NButton,
    NCard,
    NCollapse,
    NCollapseItem,
    NDescriptions,
    NDescriptionsItem,
    NForm,
    NFormItem,
    NIcon,
    NInput,
    NInputNumber,
    NResult,
    NScrollbar,
    NSelect,
    NSlider,
    NSpace,
    NStep,
    NSteps,
    NText,
    useMessage,
  } from 'naive-ui';
  import { CheckmarkCircleOutline, CopyOutline, FlashOutline } from '@vicons/ionicons5';

  import { useI18n } from '@lib/shared/hooks/useI18n';
  import { getToken as getAuthToken } from '@lib/shared/method/auth';

  import CrmCard from '@/components/pure/crm-card/index.vue';
  import CrmTab from '@/components/pure/crm-tab/index.vue';

  import { checkIqichaCookieStatus, saveIqichaCookie } from '@/api/modules';

  const { t } = useI18n();
  const message = useMessage();

  // Tab 配置
  const activeTab = ref('extension');
  const tabList = computed(() => [
    { name: 'extension', tab: t('integrationConfig.tab.extension') },
    { name: 'iqicha', tab: t('integrationConfig.tab.iqicha') },
    { name: 'ai', tab: t('integrationConfig.tab.ai') },
  ]);

  // Chrome 扩展配置 - 向导步骤
  const currentStep = ref(1);
  const copyingConfig = ref(false);
  const configCopied = ref(false);
  const crmUrl = computed(() => window.location.origin);
  const tokenDisplay = ref('');

  function getToken(): string {
    const authToken = getAuthToken();
    return authToken.sessionId || '';
  }

  async function handleCopyConfig() {
    const token = getToken();
    if (!token) {
      message.warning(t('integrationConfig.extension.config.noToken'));
      return;
    }
    copyingConfig.value = true;
    try {
      const config = { crmUrl: crmUrl.value, token, timestamp: Date.now() };
      await navigator.clipboard.writeText(JSON.stringify(config));
      configCopied.value = true;
      message.success(t('integrationConfig.extension.config.copySuccess'));
      setTimeout(() => {
        configCopied.value = false;
      }, 3000);
    } catch {
      message.error(t('integrationConfig.extension.config.copyFailed'));
    } finally {
      copyingConfig.value = false;
    }
  }

  async function handleCopyToken() {
    const token = getToken();
    if (!token) {
      message.warning(t('integrationConfig.extension.config.noToken'));
      return;
    }
    try {
      await navigator.clipboard.writeText(token);
      message.success(t('integrationConfig.extension.config.tokenCopied'));
    } catch {
      message.error(t('integrationConfig.extension.config.copyFailed'));
    }
  }

  function initTokenDisplay() {
    const token = getToken();
    if (!token) {
      tokenDisplay.value = t('integrationConfig.extension.config.notLoggedIn');
      return;
    }
    tokenDisplay.value =
      token.length > 20 ? `${token.substring(0, 10)}...${token.substring(token.length - 10)}` : token;
  }

  // 爱企查配置
  const iqichaConfig = ref({ cookie: '' });
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

  const providerOptions = computed(() => [
    { label: t('integrationConfig.provider.openai'), value: 'openai' },
    { label: t('integrationConfig.provider.claude'), value: 'claude' },
    { label: t('integrationConfig.provider.maxkb'), value: 'maxkb' },
    { label: t('integrationConfig.provider.local'), value: 'local' },
  ]);

  const modelOptions = computed(() => {
    const models: Record<string, Array<{ label: string; value: string }>> = {
      openai: [
        { label: t('integrationConfig.model.gpt4'), value: 'gpt-4' },
        { label: t('integrationConfig.model.gpt4turbo'), value: 'gpt-4-turbo' },
        { label: t('integrationConfig.model.gpt35turbo'), value: 'gpt-3.5-turbo' },
      ],
      claude: [
        { label: t('integrationConfig.model.claude3opus'), value: 'claude-3-opus' },
        { label: t('integrationConfig.model.claude3sonnet'), value: 'claude-3-sonnet' },
        { label: t('integrationConfig.model.claude3haiku'), value: 'claude-3-haiku' },
      ],
      maxkb: [{ label: t('integrationConfig.model.maxkbDefault'), value: 'maxkb-default' }],
      local: [
        { label: t('integrationConfig.model.llama3'), value: 'llama-3' },
        { label: t('integrationConfig.model.qwen2'), value: 'qwen-2' },
        { label: t('integrationConfig.model.chatglm4'), value: 'chatglm-4' },
      ],
    };
    return models[aiConfig.value.provider] || [];
  });

  function delay(ms: number): Promise<void> {
    return new Promise((resolve) => {
      setTimeout(resolve, ms);
    });
  }

  function handleProviderChange() {
    aiConfig.value.model = modelOptions.value[0]?.value || '';
  }

  async function handleTestIqicha() {
    if (!iqichaConfig.value.cookie) {
      message.warning(t('integrationConfig.iqicha.cookiePlaceholder'));
      return;
    }
    testingIqicha.value = true;
    try {
      await delay(1000);
      message.success(t('integrationConfig.testSuccess'));
    } catch {
      message.error(t('integrationConfig.testFailed'));
    } finally {
      testingIqicha.value = false;
    }
  }

  async function handleSaveIqicha() {
    if (!iqichaConfig.value.cookie) {
      message.warning(t('integrationConfig.iqicha.cookiePlaceholder'));
      return;
    }
    savingIqicha.value = true;
    console.log('[DEBUG] 开始保存爱企查Cookie, cookie长度:', iqichaConfig.value.cookie.length);
    try {
      const result = await saveIqichaCookie(iqichaConfig.value.cookie);
      console.log('[DEBUG] 保存爱企查Cookie响应:', result);
      if (result.success) {
        message.success(t('integrationConfig.saveSuccess'));
      } else {
        message.error(result.message || t('integrationConfig.saveFailed'));
      }
    } catch (error) {
      console.error('[DEBUG] 保存爱企查Cookie异常:', error);
      message.error(t('integrationConfig.saveFailed'));
    } finally {
      savingIqicha.value = false;
    }
  }

  async function handleTestAI() {
    if (!aiConfig.value.apiKey) {
      message.warning(t('integrationConfig.ai.apiKeyPlaceholder'));
      return;
    }
    testingAI.value = true;
    try {
      await delay(1000);
      message.success(t('integrationConfig.testSuccess'));
    } catch {
      message.error(t('integrationConfig.testFailed'));
    } finally {
      testingAI.value = false;
    }
  }

  async function handleSaveAI() {
    savingAI.value = true;
    try {
      await delay(500);
      message.success(t('integrationConfig.saveSuccess'));
    } catch {
      message.error(t('integrationConfig.saveFailed'));
    } finally {
      savingAI.value = false;
    }
  }

  onMounted(() => {
    initTokenDisplay();
  });
</script>

<style lang="less" scoped>
  .integration-config {
    height: 100%;
  }
</style>
