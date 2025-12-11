<template>
  <div class="script-template-page">
    <div class="page-header">
      <h2>{{ t('scriptTemplate.title') }}</h2>
      <NButton type="primary" @click="handleAdd">
        <template #icon>
          <NIcon><AddOutline /></NIcon>
        </template>
        {{ t('scriptTemplate.add') }}
      </NButton>
    </div>

    <div class="page-content">
      <!-- 左侧分类树 -->
      <div class="category-tree">
        <NTree
          :data="categoryTreeData"
          :default-expanded-keys="['all', 'industry', 'scene']"
          :selected-keys="selectedCategory"
          selectable
          @update:selected-keys="handleCategorySelect"
        />
      </div>

      <!-- 右侧列表 -->
      <div class="template-list">
        <!-- 搜索栏 -->
        <div class="search-bar">
          <NInput
            v-model:value="searchKeyword"
            :placeholder="t('scriptTemplate.search')"
            clearable
            style="width: 300px"
          >
            <template #prefix>
              <NIcon><SearchOutline /></NIcon>
            </template>
          </NInput>
        </div>

        <!-- 数据表格 -->
        <NDataTable
          :columns="columns"
          :data="filteredData"
          :loading="loading"
          :pagination="pagination"
          :row-key="(row: ScriptTemplate) => row.id"
        />
      </div>
    </div>

    <!-- 编辑抽屉 -->
    <ScriptTemplateDrawer v-model:show="showDrawer" :template-id="editingId" @saved="handleSaved" />
  </div>
</template>

<script lang="ts" setup>
  import { h } from 'vue';
  import { useMessage } from 'naive-ui';
  import { AddOutline, SearchOutline } from '@vicons/ionicons5';

  import { useI18n } from '@lib/shared/hooks/useI18n';
  import type { ScriptChannel, ScriptScene, ScriptTemplate, ScriptTone } from '@lib/shared/models/ai';

  import useModal from '@/hooks/useModal';

  import type { DataTableColumns, TreeOption } from 'naive-ui';

  const ScriptTemplateDrawer = defineAsyncComponent(() => import('./components/ScriptTemplateDrawer.vue'));

  const { t } = useI18n();
  const message = useMessage();
  const { openModal } = useModal();

  // 状态
  const loading = ref(false);
  const searchKeyword = ref('');
  const selectedCategory = ref<string[]>(['all']);
  const showDrawer = ref(false);
  const editingId = ref<string | null>(null);

  // 模拟数据
  const templates = ref<ScriptTemplate[]>([
    {
      id: '1',
      name: '首次电话接触-专业版',
      industry: 'it',
      scene: 'first_contact',
      channel: 'phone',
      tone: 'professional',
      content: '您好，我是{{公司名称}}的{{销售姓名}}...',
      isSystem: true,
      enabled: true,
      createdAt: '2024-12-01T10:00:00Z',
    },
    {
      id: '2',
      name: '产品介绍-微信版',
      industry: 'all',
      scene: 'product_intro',
      channel: 'wechat',
      tone: 'enthusiastic',
      content: '您好！我们的产品主要有以下优势...',
      isSystem: false,
      enabled: true,
      createdAt: '2024-12-05T14:30:00Z',
    },
    {
      id: '3',
      name: '邀约会议-邮件版',
      industry: 'finance',
      scene: 'meeting_invite',
      channel: 'email',
      tone: 'professional',
      content: '尊敬的{{客户姓名}}：\n\n感谢您对我们产品的关注...',
      isSystem: false,
      enabled: false,
      createdAt: '2024-12-08T09:15:00Z',
    },
  ]);

  // 分类树数据
  const categoryTreeData = computed<TreeOption[]>(() => [
    {
      key: 'all',
      label: t('scriptTemplate.allCategories'),
    },
    {
      key: 'industry',
      label: t('scriptTemplate.byIndustry'),
      children: [
        { key: 'industry-all', label: t('scriptTemplate.industry.all') },
        { key: 'industry-it', label: t('scriptTemplate.industry.it') },
        { key: 'industry-finance', label: t('scriptTemplate.industry.finance') },
        { key: 'industry-manufacturing', label: t('scriptTemplate.industry.manufacturing') },
        { key: 'industry-retail', label: t('scriptTemplate.industry.retail') },
        { key: 'industry-healthcare', label: t('scriptTemplate.industry.healthcare') },
        { key: 'industry-education', label: t('scriptTemplate.industry.education') },
        { key: 'industry-other', label: t('scriptTemplate.industry.other') },
      ],
    },
    {
      key: 'scene',
      label: t('scriptTemplate.byScene'),
      children: [
        { key: 'scene-first_contact', label: t('aiScript.scene.firstContact') },
        { key: 'scene-product_intro', label: t('aiScript.scene.productIntro') },
        { key: 'scene-meeting_invite', label: t('aiScript.scene.meetingInvite') },
        { key: 'scene-follow_up', label: t('aiScript.scene.followUp') },
      ],
    },
  ]);

  // 获取行业标签
  function getIndustryLabel(industry?: string): string {
    if (!industry) return '-';
    return t(`scriptTemplate.industry.${industry}`);
  }

  // 获取场景标签
  function getSceneLabel(scene: ScriptScene): string {
    const labels: Record<ScriptScene, string> = {
      first_contact: t('aiScript.scene.firstContact'),
      product_intro: t('aiScript.scene.productIntro'),
      meeting_invite: t('aiScript.scene.meetingInvite'),
      follow_up: t('aiScript.scene.followUp'),
    };
    return labels[scene] || scene;
  }

  // 获取渠道标签
  function getChannelLabel(channel: ScriptChannel): string {
    const labels: Record<ScriptChannel, string> = {
      phone: t('aiScript.channel.phone'),
      wechat: t('aiScript.channel.wechat'),
      email: t('aiScript.channel.email'),
    };
    return labels[channel] || channel;
  }

  // 获取语气标签
  function getToneLabel(tone: ScriptTone): string {
    const labels: Record<ScriptTone, string> = {
      professional: t('aiScript.tone.professional'),
      enthusiastic: t('aiScript.tone.enthusiastic'),
      concise: t('aiScript.tone.concise'),
    };
    return labels[tone] || tone;
  }

  // 过滤后的数据
  const filteredData = computed(() => {
    let data = templates.value;

    // 按分类过滤
    const category = selectedCategory.value[0];
    if (category && category !== 'all') {
      if (category.startsWith('industry-')) {
        const industry = category.replace('industry-', '');
        data = data.filter((item) => item.industry === industry);
      } else if (category.startsWith('scene-')) {
        const scene = category.replace('scene-', '');
        data = data.filter((item) => item.scene === scene);
      }
    }

    // 按关键词过滤
    if (searchKeyword.value) {
      const keyword = searchKeyword.value.toLowerCase();
      data = data.filter((item) => item.name.toLowerCase().includes(keyword));
    }

    return data;
  });

  // 分页配置
  const pagination = {
    pageSize: 10,
  };

  // 处理分类选择
  function handleCategorySelect(keys: string[]) {
    selectedCategory.value = keys.length > 0 ? keys : ['all'];
  }

  // 新建模板
  function handleAdd() {
    editingId.value = null;
    showDrawer.value = true;
  }

  // 编辑模板
  function handleEdit(id: string) {
    editingId.value = id;
    showDrawer.value = true;
  }

  // 切换状态
  async function handleToggleStatus(template: ScriptTemplate) {
    // TODO: 调用 API 切换状态
    template.enabled = !template.enabled;
    message.success(template.enabled ? t('scriptTemplate.enableSuccess') : t('scriptTemplate.disableSuccess'));
  }

  // 删除模板
  function handleDelete(id: string) {
    openModal({
      type: 'warning',
      title: t('scriptTemplate.delete'),
      content: t('scriptTemplate.deleteConfirm'),
      positiveText: t('common.confirm'),
      negativeText: t('common.cancel'),
      onPositiveClick: async () => {
        // TODO: 调用 API 删除
        templates.value = templates.value.filter((item) => item.id !== id);
        message.success(t('scriptTemplate.deleteSuccess'));
      },
    });
  }

  // 保存成功回调
  function handleSaved() {
    showDrawer.value = false;
    // TODO: 重新加载数据
  }

  // 加载数据
  async function loadData() {
    loading.value = true;
    try {
      // TODO: 调用 API 获取模板列表
    } finally {
      loading.value = false;
    }
  }

  // 表格列定义
  const columns = computed<DataTableColumns<ScriptTemplate>>(() => [
    {
      title: t('scriptTemplate.table.name'),
      key: 'name',
      width: 200,
    },
    {
      title: t('scriptTemplate.table.industry'),
      key: 'industry',
      width: 100,
      render: (row) => getIndustryLabel(row.industry),
    },
    {
      title: t('scriptTemplate.table.scene'),
      key: 'scene',
      width: 100,
      render: (row) => getSceneLabel(row.scene),
    },
    {
      title: t('scriptTemplate.table.channel'),
      key: 'channel',
      width: 80,
      render: (row) => getChannelLabel(row.channel),
    },
    {
      title: t('scriptTemplate.table.tone'),
      key: 'tone',
      width: 80,
      render: (row) => getToneLabel(row.tone),
    },
    {
      title: t('scriptTemplate.table.status'),
      key: 'enabled',
      width: 100,
      render: (row) =>
        h(
          'span',
          { class: row.enabled ? 'text-success' : 'text-error' },
          row.enabled ? t('scriptTemplate.status.enabled') : t('scriptTemplate.status.disabled')
        ),
    },
    {
      title: t('scriptTemplate.table.createdAt'),
      key: 'createdAt',
      width: 160,
      render: (row) => new Date(row.createdAt).toLocaleString(),
    },
    {
      title: t('scriptTemplate.table.action'),
      key: 'action',
      width: 200,
      render: (row) =>
        h('div', { class: 'action-buttons' }, [
          h('a', { onClick: () => handleEdit(row.id) }, t('common.edit')),
          h('span', { class: 'divider' }, '|'),
          h(
            'a',
            { onClick: () => handleToggleStatus(row) },
            row.enabled ? t('scriptTemplate.disable') : t('scriptTemplate.enable')
          ),
          h('span', { class: 'divider' }, '|'),
          h('a', { class: 'danger', onClick: () => handleDelete(row.id) }, t('scriptTemplate.delete')),
        ]),
    },
  ]);

  onMounted(() => {
    loadData();
  });
</script>

<style lang="less" scoped>
  .script-template-page {
    display: flex;
    padding: 16px;
    height: 100%;
    background: var(--bg-color);
    flex-direction: column;
  }
  .page-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 16px;
    h2 {
      margin: 0;
      font-size: 18px;
      font-weight: 600;
    }
  }
  .page-content {
    flex: 1;
    display: flex;
    gap: 16px;
    overflow: hidden;
  }
  .category-tree {
    overflow-y: auto;
    padding: 16px;
    width: 200px;
    border-radius: 8px;
    background: var(--card-color);
    flex-shrink: 0;
  }
  .template-list {
    display: flex;
    overflow: hidden;
    padding: 16px;
    border-radius: 8px;
    background: var(--card-color);
    flex: 1;
    flex-direction: column;
  }
  .search-bar {
    margin-bottom: 16px;
  }
  .action-buttons {
    display: flex;
    align-items: center;
    gap: 8px;
    a {
      color: var(--primary-color);
      cursor: pointer;
      &:hover {
        text-decoration: underline;
      }
      &.danger {
        color: var(--error-color);
      }
    }
    .divider {
      color: var(--border-color);
    }
  }
  .text-success {
    color: var(--success-color);
  }
  .text-error {
    color: var(--error-color);
  }
</style>
