# Design Document: Flutter QCC Enterprise Search

## Overview

本设计文档描述了在 CordysCRM Flutter 移动应用中集成企查查（qcc.com）企业搜索功能的技术方案。该功能使用 WebView 加载企查查网站，通过 JavaScript 注入提取企业数据，并支持将企业信息导入到 CRM 系统。

### 设计目标

1. **复用现有架构** - 基于现有的爱企查 WebView 实现，最小化代码改动
2. **可配置数据源** - 支持在企查查和爱企查之间切换
3. **稳定可靠** - 使用 WebView 方案避免反爬虫问题
4. **良好的用户体验** - 提供流畅的搜索、提取、导入流程

### 技术方案可行性

WebView 方案是处理企查查等企业信息网站的最佳选择：

1. **完整浏览器环境** - WebView 能完整执行 JavaScript、处理 Cookie、管理会话，在服务器看来与普通手机浏览器访问无异
2. **规避反爬虫** - 将"爬虫"行为转变为"用户辅助的数据复制"，验证码等人机验证由用户自然完成
3. **动态内容支持** - WebView 会执行页面上所有脚本，动态加载的数据都能正确渲染
4. **低风险** - 每个用户操作独立、低频，来自用户设备 IP，与正常用户行为一致

## Architecture

采用 DataSource → Repository → Provider 分层架构，实现数据源的灵活切换：

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Flutter App                                  │
├─────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────────────┐│
│  │                      UI Layer (Widgets)                          ││
│  │  ┌─────────────────┐    ┌─────────────────────────────────────┐ ││
│  │  │ Enterprise      │    │ Enterprise WebView Page             │ ││
│  │  │ Search Page     │───▶│ - 根据数据源加载对应网站            │ ││
│  │  │                 │    │ - 注入 JS 提取数据                  │ ││
│  │  └─────────────────┘    │ - 处理导入按钮点击                  │ ││
│  │                         └─────────────────────────────────────┘ ││
│  └─────────────────────────────────────────────────────────────────┘│
│                                      │                               │
│                                      ▼                               │
│  ┌─────────────────────────────────────────────────────────────────┐│
│  │                    Provider Layer (State)                        ││
│  │  ┌─────────────────────────────────────────────────────────────┐││
│  │  │ enterpriseDataSourceProvider: StateProvider<DataSource>     │││
│  │  │ enterpriseWebProvider: StateNotifierProvider                │││
│  │  │ enterpriseSearchProvider: StateNotifierProvider             │││
│  │  └─────────────────────────────────────────────────────────────┘││
│  └─────────────────────────────────────────────────────────────────┘│
│                                      │                               │
│                                      ▼                               │
│  ┌─────────────────────────────────────────────────────────────────┐│
│  │                    Repository Layer                              ││
│  │  ┌─────────────────────────────────────────────────────────────┐││
│  │  │ EnterpriseRepository                                        │││
│  │  │ - getStartUrl() → 委托给当前 DataSource                     │││
│  │  │ - isDetailPage(url) → 委托给当前 DataSource                 │││
│  │  │ - getExtractJs() → 委托给当前 DataSource                    │││
│  │  │ - importEnterprise() → Backend API                          │││
│  │  └─────────────────────────────────────────────────────────────┘││
│  └─────────────────────────────────────────────────────────────────┘│
│                                      │                               │
│                                      ▼                               │
│  ┌─────────────────────────────────────────────────────────────────┐│
│  │                    DataSource Layer                              ││
│  │  ┌───────────────────────┐    ┌───────────────────────┐         ││
│  │  │ QccDataSource         │    │ AiqichaDataSource     │         ││
│  │  │ - startUrl            │    │ - startUrl            │         ││
│  │  │ - isDetailPage()      │    │ - isDetailPage()      │         ││
│  │  │ - extractJs           │    │ - extractJs           │         ││
│  │  │ - injectButtonJs      │    │ - injectButtonJs      │         ││
│  │  └───────────────────────┘    └───────────────────────┘         ││
│  └─────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         Backend API                                  │
│  POST /api/enterprise/import                                        │
│  GET  /api/enterprise/search-local                                  │
└─────────────────────────────────────────────────────────────────────┘
```

## Components and Interfaces

### 1. Enterprise Data Source Interface

定义统一的数据源接口，所有数据源实现必须遵守此契约：

```dart
/// 企业数据源抽象接口
abstract class EnterpriseDataSourceInterface {
  /// 获取数据源首页 URL
  String get startUrl;
  
  /// 判断 URL 是否为企业详情页
  bool isDetailPage(String url);
  
  /// 判断 URL 是否属于此数据源
  bool isSourceLink(String url);
  
  /// 获取数据提取 JavaScript
  String get extractDataJs;
  
  /// 获取导入按钮注入 JavaScript
  String get injectButtonJs;
  
  /// 数据源标识
  String get sourceId;
}
```

### 2. QCC Data Source Implementation

企查查数据源的具体实现：

```dart
/// 企查查数据源实现
class QccDataSource implements EnterpriseDataSourceInterface {
  @override
  String get startUrl => 'https://www.qcc.com';
  
  @override
  String get sourceId => 'qcc';
  
  @override
  bool isDetailPage(String url) {
    // 企查查详情页 URL 模式: https://www.qcc.com/firm/[hash].html
    return url.contains('qcc.com/firm/') && url.endsWith('.html');
  }
  
  @override
  bool isSourceLink(String url) {
    return url.contains('qcc.com');
  }
  
  @override
  String get extractDataJs => _qccExtractDataJs;
  
  @override
  String get injectButtonJs => _qccInjectButtonJs;
}
```

### 3. Enterprise Data Source Configuration

数据源配置和切换：

```dart
/// 企业数据源类型
enum EnterpriseDataSourceType {
  qcc,      // 企查查
  aiqicha,  // 爱企查
}

/// 数据源配置 Provider
final enterpriseDataSourceTypeProvider = StateProvider<EnterpriseDataSourceType>(
  (ref) => EnterpriseDataSourceType.qcc, // 默认使用企查查
);

/// 当前数据源实例 Provider
final enterpriseDataSourceProvider = Provider<EnterpriseDataSourceInterface>((ref) {
  final type = ref.watch(enterpriseDataSourceTypeProvider);
  return switch (type) {
    EnterpriseDataSourceType.qcc => QccDataSource(),
    EnterpriseDataSourceType.aiqicha => AiqichaDataSource(),
  };
});
```

### 4. URL Pattern Matching Utilities

URL 工具函数，用于检测和分类企业信息链接：

```dart
/// 企查查 URL 模式
/// - 首页: https://www.qcc.com/
/// - 搜索页: https://www.qcc.com/search?key=关键词
/// - 企业详情页: https://www.qcc.com/firm/[hash].html

/// 检测是否为企查查企业详情页
bool isQccDetailPage(String url) {
  if (url.isEmpty) return false;
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  return uri.host.contains('qcc.com') && 
         uri.path.startsWith('/firm/') && 
         uri.path.endsWith('.html');
}

/// 检测是否为企查查链接
bool isQccLink(String url) {
  if (url.isEmpty) return false;
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  return uri.host.contains('qcc.com');
}

/// 检测是否为爱企查企业详情页
bool isAiqichaDetailPage(String url) {
  if (url.isEmpty) return false;
  return url.contains('aiqicha') && 
         (url.contains('company_detail') || url.contains('pid='));
}

/// 检测是否为爱企查链接
bool isAiqichaLink(String url) {
  if (url.isEmpty) return false;
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  return uri.host.contains('aiqicha');
}

/// 根据 URL 自动检测数据源类型
EnterpriseDataSourceType? detectDataSourceFromUrl(String url) {
  if (isQccLink(url)) return EnterpriseDataSourceType.qcc;
  if (isAiqichaLink(url)) return EnterpriseDataSourceType.aiqicha;
  return null;
}
```

### 5. JavaScript Injection for Data Extraction

#### 数据提取策略

**核心原则**：不依赖固定的 CSS class 或 id（这些会随网站更新而变化），而是通过搜索固定的文本标签（如"统一社会信用代码"）来定位元素，然后基于相对 DOM 位置获取数据。

企查查页面的数据提取 JavaScript：

```javascript
const _qccExtractDataJs = '''
window.__extractEnterpriseData = function() {
  // 通用文本获取函数
  const getText = (selectors) => {
    for (const sel of selectors.split(',')) {
      const el = document.querySelector(sel.trim());
      if (el && el.textContent.trim()) {
        return el.textContent.trim();
      }
    }
    return '';
  };
  
  // 基于标签文本的相对定位提取（更稳定）
  const getTextByLabel = (labels) => {
    const labelList = Array.isArray(labels) ? labels : [labels];
    
    // 遍历所有可能包含数据的容器元素
    const containers = document.querySelectorAll('table tr, .info-item, .detail-item, .data-row, div[class*="item"], dl');
    
    for (const container of containers) {
      const text = container.textContent || '';
      
      for (const label of labelList) {
        if (text.includes(label)) {
          // 策略1: 查找 td 的下一个兄弟 td
          const tds = container.querySelectorAll('td');
          if (tds.length >= 2) {
            for (let i = 0; i < tds.length - 1; i++) {
              if (tds[i].textContent.includes(label)) {
                return tds[i + 1].textContent.trim();
              }
            }
          }
          
          // 策略2: 查找带有 value 类的元素
          const valueEl = container.querySelector('.value, .data-value, dd, span:last-child');
          if (valueEl && !valueEl.textContent.includes(label)) {
            return valueEl.textContent.trim();
          }
          
          // 策略3: 使用 nextElementSibling
          const labelEl = Array.from(container.querySelectorAll('*')).find(
            el => el.textContent.trim() === label
          );
          if (labelEl && labelEl.nextElementSibling) {
            return labelEl.nextElementSibling.textContent.trim();
          }
        }
      }
    }
    return '';
  };
  
  // 从 URL 提取企业 ID
  const urlMatch = location.href.match(/\\/firm\\/([^.]+)\\.html/);
  const id = urlMatch ? urlMatch[1] : '';
  
  // 提取企业名称（通常在 h1 标签中）
  const name = getText('h1.title, h1.name, .company-name, .firm-name, h1') || 
               document.title.replace(/-.*$/, '').trim();
  
  return {
    id: id,
    name: name,
    creditCode: getTextByLabel(['统一社会信用代码', '信用代码']),
    legalPerson: getTextByLabel(['法定代表人', '法人']),
    registeredCapital: getTextByLabel(['注册资本']),
    establishDate: getTextByLabel(['成立日期', '成立时间']),
    status: getTextByLabel(['经营状态', '状态']),
    address: getTextByLabel(['注册地址', '地址']),
    industry: getTextByLabel(['所属行业', '行业']),
    businessScope: getTextByLabel(['经营范围']),
    phone: getTextByLabel(['电话', '联系电话']),
    email: getTextByLabel(['邮箱', '电子邮箱']),
    website: getTextByLabel(['官网', '网址']),
    source: 'qcc'
  };
};
''';
```

#### 导入按钮注入 JavaScript

```javascript
const _qccInjectButtonJs = '''
(function() {
  // 防止重复注入
  if (document.getElementById('__crm_import_btn')) return;
  
  // 创建浮动按钮
  const btn = document.createElement('button');
  btn.id = '__crm_import_btn';
  btn.innerHTML = '📥 导入CRM';
  
  // 样式设置
  Object.assign(btn.style, {
    position: 'fixed',
    right: '16px',
    bottom: '80px',
    zIndex: '99999',
    padding: '12px 20px',
    background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
    color: '#fff',
    border: 'none',
    borderRadius: '24px',
    fontSize: '14px',
    fontWeight: '600',
    boxShadow: '0 4px 15px rgba(102, 126, 234, 0.4)',
    cursor: 'pointer',
    transition: 'transform 0.2s, box-shadow 0.2s',
  });
  
  // 悬停效果
  btn.onmouseenter = () => {
    btn.style.transform = 'scale(1.05)';
    btn.style.boxShadow = '0 6px 20px rgba(102, 126, 234, 0.5)';
  };
  btn.onmouseleave = () => {
    btn.style.transform = 'scale(1)';
    btn.style.boxShadow = '0 4px 15px rgba(102, 126, 234, 0.4)';
  };
  
  // 点击事件
  btn.onclick = () => {
    try {
      const data = window.__extractEnterpriseData();
      window.flutter_inappwebview.callHandler('onEnterpriseData', JSON.stringify(data));
    } catch (e) {
      window.flutter_inappwebview.callHandler('onError', e.toString());
    }
  };
  
  document.body.appendChild(btn);
})();
''';
```

## Data Models

### Enterprise Entity (已存在)

```dart
class Enterprise {
  final String id;
  final String name;
  final String creditCode;
  final String legalPerson;
  final String registeredCapital;
  final String establishDate;
  final String status;
  final String address;
  final String industry;
  final String businessScope;
  final String phone;
  final String email;
  final String website;
  final String source; // 'local', 'qcc', 'iqicha'
}
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: QCC Detail Page URL Detection

*For any* URL string, the `isQccDetailPage` function should return true if and only if the URL:
1. Contains a host with "qcc.com"
2. Has a path starting with "/firm/"
3. Has a path ending with ".html"

**Validates: Requirements 1.4, 4.2**

### Property 2: QCC Link Detection

*For any* URL string, the `isQccLink` function should return true if and only if the URL contains a host with "qcc.com".

**Validates: Requirements 4.1**

### Property 3: Aiqicha Detail Page URL Detection

*For any* URL string, the `isAiqichaDetailPage` function should return true if and only if the URL contains "aiqicha" and either "company_detail" or "pid=".

**Validates: Requirements 5.3**

### Property 4: Aiqicha Link Detection

*For any* URL string, the `isAiqichaLink` function should return true if and only if the URL contains a host with "aiqicha".

**Validates: Requirements 5.3**

### Property 5: Data Source Auto Detection

*For any* URL string that is either a QCC link or an Aiqicha link, the `detectDataSourceFromUrl` function should return the correct data source type. For URLs that are neither, it should return null.

**Validates: Requirements 4.1, 4.2**

### Property 6: Data Source Configuration Consistency

*For any* data source type configuration, the `enterpriseDataSourceProvider` should return a data source instance whose `startUrl` matches the expected URL (qcc.com for QCC, aiqicha.baidu.com for Aiqicha).

**Validates: Requirements 5.2, 5.3, 5.4**

### Property 7: URL Detection Mutual Exclusivity

*For any* URL string, `isQccLink` and `isAiqichaLink` should not both return true (a URL cannot belong to both data sources).

**Validates: Requirements 5.2, 5.3**

### Property 8: Detail Page Implies Source Link

*For any* URL string, if `isQccDetailPage` returns true, then `isQccLink` must also return true. Similarly, if `isAiqichaDetailPage` returns true, then `isAiqichaLink` must also return true.

**Validates: Requirements 1.4, 4.2**

## Error Handling

### WebView Errors

1. **页面加载失败** - 显示错误提示，提供重试按钮
2. **JavaScript 执行失败** - 显示提取失败提示，建议用户手动复制信息
3. **网络错误** - 显示网络错误提示，检查网络连接

### Import Errors

1. **认证失败 (401)** - 提示用户重新登录 CRM
2. **数据冲突 (409)** - 显示冲突解决对话框，允许覆盖或取消
3. **服务器错误 (5xx)** - 显示服务器错误提示，建议稍后重试

## Testing Strategy

### Unit Tests

1. **URL 模式匹配测试** - 测试 `isQccDetailPage`、`isQccLink`、`isAiqichaDetailPage`、`isAiqichaLink` 函数
2. **数据源配置测试** - 测试数据源切换逻辑
3. **数据源自动检测测试** - 测试 `detectDataSourceFromUrl` 函数

### Property-Based Tests

使用 `glados` 库进行属性测试，每个属性测试运行至少 100 次迭代：

1. **Property 1 测试** - 生成随机 URL，验证 QCC 详情页检测逻辑
   - 生成器：生成包含 qcc.com/firm/*.html 模式的 URL 和随机 URL
   - 验证：isQccDetailPage 返回值与 URL 模式匹配

2. **Property 2 测试** - 生成随机 URL，验证 QCC 链接检测逻辑
   - 生成器：生成包含 qcc.com 的 URL 和不包含的 URL
   - 验证：isQccLink 返回值与 URL 内容匹配

3. **Property 3 测试** - 生成随机 URL，验证爱企查详情页检测逻辑
   - 生成器：生成包含 aiqicha 和 company_detail/pid= 的 URL
   - 验证：isAiqichaDetailPage 返回值与 URL 模式匹配

4. **Property 4 测试** - 生成随机 URL，验证爱企查链接检测逻辑
   - 生成器：生成包含 aiqicha 的 URL 和不包含的 URL
   - 验证：isAiqichaLink 返回值与 URL 内容匹配

5. **Property 5 测试** - 生成随机 URL，验证数据源自动检测
   - 生成器：生成 QCC URL、爱企查 URL 和其他 URL
   - 验证：detectDataSourceFromUrl 返回正确的数据源类型或 null

6. **Property 6 测试** - 生成随机数据源配置，验证 WebView URL 一致性
   - 生成器：生成 EnterpriseDataSourceType 枚举值
   - 验证：对应的 DataSource 实例的 startUrl 正确

7. **Property 7 测试** - 生成随机 URL，验证互斥性
   - 生成器：生成各种 URL
   - 验证：isQccLink 和 isAiqichaLink 不会同时返回 true

8. **Property 8 测试** - 生成随机 URL，验证详情页蕴含源链接
   - 生成器：生成各种 URL
   - 验证：详情页检测为 true 时，源链接检测也为 true

### Integration Tests

1. **WebView 加载测试** - 验证 WebView 能正确加载企查查网站
2. **数据提取测试** - 验证 JavaScript 注入和数据提取流程
3. **导入流程测试** - 验证完整的提取-预览-导入流程
4. **分享链接测试** - 验证从外部应用分享链接的处理流程
