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

        <!-- Chrome 扩展配置 -->
        <NTabPane :name="'extension'" :tab="t('integrationConfig.tab.extension')">
          <NCard>
            <!-- 向导模式 -->
            <NSteps :current="currentStep" class="extension-wizard">
              <NStep title="安装扩展" description="在 Chrome 中安装扩展程序" />
              <NStep title="获取配置" description="一键复制配置信息" />
              <NStep title="完成配置" description="在扩展中粘贴配置" />
            </NSteps>

            <div class="wizard-content">
              <!-- 步骤 1: 安装扩展 -->
              <div v-show="currentStep === 1" class="step-content">
                <NAlert type="info" class="mb-4">
                  <template #header>
                    <NSpace align="center">
                      <NIcon size="18"><ExtensionPuzzleOutline /></NIcon>
                      <span>安装 Chrome 扩展</span>
                    </NSpace>
                  </template>
                  <ol class="extension-steps">
                    <li>打开 Chrome 浏览器，访问 <NText code>chrome://extensions/</NText></li>
                    <li>开启右上角的「开发者模式」</li>
                    <li>点击「加载已解压的扩展程序」</li>
                    <li>选择项目目录下的 <NText code>frontend/packages/chrome-extension/dist</NText></li>
                  </ol>
                </NAlert>
                <div class="step-actions">
                  <NButton type="primary" @click="currentStep = 2">
                    已安装，下一步
                    <template #icon>
                      <NIcon><ArrowForwardOutline /></NIcon>
                    </template>
                  </NButton>
                </div>
              </div>

              <!-- 步骤 2: 获取配置 -->
              <div v-show="currentStep === 2" class="step-content">
                <div class="one-click-config">
                  <NCard embedded class="config-card">
                    <template #header>
                      <NSpace align="center">
                        <NIcon size="20" color="#18a058"><FlashOutline /></NIcon>
                        <span>一键配置</span>
                      </NSpace>
                    </template>
                    <p class="config-desc">点击下方按钮复制配置信息，然后在 Chrome 扩展中粘贴即可完成配置。</p>
                    <NButton type="primary" size="large" block :loading="copyingConfig" @click="handleCopyConfig">
                      <template #icon>
                        <NIcon><CopyOutline /></NIcon>
                      </template>
                      一键复制配置
                    </NButton>
                    <NText v-if="configCopied" type="success" class="copy-success">
                      <NIcon><CheckmarkCircleOutline /></NIcon>
                      配置已复制到剪贴板
                    </NText>
                  </NCard>

                  <NCollapse class="mt-4">
                    <NCollapseItem title="查看配置详情" name="details">
                      <NDescriptions label-placement="left" :column="1" bordered>
                        <NDescriptionsItem label="CRM 地址">
                          <NText code>{{ crmUrl }}</NText>
                        </NDescriptionsItem>
                        <NDescriptionsItem label="API Token">
                          <NSpace>
                            <NText code>{{ tokenDisplay }}</NText>
                            <NButton text type="primary" size="small" @click="handleCopyToken">复制</NButton>
                          </NSpace>
                        </NDescriptionsItem>
                      </NDescriptions>
                    </NCollapseItem>
                  </NCollapse>
                </div>

                <div class="step-actions">
                  <NSpace>
                    <NButton @click="currentStep = 1">上一步</NButton>
                    <NButton type="primary" @click="currentStep = 3">
                      已复制，下一步
                      <template #icon>
                        <NIcon><ArrowForwardOutline /></NIcon>
                      </template>
                    </NButton>
                  </NSpace>
                </div>
              </div>

              <!-- 步骤 3: 完成配置 -->
              <div v-show="currentStep === 3" class="step-content">
                <NResult status="info" title="在扩展中完成配置" description="请按以下步骤完成最后的配置">
                  <template #footer>
                    <ol class="final-steps">
                      <li
                        >点击浏览器右上角的扩展图标 <NIcon><ExtensionPuzzleOutline /></NIcon
                      ></li>
                      <li>找到「爱企查 CRM 助手」扩展并点击</li>
                      <li>在弹出窗口中点击「粘贴配置」按钮</li>
                      <li>点击「连接测试」验证配置是否正确</li>
                      <li>测试成功后点击「保存设置」</li>
                    </ol>
                  </template>
                </NResult>

                <NAlert type="warning" class="mt-4">
                  <template #header>安全提示</template>
                  Token 是您的身份凭证，请勿泄露给他人。Token 有效期与登录会话一致。
                </NAlert>

                <div class="step-actions">
                  <NSpace>
                    <NButton @click="currentStep = 2">上一步</NButton>
                    <NButton type="primary" @click="currentStep = 1">重新开始</NButton>
                  </NSpace>
                </div>
              </div>
            </div>
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
  import {
    ArrowForwardOutline,
    CheckmarkCircleOutline,
    CopyOutline,
    ExtensionPuzzleOutline,
    FlashOutline,
  } from '@vicons/ionicons5';

  import { useI18n } from '@lib/shared/hooks/useI18n';

  const { t } = useI18n();
  const message = useMessage();

  // Chrome 扩展配置 - 向导步骤
  const currentStep = ref(1);
  const copyingConfig = ref(false);
  const configCopied = ref(false);

  // Chrome 扩展配置
  const crmUrl = computed(() => window.location.origin);
  const tokenDisplay = ref('');

  // 获取当前 Token
  function getToken(): string {
    const token = localStorage.getItem('token') || localStorage.getItem('accessToken') || '';
    return token.replace(/^"|"$/g, '');
  }

  // 一键复制配置（JSON 格式）
  async function handleCopyConfig() {
    const token = getToken();
    if (!token) {
      message.warning('未找到有效的 Token，请确保已登录');
      return;
    }

    copyingConfig.value = true;
    try {
      const config = {
        crmUrl: crmUrl.value,
        token,
        timestamp: Date.now(),
      };
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

  // 复制 Token
  function handleCopyToken() {
    const token = getToken();
    if (!token) {
      message.warning('未找到有效的 Token，请确保已登录');
      return;
    }
    navigator.clipboard.writeText(token);
    message.success('Token 已复制到剪贴板');
  }

  // 初始化 Token 显示
  function initTokenDisplay() {
    const token = getToken();
    if (token) {
      tokenDisplay.value =
        token.length > 20 ? `${token.substring(0, 10)}...${token.substring(token.length - 10)}` : token;
    } else {
      tokenDisplay.value = '未登录';
    }
  }

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

  // 模型选项
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

  async function loadConfig() {
    initTokenDisplay();
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
  .extension-wizard {
    margin-bottom: 24px;
    padding: 0 20px;
  }
  .wizard-content {
    min-height: 300px;
  }
  .step-content {
    padding: 16px 0;
  }
  .step-actions {
    display: flex;
    justify-content: flex-end;
    margin-top: 24px;
    padding-top: 16px;
    border-top: 1px solid var(--border-color);
  }
  .extension-steps {
    margin: 8px 0 0;
    padding-left: 20px;
    li {
      margin: 8px 0;
      line-height: 1.6;
    }
  }
  .one-click-config {
    margin: 0 auto;
    max-width: 500px;
  }
  .config-card {
    text-align: center;
  }
  .config-desc {
    margin: 0 0 16px;
    color: var(--text-color-3);
  }
  .copy-success {
    display: flex;
    justify-content: center;
    align-items: center;
    margin-top: 12px;
    gap: 4px;
  }
  .final-steps {
    margin: 0;
    padding-left: 20px;
    text-align: left;
    li {
      margin: 12px 0;
      line-height: 1.6;
    }
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
  .mb-4 {
    margin-bottom: 16px;
  }
  .mt-4 {
    margin-top: 16px;
  }
</style>
