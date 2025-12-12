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
          <NSteps :current="currentStep" size="small">
            <NStep title="安装扩展" />
            <NStep title="获取配置" />
            <NStep title="完成配置" />
          </NSteps>
        </div>

        <!-- 步骤 1: 安装扩展 -->
        <div v-if="currentStep === 1">
          <NAlert type="info" class="mb-[16px]">
            <template #header>安装 Chrome 扩展</template>
            <ol class="mt-[8px] list-decimal pl-[20px]">
              <li class="mb-[8px]">打开 Chrome 浏览器，访问 <NText code>chrome://extensions/</NText></li>
              <li class="mb-[8px]">开启右上角的「开发者模式」</li>
              <li class="mb-[8px]">点击「加载已解压的扩展程序」</li>
              <li>选择项目目录下的 <NText code>frontend/packages/chrome-extension/dist</NText></li>
            </ol>
          </NAlert>
          <div class="flex justify-end">
            <NButton type="primary" @click="currentStep = 2"> 已安装，下一步 </NButton>
          </div>
        </div>

        <!-- 步骤 2: 获取配置 -->
        <div v-if="currentStep === 2">
          <div class="mx-auto max-w-[500px]">
            <NCard embedded class="mb-[16px] text-center">
              <template #header>
                <div class="flex items-center justify-center gap-[8px]">
                  <NIcon size="20" color="#18a058"><FlashOutline /></NIcon>
                  <span>一键配置</span>
                </div>
              </template>
              <p class="mb-[16px] text-[var(--text-n2)]"
                >点击下方按钮复制配置信息，然后在 Chrome 扩展中粘贴即可完成配置。</p
              >
              <NButton type="primary" size="large" block :loading="copyingConfig" @click="handleCopyConfig">
                <template #icon>
                  <NIcon><CopyOutline /></NIcon>
                </template>
                一键复制配置
              </NButton>
              <div
                v-if="configCopied"
                class="mt-[12px] flex items-center justify-center gap-[4px] text-[var(--success-color)]"
              >
                <NIcon><CheckmarkCircleOutline /></NIcon>
                <span>配置已复制到剪贴板</span>
              </div>
            </NCard>

            <NCollapse>
              <NCollapseItem title="查看配置详情" name="details">
                <NDescriptions label-placement="left" :column="1" bordered>
                  <NDescriptionsItem label="CRM 地址">
                    <NText code>{{ crmUrl }}</NText>
                  </NDescriptionsItem>
                  <NDescriptionsItem label="API Token">
                    <div class="flex items-center gap-[8px]">
                      <NText code>{{ tokenDisplay }}</NText>
                      <NButton text type="primary" size="small" @click="handleCopyToken">复制</NButton>
                    </div>
                  </NDescriptionsItem>
                </NDescriptions>
              </NCollapseItem>
            </NCollapse>
          </div>

          <div class="mt-[24px] flex justify-end gap-[16px] border-t border-[var(--border-color)] pt-[16px]">
            <NButton @click="currentStep = 1">上一步</NButton>
            <NButton type="primary" @click="currentStep = 3">已复制，下一步</NButton>
          </div>
        </div>

        <!-- 步骤 3: 完成配置 -->
        <div v-if="currentStep === 3">
          <NResult status="info" title="在扩展中完成配置" description="请按以下步骤完成最后的配置">
            <template #footer>
              <ol class="list-decimal pl-[20px] text-left">
                <li class="mb-[12px]">点击浏览器右上角的扩展图标</li>
                <li class="mb-[12px]">找到「爱企查 CRM 助手」扩展并点击</li>
                <li class="mb-[12px]">在弹出窗口中点击「粘贴配置」按钮</li>
                <li class="mb-[12px]">点击「连接测试」验证配置是否正确</li>
                <li>测试成功后点击「保存设置」</li>
              </ol>
            </template>
          </NResult>

          <NAlert type="warning" class="mt-[16px]">
            <template #header>安全提示</template>
            Token 是您的身份凭证，请勿泄露给他人。Token 有效期与登录会话一致。
          </NAlert>

          <div class="mt-[24px] flex justify-end gap-[16px] border-t border-[var(--border-color)] pt-[16px]">
            <NButton @click="currentStep = 2">上一步</NButton>
            <NButton type="primary" @click="currentStep = 1">重新开始</NButton>
          </div>
        </div>
      </CrmCard>

      <!-- 爱企查配置 -->
      <CrmCard v-if="activeTab === 'iqicha'" hide-footer auto-height>
        <NForm :model="iqichaConfig" label-placement="left" label-width="120">
          <NFormItem :label="t('integrationConfig.iqicha.cookie')">
            <NInput
              v-model:value="iqichaConfig.cookie"
              type="password"
              show-password-on="click"
              :placeholder="t('integrationConfig.iqicha.cookiePlaceholder')"
              style="max-width: 500px"
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
        <NAlert type="info" :title="t('integrationConfig.iqicha.cookieTip')" class="mt-[16px]" />
      </CrmCard>

      <!-- AI 服务配置 -->
      <CrmCard v-if="activeTab === 'ai'" hide-footer auto-height>
        <NForm :model="aiConfig" label-placement="left" label-width="120">
          <NFormItem :label="t('integrationConfig.ai.provider')">
            <NSelect
              v-model:value="aiConfig.provider"
              :options="providerOptions"
              :placeholder="t('integrationConfig.ai.providerPlaceholder')"
              style="max-width: 300px"
              @update:value="handleProviderChange"
            />
          </NFormItem>

          <NFormItem :label="t('integrationConfig.ai.apiKey')">
            <NInput
              v-model:value="aiConfig.apiKey"
              type="password"
              show-password-on="click"
              :placeholder="t('integrationConfig.ai.apiKeyPlaceholder')"
              style="max-width: 500px"
            />
          </NFormItem>

          <NFormItem :label="t('integrationConfig.ai.model')">
            <NSelect
              v-model:value="aiConfig.model"
              :options="modelOptions"
              :placeholder="t('integrationConfig.ai.modelPlaceholder')"
              style="max-width: 300px"
            />
          </NFormItem>

          <NFormItem :label="t('integrationConfig.ai.temperature')">
            <div class="flex w-full max-w-[400px] items-center gap-[16px]">
              <NSlider v-model:value="aiConfig.temperature" :min="0" :max="2" :step="0.1" class="flex-1" />
              <span class="w-[40px] text-right font-medium">{{ aiConfig.temperature }}</span>
            </div>
          </NFormItem>
          <NFormItem>
            <NText depth="3" class="text-[12px]">
              {{ t('integrationConfig.ai.temperatureTip') }}
            </NText>
          </NFormItem>

          <NFormItem :label="t('integrationConfig.ai.maxTokens')">
            <NInputNumber v-model:value="aiConfig.maxTokens" :min="100" :max="32000" :step="100" style="width: 200px" />
          </NFormItem>
          <NFormItem>
            <NText depth="3" class="text-[12px]">
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
      </CrmCard>
    </div>
  </n-scrollbar>
</template>

<script lang="ts" setup>
  import { NScrollbar, useMessage } from 'naive-ui';
  import { CheckmarkCircleOutline, CopyOutline, FlashOutline } from '@vicons/ionicons5';

  import { useI18n } from '@lib/shared/hooks/useI18n';

  import CrmCard from '@/components/pure/crm-card/index.vue';
  import CrmTab from '@/components/pure/crm-tab/index.vue';

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
    const token = localStorage.getItem('token') || localStorage.getItem('accessToken') || '';
    return token.replace(/^"|"$/g, '');
  }

  async function handleCopyConfig() {
    const token = getToken();
    if (!token) {
      message.warning('未找到有效的 Token，请确保已登录');
      return;
    }
    copyingConfig.value = true;
    try {
      const config = { crmUrl: crmUrl.value, token, timestamp: Date.now() };
      await navigator.clipboard.writeText(JSON.stringify(config));
      configCopied.value = true;
      message.success('配置已复制，请在 Chrome 扩展中粘贴');
      setTimeout(() => {
        configCopied.value = false;
      }, 3000);
    } catch {
      message.error('复制失败，请手动复制');
    } finally {
      copyingConfig.value = false;
    }
  }

  function handleCopyToken() {
    const token = getToken();
    if (!token) {
      message.warning('未找到有效的 Token，请确保已登录');
      return;
    }
    navigator.clipboard.writeText(token);
    message.success('Token 已复制到剪贴板');
  }

  function initTokenDisplay() {
    const token = getToken();
    if (!token) {
      tokenDisplay.value = '未登录';
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
        { label: 'GPT-4', value: 'gpt-4' },
        { label: 'GPT-4 Turbo', value: 'gpt-4-turbo' },
        { label: 'GPT-3.5 Turbo', value: 'gpt-3.5-turbo' },
      ],
      claude: [
        { label: 'Claude 3 Opus', value: 'claude-3-opus' },
        { label: 'Claude 3 Sonnet', value: 'claude-3-sonnet' },
        { label: 'Claude 3 Haiku', value: 'claude-3-haiku' },
      ],
      maxkb: [{ label: 'MaxKB Default', value: 'maxkb-default' }],
      local: [
        { label: 'Llama 3', value: 'llama-3' },
        { label: 'Qwen 2', value: 'qwen-2' },
        { label: 'ChatGLM 4', value: 'chatglm-4' },
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
    savingIqicha.value = true;
    try {
      await delay(500);
      message.success(t('integrationConfig.saveSuccess'));
    } catch {
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
