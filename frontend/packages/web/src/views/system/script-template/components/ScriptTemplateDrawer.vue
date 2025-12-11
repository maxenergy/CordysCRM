<template>
  <CrmDrawer
    v-model:show="visible"
    :title="isEdit ? t('scriptTemplate.edit') : t('scriptTemplate.add')"
    width="600"
    @positive-click="handleSave"
  >
    <NForm
      ref="formRef"
      :model="form"
      :rules="rules"
      label-placement="left"
      label-width="100"
    >
      <NFormItem :label="t('scriptTemplate.form.name')" path="name">
        <NInput
          v-model:value="form.name"
          :placeholder="t('scriptTemplate.form.namePlaceholder')"
        />
      </NFormItem>

      <NFormItem :label="t('scriptTemplate.form.industry')" path="industry">
        <NSelect
          v-model:value="form.industry"
          :options="industryOptions"
          :placeholder="t('scriptTemplate.form.industryPlaceholder')"
        />
      </NFormItem>

      <NFormItem :label="t('scriptTemplate.form.scene')" path="scene">
        <NRadioGroup v-model:value="form.scene">
          <NSpace>
            <NRadio
              v-for="option in sceneOptions"
              :key="option.value"
              :value="option.value"
            >
              {{ option.label }}
            </NRadio>
          </NSpace>
        </NRadioGroup>
      </NFormItem>

      <NFormItem :label="t('scriptTemplate.form.channel')" path="channel">
        <NRadioGroup v-model:value="form.channel">
          <NSpace>
            <NRadio
              v-for="option in channelOptions"
              :key="option.value"
              :value="option.value"
            >
              {{ option.label }}
            </NRadio>
          </NSpace>
        </NRadioGroup>
      </NFormItem>

      <NFormItem :label="t('scriptTemplate.form.tone')" path="tone">
        <NRadioGroup v-model:value="form.tone">
          <NSpace>
            <NRadio
              v-for="option in toneOptions"
              :key="option.value"
              :value="option.value"
            >
              {{ option.label }}
            </NRadio>
          </NSpace>
        </NRadioGroup>
      </NFormItem>

      <NFormItem :label="t('scriptTemplate.form.content')" path="content">
        <div class="content-editor">
          <NInput
            ref="contentInputRef"
            v-model:value="form.content"
            type="textarea"
            :rows="10"
            :placeholder="t('scriptTemplate.form.contentPlaceholder')"
          />
          <div class="variables-panel">
            <div class="variables-title">
              {{ t('scriptTemplate.form.variables') }}
              <NTooltip>
                <template #trigger>
                  <NIcon size="14"><InformationCircleOutline /></NIcon>
                </template>
                {{ t('scriptTemplate.form.variablesTip') }}
              </NTooltip>
            </div>
            <div class="variables-list">
              <NTag
                v-for="variable in availableVariables"
                :key="variable.key"
                size="small"
                :bordered="false"
                class="variable-tag"
                @click="insertVariable(variable.key)"
              >
                {{ variable.label }}
              </NTag>
            </div>
          </div>
        </div>
      </NFormItem>

      <NFormItem :label="t('scriptTemplate.form.preview')">
        <div class="preview-content">
          {{ previewContent }}
        </div>
      </NFormItem>
    </NForm>
  </CrmDrawer>
</template>

<script lang="ts" setup>
  import type { FormInst, FormRules } from 'naive-ui';
  import { useMessage } from 'naive-ui';
  import { InformationCircleOutline } from '@vicons/ionicons5';
  import { useI18n } from '@lib/shared/hooks/useI18n';
  import type { ScriptScene, ScriptChannel, ScriptTone } from '@lib/shared/models/ai';

  import CrmDrawer from '@/components/pure/crm-drawer/index.vue';

  const props = defineProps<{
    templateId: string | null;
  }>();

  const emit = defineEmits<{
    (e: 'saved'): void;
  }>();

  const visible = defineModel<boolean>('show', {
    required: true,
  });

  const { t } = useI18n();
  const message = useMessage();

  const formRef = ref<FormInst | null>(null);
  const contentInputRef = ref<any>(null);

  const isEdit = computed(() => !!props.templateId);

  // 表单数据
  const form = ref({
    name: '',
    industry: 'all',
    scene: 'first_contact' as ScriptScene,
    channel: 'phone' as ScriptChannel,
    tone: 'professional' as ScriptTone,
    content: '',
  });

  // 表单验证规则
  const rules: FormRules = {
    name: [
      { required: true, message: t('scriptTemplate.form.namePlaceholder'), trigger: 'blur' },
    ],
    content: [
      { required: true, message: t('scriptTemplate.form.contentPlaceholder'), trigger: 'blur' },
    ],
  };

  // 行业选项
  const industryOptions = computed(() => [
    { label: t('scriptTemplate.industry.all'), value: 'all' },
    { label: t('scriptTemplate.industry.it'), value: 'it' },
    { label: t('scriptTemplate.industry.finance'), value: 'finance' },
    { label: t('scriptTemplate.industry.manufacturing'), value: 'manufacturing' },
    { label: t('scriptTemplate.industry.retail'), value: 'retail' },
    { label: t('scriptTemplate.industry.healthcare'), value: 'healthcare' },
    { label: t('scriptTemplate.industry.education'), value: 'education' },
    { label: t('scriptTemplate.industry.other'), value: 'other' },
  ]);

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

  // 可用变量
  const availableVariables = [
    { key: '{{公司名称}}', label: '公司名称' },
    { key: '{{客户姓名}}', label: '客户姓名' },
    { key: '{{销售姓名}}', label: '销售姓名' },
    { key: '{{产品名称}}', label: '产品名称' },
    { key: '{{联系电话}}', label: '联系电话' },
    { key: '{{邮箱地址}}', label: '邮箱地址' },
    { key: '{{当前日期}}', label: '当前日期' },
  ];

  // 预览内容
  const previewContent = computed(() => {
    let content = form.value.content;
    // 替换变量为示例值
    const sampleValues: Record<string, string> = {
      '{{公司名称}}': 'XX科技有限公司',
      '{{客户姓名}}': '王总',
      '{{销售姓名}}': '小李',
      '{{产品名称}}': 'CRM系统',
      '{{联系电话}}': '138-xxxx-xxxx',
      '{{邮箱地址}}': 'example@company.com',
      '{{当前日期}}': new Date().toLocaleDateString(),
    };
    for (const [key, value] of Object.entries(sampleValues)) {
      content = content.replace(new RegExp(key.replace(/[{}]/g, '\\$&'), 'g'), value);
    }
    return content || '-';
  });

  // 插入变量
  function insertVariable(variable: string) {
    form.value.content += variable;
  }

  // 保存
  async function handleSave() {
    try {
      await formRef.value?.validate();

      // TODO: 调用 API 保存模板
      // if (isEdit.value) {
      //   await updateScriptTemplate({ id: props.templateId, ...form.value });
      // } else {
      //   await createScriptTemplate(form.value);
      // }

      message.success(t('scriptTemplate.saveSuccess'));
      emit('saved');
      visible.value = false;
    } catch (e) {
      console.error('Validation failed:', e);
    }
  }

  // 加载模板数据
  async function loadTemplate() {
    if (!props.templateId) {
      // 重置表单
      form.value = {
        name: '',
        industry: 'all',
        scene: 'first_contact',
        channel: 'phone',
        tone: 'professional',
        content: '',
      };
      return;
    }

    try {
      // TODO: 调用 API 获取模板详情
      // const template = await getScriptTemplate(props.templateId);
      // form.value = { ...template };
    } catch (e) {
      console.error('Failed to load template:', e);
    }
  }

  // 监听显示状态
  watch(visible, (val) => {
    if (val) {
      loadTemplate();
    }
  });
</script>

<style lang="less" scoped>
  .content-editor {
    width: 100%;
  }

  .variables-panel {
    margin-top: 12px;
    padding: 12px;
    background: var(--bg-color);
    border-radius: 8px;
  }

  .variables-title {
    display: flex;
    align-items: center;
    gap: 4px;
    margin-bottom: 8px;
    font-size: 13px;
    color: var(--text-n3);
  }

  .variables-list {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
  }

  .variable-tag {
    cursor: pointer;

    &:hover {
      background: var(--primary-color-hover);
      color: var(--primary-color);
    }
  }

  .preview-content {
    width: 100%;
    min-height: 100px;
    padding: 12px;
    background: var(--bg-color);
    border-radius: 8px;
    white-space: pre-wrap;
    word-break: break-word;
    font-size: 14px;
    line-height: 1.6;
  }
</style>
