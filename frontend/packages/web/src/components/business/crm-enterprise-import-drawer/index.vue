<template>
  <n-drawer v-model:show="showDrawer" :width="520" placement="right">
    <n-drawer-content :title="t('enterprise.import.title')" closable>
      <n-tabs v-model:value="activeTab" type="line" animated>
        <!-- 搜索企业 Tab -->
        <n-tab-pane name="search" :tab="t('enterprise.import.searchTab')">
          <div class="mb-4">
            <n-input
              v-model:value="searchKeyword"
              :placeholder="t('enterprise.import.searchPlaceholder')"
              clearable
              @keyup.enter="handleSearch"
            >
              <template #suffix>
                <n-icon class="cursor-pointer" @click="handleSearch">
                  <SearchOutline />
                </n-icon>
              </template>
            </n-input>
          </div>
          <!-- 搜索结果列表 -->
          <n-spin :show="searching">
            <div v-if="searchResults.length > 0" class="enterprise-list">
              <div v-for="item in searchResults" :key="item.id" class="enterprise-item" @click="selectEnterprise(item)">
                <div class="enterprise-name">{{ item.name }}</div>
                <div class="enterprise-info">
                  <div v-if="item.creditCode">
                    <span class="label">{{ t('enterprise.import.creditCode') }}：</span>
                    {{ item.creditCode }}
                  </div>
                  <div v-if="item.legalPerson">
                    <span class="label">{{ t('enterprise.import.legalPerson') }}：</span>
                    {{ item.legalPerson }}
                  </div>
                  <div v-if="item.address">
                    <span class="label">{{ t('enterprise.import.address') }}：</span>
                    {{ item.address }}
                  </div>
                </div>
              </div>
            </div>
            <n-empty v-else-if="hasSearched && !searching" :description="t('enterprise.import.noResult')" />
          </n-spin>
        </n-tab-pane>
        <!-- 粘贴链接 Tab -->
        <n-tab-pane name="link" :tab="t('enterprise.import.linkTab')">
          <div class="mb-4">
            <n-input
              v-model:value="aiqichaLink"
              type="textarea"
              :rows="3"
              :placeholder="t('enterprise.import.linkPlaceholder')"
            />
          </div>
          <n-button type="primary" :loading="parsing" @click="parseAiqichaLink">
            {{ t('enterprise.import.parseLink') }}
          </n-button>
          <div class="link-hint">
            <p>支持的链接格式：</p>
            <p class="link-example">https://aiqicha.baidu.com/company_detail_xxxxx</p>
          </div>
        </n-tab-pane>
        <!-- 手动填写 Tab -->
        <n-tab-pane name="manual" :tab="t('enterprise.import.manualTab')">
          <n-form ref="formRef" :model="formData" :rules="formRules" label-placement="top">
            <n-form-item :label="t('enterprise.import.name')" path="name">
              <n-input v-model:value="formData.name" :placeholder="t('enterprise.import.required')" />
            </n-form-item>
            <n-form-item :label="t('enterprise.import.creditCode')" path="creditCode">
              <n-input v-model:value="formData.creditCode" />
            </n-form-item>
            <n-form-item :label="t('enterprise.import.legalPerson')" path="legalPerson">
              <n-input v-model:value="formData.legalPerson" />
            </n-form-item>
            <n-form-item :label="t('enterprise.import.address')" path="address">
              <n-input v-model:value="formData.address" />
            </n-form-item>
            <n-form-item :label="t('enterprise.import.industry')" path="industry">
              <n-input v-model:value="formData.industry" />
            </n-form-item>
          </n-form>
        </n-tab-pane>
      </n-tabs>
      <!-- 预览区域 -->
      <div v-if="selectedEnterprise" class="preview-section">
        <div class="preview-header">
          <span class="preview-title">已选择企业</span>
          <n-button text type="error" size="small" @click="clearSelection">清除</n-button>
        </div>
        <n-descriptions :column="1" label-placement="left" size="small">
          <n-descriptions-item :label="t('enterprise.import.name')">
            {{ selectedEnterprise.name }}
          </n-descriptions-item>
          <n-descriptions-item v-if="selectedEnterprise.creditCode" :label="t('enterprise.import.creditCode')">
            {{ selectedEnterprise.creditCode }}
          </n-descriptions-item>
          <n-descriptions-item v-if="selectedEnterprise.legalPerson" :label="t('enterprise.import.legalPerson')">
            {{ selectedEnterprise.legalPerson }}
          </n-descriptions-item>
        </n-descriptions>
        <!-- 导入选项 -->
        <n-divider />
        <n-radio-group v-model:value="importOption" class="mb-3">
          <n-space vertical>
            <n-radio value="create">{{ t('enterprise.import.createCustomer') }}</n-radio>
            <n-radio value="link">{{ t('enterprise.import.linkCustomer') }}</n-radio>
          </n-space>
        </n-radio-group>
      </div>
      <!-- Chrome 扩展提示 -->
      <n-alert type="info" class="mt-4">
        <template #header>{{ t('enterprise.import.chromeExtension') }}</template>
        {{ t('enterprise.import.chromeExtensionTip') }}
      </n-alert>
      <template #footer>
        <div class="footer-actions">
          <n-button @click="showDrawer = false">取消</n-button>
          <n-button type="primary" :loading="importing" :disabled="!canImport" @click="handleImport">
            {{ t('enterprise.import.importAction') }}
          </n-button>
        </div>
      </template>
    </n-drawer-content>
  </n-drawer>
</template>

<script setup lang="ts">
  import { computed, ref, watch } from 'vue';
  import {
    NAlert,
    NButton,
    NDescriptions,
    NDescriptionsItem,
    NDivider,
    NDrawer,
    NDrawerContent,
    NEmpty,
    NForm,
    NFormItem,
    NIcon,
    NInput,
    NRadio,
    NRadioGroup,
    NSpace,
    NSpin,
    NTabPane,
    NTabs,
    useMessage,
  } from 'naive-ui';
  import { SearchOutline } from '@vicons/ionicons5';

  import { useI18n } from '@lib/shared/hooks/useI18n';

  import { searchEnterprise } from '@/api/modules';

  interface EnterpriseItem {
    id: string;
    name: string;
    creditCode?: string;
    legalPerson?: string;
    address?: string;
    industry?: string;
  }

  const { t } = useI18n();

  const Message = useMessage();

  const props = defineProps<{
    show: boolean;
  }>();

  const emit = defineEmits<{
    (e: 'update:show', value: boolean): void;
    (e: 'imported', customerId: string): void;
  }>();

  const showDrawer = computed({
    get: () => props.show,
    set: (val) => emit('update:show', val),
  });

  // Tab 状态
  const activeTab = ref('search');

  // 搜索相关
  const searchKeyword = ref('');
  const searchResults = ref<EnterpriseItem[]>([]);
  const searching = ref(false);
  const hasSearched = ref(false);

  // 链接解析
  const aiqichaLink = ref('');
  const parsing = ref(false);

  // 表单数据
  const formRef = ref(null);
  const formData = ref({
    name: '',
    creditCode: '',
    legalPerson: '',
    address: '',
    industry: '',
  });

  const formRules = {
    name: [{ required: true, message: '请输入企业名称', trigger: 'blur' }],
  };

  // 选中的企业
  const selectedEnterprise = ref<EnterpriseItem | null>(null);

  // 导入选项
  const importOption = ref<'create' | 'link'>('create');

  // 导入状态
  const importing = ref(false);

  const canImport = computed(() => {
    if (activeTab.value === 'manual') {
      return !!formData.value.name;
    }
    return !!selectedEnterprise.value;
  });

  // 重置表单
  function resetForm() {
    searchKeyword.value = '';
    searchResults.value = [];
    hasSearched.value = false;
    aiqichaLink.value = '';
    selectedEnterprise.value = null;
    importOption.value = 'create';
    formData.value = {
      name: '',
      creditCode: '',
      legalPerson: '',
      address: '',
      industry: '',
    };
  }

  // 搜索企业
  async function handleSearch() {
    if (!searchKeyword.value.trim()) return;

    searching.value = true;
    hasSearched.value = true;

    try {
      const result = await searchEnterprise(searchKeyword.value.trim(), 1, 20);

      if (result.success && result.items) {
        searchResults.value = result.items.map((item) => ({
          id: item.pid || item.creditCode || '',
          name: item.name,
          creditCode: item.creditCode,
          legalPerson: item.legalPerson,
          address: item.address,
          industry: item.industry || '',
        }));
      } else {
        searchResults.value = [];
        if (result.message) {
          Message.warning(result.message);
        }
      }
    } catch (error: any) {
      console.error('搜索失败:', error);
      const errorMsg = error?.message || error?.msg || '搜索失败，请检查网络连接';
      Message.error(errorMsg);
      searchResults.value = [];
    } finally {
      searching.value = false;
    }
  }

  // 选择企业
  function selectEnterprise(item: EnterpriseItem) {
    selectedEnterprise.value = item;
  }

  // 清除选择
  function clearSelection() {
    selectedEnterprise.value = null;
  }

  // 解析爱企查链接
  function parseAiqichaLink() {
    if (!aiqichaLink.value.trim()) {
      Message.warning('请输入爱企查链接');
      return;
    }

    const linkPattern = /aiqicha\.baidu\.com\/company_detail_(\d+)/;
    if (!linkPattern.test(aiqichaLink.value)) {
      Message.error('链接格式不正确');
      return;
    }

    parsing.value = true;
    setTimeout(() => {
      selectedEnterprise.value = {
        id: 'parsed-1',
        name: '解析的企业名称',
        creditCode: '91110000MA00ZZZZZ',
        legalPerson: '王五',
        address: '深圳市南山区xxx路xxx号',
        industry: '科技推广和应用服务业',
      };
      parsing.value = false;
      Message.success('链接解析成功');
    }, 800);
  }

  // 导入企业
  function handleImport() {
    importing.value = true;
    setTimeout(() => {
      importing.value = false;
      Message.success(t('enterprise.import.success'));
      emit('imported', 'new-customer-id');
      showDrawer.value = false;
      resetForm();
    }, 1000);
  }

  // 关闭时重置
  watch(showDrawer, (val) => {
    if (!val) {
      resetForm();
    }
  });
</script>

<style scoped lang="less">
  .enterprise-list {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }
  .enterprise-item {
    padding: 12px;
    border: 1px solid #e5e7eb;
    border-radius: 8px;
    cursor: pointer;
    transition: all 0.2s;
    &:hover {
      border-color: var(--primary-color);
      background-color: var(--primary-color-hover);
    }
  }
  .enterprise-name {
    margin-bottom: 4px;
    font-size: 14px;
    font-weight: 500;
  }
  .enterprise-info {
    font-size: 12px;
    color: #6b7280;
    .label {
      color: #9ca3af;
    }
  }
  .link-hint {
    margin-top: 16px;
    font-size: 12px;
    color: #6b7280;
  }
  .link-example {
    margin-top: 4px;
    font-size: 11px;
  }
  .preview-section {
    margin-top: 24px;
    padding: 16px;
    border-radius: 8px;
    background-color: #f9fafb;
  }
  .preview-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 12px;
  }
  .preview-title {
    font-weight: 500;
  }
  .footer-actions {
    display: flex;
    gap: 12px;
    justify-content: flex-end;
  }
</style>
