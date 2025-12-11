<template>
  <CrmDrawer
    v-model:show="visible"
    :title="t('aiScript.title')"
    width="480"
    :footer="false"
  >
    <div class="ai-script-drawer">
      <!-- 场景选择 -->
      <div class="section">
        <div class="section-title">{{ t('aiScript.scene') }}</div>
        <NRadioGroup v-model:value="form.scene" name="scene">
          <NSpace>
            <NRadioButton
              v-for="scene in sceneOptions"
              :key="scene.value"
              :value="scene.value"
            >
              {{ scene.label }}
            </NRadioButton>
          </NSpace>
        </NRadioGroup>
      </div>

      <!-- 渠道选择 -->
      <div class="section">
        <div class="section-title">{{ t('aiScript.channel') }}</div>
        <NRadioGroup v-model:value="form.channel" name="channel">
          <NSpace>
            <NRadioButton
              v-for="channel in channelOptions"
              :key="channel.value"
              :value="channel.value"
            >
              {{ channel.label }}
            </NRadioButton>
          </NSpace>
        </NRadioGroup>
      </div>

      <!-- 语气选择 -->
      <div class="section">
        <div class="section-title">{{ t('aiScript.tone') }}</div>
        <NRadioGroup v-model:value="form.tone" name="tone">
          <NSpace>
            <NRadioButton
              v-for="tone in toneOptions"
              :key="tone.value"
              :value="tone.value"
            >
              {{ tone.label }}
            </NRadioButton>
          </NSpace>
        </NRadioGroup>
      </div>

      <!-- 模板选择 -->
      <div class="section">
        <div class="section-title">{{ t('aiScript.template') }}</div>
        <NSelect
          v-model:value="form.templateId"
          :options="templateOptions"
          :placeholder="t('aiScript.templatePlaceholder')"
          clearable
        />
      </div>

      <!-- 生成按钮 -->
      <NButton
        type="primary"
        block
        size="large"
        :loading="generating"
        @click="handleGenerate"
      >
        <template #icon>
          <NIcon><SparklesOutline /></NIcon>
        </template>
        {{ generating ? t('aiScript.generating') : t('aiScript.generate') }}
      </NButton>

      <!-- 结果展示 -->
      <div class="section result-section">
        <div class="section-title">{{ t('aiScript.result') }}</div>
        <NInput
          v-model:value="generatedContent"
          type="textarea"
          :rows="8"
          :placeholder="t('aiScript.resultPlaceholder')"
        />
        <NSpace v-if="generatedContent" justify="end" class="mt-[12px]">
          <NButton size="small" @click="handleCopy">
            <template #icon>
              <NIcon><CopyOutline /></NIcon>
            </template>
            {{ t('aiScript.copy') }}
          </NButton>
          <NButton size="small" @click="handleSaveAsTemplate">
            <template #icon>
              <NIcon><SaveOutline /></NIcon>
            </template>
            {{ t('aiScript.saveAsTemplate') }}
          </NButton>
        </NSpace>
      </div>

      <!-- 历史记录 -->
      <NCollapse v-if="history.length > 0">
        <NCollapseItem :title="t('aiScript.history')" name="history">
          <template #header-extra>
            <NIcon><TimeOutline /></NIcon>
          </template>
          <NList hoverable clickable>
            <NListItem
              v-for="(item, index) in history"
              :key="index"
              @click="handleLoadHistory(item)"
            >
              <NThing>
                <template #header>
                  <NEllipsis :line-clamp="2">{{ item.content }}</NEllipsis>
                </template>
                <template #description>
                  <NSpace size="small">
                    <NTag size="small" :bordered="false">{{ getSceneLabel(item.scene) }}</NTag>
                    <NTag size="small" :bordered="false">{{ getChannelLabel(item.channel) }}</NTag>
                    <NTag size="small" :bordered="false">{{ getToneLabel(item.tone) }}</NTag>
                  </NSpace>
                </template>
              </NThing>
            </NListItem>
          </NList>
        </NCollapseItem>
      </NCollapse>
    </div>

    <!-- 保存模板对话框 -->
    <NModal
      v-model:show="showSaveModal"
      preset="dialog"
      :title="t('aiScript.saveTemplate.title')"
      :positive-text="t('aiScript.saveTemplate.confirm')"
      :negative-text="t('aiScript.saveTemplate.cancel')"
      @positive-click="handleConfirmSave"
    >
      <NInput
        v-model:value="templateName"
        :placeholder="t('aiScript.saveTemplate.namePlaceholder')"
      />
    </NModal>
  </CrmDrawer>
</template>

<script lang="ts" setup>
  import { useMessage } from 'naive-ui';
  import { SparklesOutline, CopyOutline, SaveOutline, TimeOutline } from '@vicons/ionicons5';
  import { useI18n } from '@lib/shared/hooks/useI18n';
  import type { ScriptScene, ScriptChannel, ScriptTone, ScriptHistoryItem } from '@lib/shared/models/ai';

  import CrmDrawer from '@/components/pure/crm-drawer/index.vue';

  // 简单的复制到剪贴板函数
  function copyToClipboard(text: string): Promise<void> {
    return navigator.clipboard.writeText(text);
  }

  const props = defineProps<{
    customerId: string;
  }>();

  const visible = defineModel<boolean>('show', {
    required: true,
  });

  const { t } = useI18n();
  const message = useMessage();

  // 表单数据
  const form = ref({
    scene: 'first_contact' as ScriptScene,
    channel: 'phone' as ScriptChannel,
    tone: 'professional' as ScriptTone,
    templateId: null as string | null,
  });

  // 场景选项
  const sceneOptions = computed(() => [
    { label: t('aiScript.scene.firstContact'), value: 'first_contact' },
    { label: t('aiScript.scene.productIntro'), value: 'product_intro' },
    { label: t('aiScript.scene.meetingInvite'), value: 'meeting_invite' },
    { label: t('aiScript.scene.followUp'), value: 'follow_up' },
  ]);

  // 渠道选项
  const channelOptions = computed(() => [
    { label: t('aiScript.channel.phone'), value: 'phone' },
    { label: t('aiScript.channel.wechat'), value: 'wechat' },
    { label: t('aiScript.channel.email'), value: 'email' },
  ]);

  // 语气选项
  const toneOptions = computed(() => [
    { label: t('aiScript.tone.professional'), value: 'professional' },
    { label: t('aiScript.tone.enthusiastic'), value: 'enthusiastic' },
    { label: t('aiScript.tone.concise'), value: 'concise' },
  ]);

  // 模板选项
  const templateOptions = ref<{ label: string; value: string }[]>([]);

  // 生成状态
  const generating = ref(false);
  const generatedContent = ref('');

  // 历史记录
  const history = ref<ScriptHistoryItem[]>([]);

  // 保存模板
  const showSaveModal = ref(false);
  const templateName = ref('');

  // 生成话术
  async function handleGenerate() {
    generating.value = true;
    try {
      // TODO: 调用 API 生成话术
      // const result = await generateScript({
      //   customerId: props.customerId,
      //   scene: form.value.scene,
      //   channel: form.value.channel,
      //   tone: form.value.tone,
      //   templateId: form.value.templateId || undefined,
      // });
      // generatedContent.value = result.content;

      // 模拟生成
      await new Promise(resolve => setTimeout(resolve, 2000));
      generatedContent.value = getMockScript();

      // 添加到历史记录
      history.value.unshift({
        id: Date.now().toString(),
        content: generatedContent.value,
        scene: form.value.scene,
        channel: form.value.channel,
        tone: form.value.tone,
        createdAt: new Date().toISOString(),
      });

      // 限制历史记录数量
      if (history.value.length > 10) {
        history.value = history.value.slice(0, 10);
      }
    } catch (e) {
      console.error('Failed to generate script:', e);
    } finally {
      generating.value = false;
    }
  }

  // 复制到剪贴板
  async function handleCopy() {
    if (!generatedContent.value) return;
    try {
      await copyToClipboard(generatedContent.value);
      message.success(t('aiScript.copySuccess'));
    } catch (e) {
      console.error('Failed to copy:', e);
    }
  }

  // 保存为模板
  function handleSaveAsTemplate() {
    templateName.value = '';
    showSaveModal.value = true;
  }

  // 确认保存模板
  async function handleConfirmSave() {
    if (!templateName.value.trim()) return;

    try {
      // TODO: 调用 API 保存模板
      // await saveScriptTemplate({
      //   name: templateName.value,
      //   content: generatedContent.value,
      //   scene: form.value.scene,
      //   channel: form.value.channel,
      //   tone: form.value.tone,
      // });

      message.success(t('aiScript.saveSuccess'));
      showSaveModal.value = false;
    } catch (e) {
      message.error(t('aiScript.saveFailed'));
      console.error('Failed to save template:', e);
    }
  }

  // 加载历史记录
  function handleLoadHistory(item: ScriptHistoryItem) {
    form.value.scene = item.scene;
    form.value.channel = item.channel;
    form.value.tone = item.tone;
    generatedContent.value = item.content;
  }

  // 获取场景标签
  function getSceneLabel(scene: ScriptScene): string {
    const option = sceneOptions.value.find(o => o.value === scene);
    return option?.label || scene;
  }

  // 获取渠道标签
  function getChannelLabel(channel: ScriptChannel): string {
    const option = channelOptions.value.find(o => o.value === channel);
    return option?.label || channel;
  }

  // 获取语气标签
  function getToneLabel(tone: ScriptTone): string {
    const option = toneOptions.value.find(o => o.value === tone);
    return option?.label || tone;
  }

  // 模拟话术内容
  function getMockScript(): string {
    const scripts: Record<ScriptScene, Record<ScriptChannel, string>> = {
      first_contact: {
        phone: `您好，我是XX公司的销售顾问小王。

我们注意到贵公司在数字化转型方面有很大的发展潜力，我们专注于为企业提供一站式CRM解决方案，已经帮助超过500家企业提升了30%以上的销售效率。

请问您现在方便聊几分钟吗？我想简单了解一下贵公司目前在客户管理方面的情况，看看我们是否能够提供一些帮助。`,
        wechat: `您好！我是XX公司的小王 👋

我们专注于企业CRM解决方案，已帮助500+企业提升销售效率。

看到贵公司在行业内发展很好，想了解一下您目前在客户管理方面是否有一些痛点？

方便的话，我可以发一些我们的案例给您参考 📊`,
        email: `尊敬的领导：

您好！我是XX公司的销售顾问小王。

我们是一家专注于企业CRM解决方案的科技公司，已成功帮助超过500家企业实现数字化转型，平均提升销售效率30%以上。

我们注意到贵公司在行业内的出色表现，相信我们的解决方案能够为贵公司的业务发展提供有力支持。

如您方便，希望能安排一次简短的线上交流，了解贵公司的具体需求。

期待您的回复！

此致
敬礼

小王
XX公司 销售顾问
电话：138-xxxx-xxxx`,
      },
      product_intro: {
        phone: `我们的CRM系统主要有三大核心优势：

第一，智能客户画像。系统会自动整合客户信息，生成360度客户视图，帮助销售人员快速了解客户。

第二，AI话术推荐。基于客户特征和历史沟通记录，系统会智能推荐最佳沟通话术，提升成交率。

第三，移动办公支持。支持手机端随时随地处理业务，不错过任何商机。

您对哪个功能比较感兴趣？`,
        wechat: `我们CRM的核心优势 ⭐

1️⃣ 智能客户画像 - 360度了解客户
2️⃣ AI话术推荐 - 提升成交率
3️⃣ 移动办公 - 随时随地处理业务

这是我们的产品介绍资料，您可以先看看 📎

有任何问题随时问我～`,
        email: `尊敬的领导：

感谢您对我们产品的关注！

以下是我们CRM系统的核心功能介绍：

【智能客户画像】
- 自动整合多渠道客户数据
- 生成360度客户视图
- AI分析客户价值和需求

【AI话术推荐】
- 基于客户特征智能推荐话术
- 历史沟通记录分析
- 持续优化推荐效果

【移动办公支持】
- iOS/Android双端支持
- 离线数据同步
- 实时消息推送

附件是详细的产品介绍资料，供您参考。

如有任何问题，欢迎随时联系我。

此致
敬礼`,
      },
      meeting_invite: {
        phone: `基于我们之前的沟通，我觉得我们的方案确实能够帮助贵公司解决目前的痛点。

我想邀请您参加一次线上演示会议，大概30分钟，我会详细展示系统的核心功能，您也可以提出具体的问题。

您看这周三下午3点或者周四上午10点，哪个时间比较方便？`,
        wechat: `王总，基于我们之前的沟通，我觉得可以安排一次详细的产品演示 💻

大概30分钟，我会展示：
✅ 客户管理核心功能
✅ AI智能推荐演示
✅ 移动端操作体验

您看这周三下午3点或周四上午10点，哪个时间方便？

我提前发会议链接给您 📅`,
        email: `尊敬的王总：

感谢您对我们产品的持续关注！

基于我们之前的沟通，我认为安排一次详细的产品演示会议将有助于您更全面地了解我们的解决方案。

会议内容：
- CRM系统核心功能演示
- AI智能推荐实际效果展示
- 针对贵公司需求的定制化方案讨论

建议时间（约30分钟）：
- 选项一：本周三（12月13日）下午3:00
- 选项二：本周四（12月14日）上午10:00

请您选择一个方便的时间，我将发送会议邀请。

期待与您的交流！

此致
敬礼`,
      },
      follow_up: {
        phone: `王总您好，我是XX公司的小王。

上次我们聊了关于CRM系统的事情，不知道您这边考虑得怎么样了？

如果您还有什么疑问，或者需要我补充什么资料，随时告诉我。

另外，我们最近推出了一个限时优惠活动，如果本月内签约可以享受8折优惠，您看要不要了解一下？`,
        wechat: `王总好！我是小王 👋

上次聊的CRM系统，您考虑得怎么样了？

有任何问题随时问我～

对了，我们最近有个限时优惠 🎁
本月签约可享8折，要不要了解下？`,
        email: `尊敬的王总：

您好！我是XX公司的小王。

距离我们上次沟通已经过去一周了，想跟您确认一下关于CRM系统的考虑情况。

如果您还有任何疑问，或需要补充资料，请随时告诉我。

另外，我们公司近期推出了限时优惠活动：
- 本月内签约可享受8折优惠
- 赠送3个月免费技术支持
- 免费数据迁移服务

如您有兴趣，我可以为您详细介绍。

期待您的回复！

此致
敬礼`,
      },
    };

    return scripts[form.value.scene]?.[form.value.channel] || '话术生成中...';
  }

  // 加载模板列表
  async function loadTemplates() {
    try {
      // TODO: 调用 API 获取模板列表
      // const templates = await getScriptTemplates();
      // templateOptions.value = templates.map(t => ({ label: t.name, value: t.id }));
    } catch (e) {
      console.error('Failed to load templates:', e);
    }
  }

  // 监听显示状态
  watch(visible, (val) => {
    if (val) {
      loadTemplates();
    }
  });
</script>

<style lang="less" scoped>
  .ai-script-drawer {
    padding: 16px;
  }

  .section {
    margin-bottom: 24px;
  }

  .section-title {
    margin-bottom: 12px;
    font-weight: 600;
    font-size: 14px;
    color: var(--text-n2);
  }

  .result-section {
    margin-top: 24px;
  }
</style>
