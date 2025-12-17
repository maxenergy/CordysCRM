import '../../core/utils/enterprise_url_utils.dart';
import '../../domain/datasources/enterprise_data_source.dart';

/// 企查查（qcc.com）数据源实现
///
/// 提供企查查网站的 URL 检测和 JavaScript 注入逻辑。
/// 企查查页面结构变化较快，采用"按字段 label 扫描"的通用提取方式。
class QccDataSource extends EnterpriseDataSourceInterface {
  const QccDataSource();

  @override
  String get sourceId => 'qcc';

  @override
  String get displayName => '企查查';

  @override
  String get startUrl => 'https://www.qcc.com';

  @override
  bool isSourceLink(String url) => isQccLink(url);

  @override
  bool isDetailPage(String url) => isQccDetailPage(url);

  @override
  String get extractDataJs => _extractDataJs;

  @override
  String get injectButtonJs => _injectButtonJs;

  @override
  String? get searchJs => _searchJs;


  /// 导入按钮注入脚本
  ///
  /// 创建浮动按钮，点击时调用数据提取函数并通过 Flutter 回调传递数据。
  /// 使用蓝色渐变样式，与爱企查的紫色渐变区分。
  static const _injectButtonJs = '''
(function() {
  // 防止重复注入
  if (document.getElementById('__crm_import_btn')) return;
  
  // 创建浮动按钮
  const btn = document.createElement('button');
  btn.id = '__crm_import_btn';
  btn.innerHTML = '📥 导入CRM';
  
  // 样式设置（蓝色渐变，区分爱企查的紫色）
  Object.assign(btn.style, {
    position: 'fixed',
    right: '16px',
    bottom: '80px',
    zIndex: '99999',
    padding: '12px 20px',
    background: 'linear-gradient(135deg, #0ea5e9 0%, #2563eb 100%)',
    color: '#fff',
    border: 'none',
    borderRadius: '24px',
    fontSize: '14px',
    fontWeight: '600',
    boxShadow: '0 4px 15px rgba(37, 99, 235, 0.35)',
    cursor: 'pointer',
    transition: 'transform 0.2s, box-shadow 0.2s',
  });
  
  // 悬停效果
  btn.onmouseenter = () => {
    btn.style.transform = 'scale(1.05)';
    btn.style.boxShadow = '0 6px 20px rgba(37, 99, 235, 0.45)';
  };
  btn.onmouseleave = () => {
    btn.style.transform = 'scale(1)';
    btn.style.boxShadow = '0 4px 15px rgba(37, 99, 235, 0.35)';
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

  /// 数据提取脚本
  ///
  /// 使用"按字段 label 扫描"策略，提高对 DOM 结构变化的适应性。
  /// 优先通过文本标签定位元素，然后基于相对 DOM 位置获取数据。
  static const _extractDataJs = '''
window.__extractEnterpriseData = function() {
  // 文本规范化：去除多余空白
  const norm = (s) => (s || '').replace(/\\s+/g, ' ').trim();

  // 通过选择器获取文本
  const getText = (sel) => {
    const el = document.querySelector(sel);
    return el ? norm(el.textContent) : '';
  };
  
  // 通过标签文本定位并获取对应值
  const getTextByLabel = (label) => {
    // 扫描常见的信息容器元素
    const items = document.querySelectorAll(
      'tr, .info-item, .detail-item, .company-info, .content, .basic, .base, .keyInfo, .key-info, table, dl'
    );
    
    for (const item of items) {
      const text = norm(item.textContent);
      if (!text || !text.includes(label)) continue;
      
      // 策略1：表格结构 - label 在 td:first-child，值在 td:last-child
      const tds = item.querySelectorAll('td');
      if (tds.length >= 2) {
        for (let i = 0; i < tds.length - 1; i++) {
          if (norm(tds[i].textContent).includes(label)) {
            return norm(tds[i + 1].textContent);
          }
        }
      }
      
      // 策略2：键值结构 - 查找 .value 或最后一个子元素
      const value = item.querySelector('.value, .val, dd, span:last-child, div:last-child');
      if (value && !norm(value.textContent).includes(label)) {
        return norm(value.textContent);
      }
    }
    return '';
  };

  // 从 URL 提取企业 ID
  const firmMatch = location.href.match(/\\/firm\\/([^/?#.]+)\\.html/i);
  const companyMatch = location.href.match(/\\/company\\/([^/?#.]+)\\.html/i);
  const id = firmMatch ? firmMatch[1] : (companyMatch ? companyMatch[1] : '');
  
  // 提取企业名称（通常在 h1 标签中）
  const name = getText('h1') || getText('.title') || getText('.company-name') || 
               document.title.replace(/-.*\$/, '').trim();
  
  return {
    id: id,
    name: name,
    creditCode: getTextByLabel('统一社会信用代码') || getTextByLabel('信用代码'),
    legalPerson: getTextByLabel('法定代表人') || getTextByLabel('法人') || getTextByLabel('法人代表'),
    registeredCapital: getTextByLabel('注册资本'),
    establishDate: getTextByLabel('成立日期') || getTextByLabel('成立时间'),
    status: getTextByLabel('经营状态') || getTextByLabel('登记状态') || getTextByLabel('状态'),
    address: getTextByLabel('注册地址') || getTextByLabel('地址'),
    industry: getTextByLabel('所属行业') || getTextByLabel('行业'),
    businessScope: getTextByLabel('经营范围'),
    phone: getTextByLabel('电话') || getTextByLabel('联系电话'),
    email: getTextByLabel('邮箱') || getTextByLabel('电子邮箱'),
    website: getTextByLabel('官网') || getTextByLabel('网址'),
    source: 'qcc'
  };
};
''';

  /// 搜索执行和结果抓取脚本
  ///
  /// 在企查查页面执行搜索并抓取结果列表。
  /// 采用多选择器 + 启发式策略，提高健壮性。
  /// 支持 requestId 参数用于并发请求关联，避免竞态条件。
  /// 总超时 12s（留 3s 余量给 Dart 侧 15s 超时）。
  static const _searchJs = '''
window.__searchQcc = function(keyword, requestId) {
  // ========== 工具函数 ==========
  const sleep = (ms) => new Promise(r => setTimeout(r, ms));
  
  const isVisible = (el) => {
    if (!el) return false;
    const style = window.getComputedStyle(el);
    if (style.display === 'none' || style.visibility === 'hidden' || style.opacity === '0') return false;
    const rect = el.getBoundingClientRect();
    return rect.width > 0 && rect.height > 0;
  };
  
  // React/Vue 受控输入：使用原生 setter + 触发事件
  const setNativeValue = (input, value) => {
    if (!input) return;
    const proto = Object.getPrototypeOf(input);
    const desc = Object.getOwnPropertyDescriptor(proto, 'value') ||
                 Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value');
    if (desc && desc.set) desc.set.call(input, value);
    else input.value = value;
    input.dispatchEvent(new Event('input', { bubbles: true }));
    input.dispatchEvent(new Event('change', { bubbles: true }));
  };
  
  const textOf = (el) => (el && (el.innerText || el.value || el.textContent) 
    ? String(el.innerText || el.value || el.textContent).trim() : '');
  
  // ========== 搜索框查找（多选择器 + 启发式） ==========
  const findSearchInput = () => {
    const selectors = [
      '#searchkey',
      'input[name="key"]',
      'input[name="searchkey"]',
      'input[name*="key" i]',
      'input[id*="search" i]',
      'input[type="search"]',
      'input[placeholder*="查"]',
      'input[placeholder*="企业"]',
      'input[placeholder*="公司"]',
      'input[placeholder*="老板"]',
      '.search-input input',
      '.header-search input',
      'header input[type="text"]',
    ];
    for (const sel of selectors) {
      try {
        const el = document.querySelector(sel);
        if (el && el.tagName === 'INPUT' && !el.disabled && isVisible(el)) return el;
      } catch (_) {}
    }
    // 启发式：扫描所有可见 input
    const inputs = Array.from(document.querySelectorAll('input'))
      .filter(i => i && !i.disabled && i.type !== 'hidden' && isVisible(i));
    return inputs.find(i => /查|企业|公司|统一社会信用代码|老板/.test(i.placeholder || '')) ||
           inputs.find(i => /key|search/i.test(i.name || '') || /key|search/i.test(i.id || '')) ||
           null;
  };
  
  // ========== 搜索按钮查找（多选择器 + 启发式） ==========
  const findSearchSubmit = () => {
    const selectors = [
      'button.search-btn',
      '.search-btn',
      'button[type="submit"]',
      'form button[type="submit"]',
      'input[type="submit"]',
      '.header-search button',
      'header button',
    ];
    for (const sel of selectors) {
      try {
        const el = document.querySelector(sel);
        if (el && isVisible(el) && !el.disabled) return el;
      } catch (_) {}
    }
    // 启发式：查找包含搜索相关文字的按钮
    const candidates = Array.from(document.querySelectorAll('button,a,input[type="button"],input[type="submit"]'))
      .filter(el => isVisible(el) && !el.disabled);
    return candidates.find(el => /查一下|搜索|查询|查企业|查公司|查老板|查风险/.test(textOf(el))) || null;
  };
  
  // ========== 风控/验证页检测 ==========
  const isRiskOrBlockPage = () => {
    const href = String(location.href || '');
    const bodyText = document.body ? (document.body.innerText || '') : '';
    return /overseaApply|verify|captcha/i.test(href) || 
           bodyText.includes('海外产品使用') || 
           bodyText.includes('访问受限') || 
           bodyText.includes('安全验证') ||
           bodyText.includes('请完成验证');
  };
  
  // ========== 检测是否已在搜索结果页 ==========
  const isSearchResultPage = () => {
    const href = String(location.href || '');
    return /\\/web\\/search|search\\?|search\\//.test(href);
  };
  
  // ========== 结果抓取（多选择器策略） ==========
  const scrapeResults = () => {
    // 多种可能的结果容器选择器（从精确到宽泛）
    const containerSelectors = [
      '#search-result .firm-list-item',
      '.search-result .firm-list-item',
      '.result-list .firm-list-item',
      '.search-list .list-item',
      '.company-list .company-item',
      '.m-search-list .list-item',
      '.search-result-list .item',
    ];
    
    let items = [];
    for (const sel of containerSelectors) {
      try {
        items = document.querySelectorAll(sel);
        if (items.length > 0) break;
      } catch (_) {}
    }
    
    const results = [];
    items.forEach(item => {
      // 多种可能的标题链接选择器
      const a = item.querySelector('a.title, a.name, .title a, .name a, h3 a, h2 a');
      const name = a ? a.innerText.trim() : '';
      const url = a ? a.href : '';
      
      // 从 URL 提取企业 ID
      const firmMatch = url.match(/\\/firm\\/([^/?#.]+)\\.html/i);
      const companyMatch = url.match(/\\/company\\/([^/?#.]+)\\.html/i);
      const id = firmMatch ? firmMatch[1] : (companyMatch ? companyMatch[1] : '');

      // 字段选择器（收窄范围，避免抓到脏数据）
      const legalPerson = item.querySelector('.legal-person a, .legal-person, .fr a')?.innerText.trim() || '';
      const status = item.querySelector('.status-tip, .status, .tag')?.innerText.trim() || '';
      const creditCode = item.querySelector('.credit-code, .code')?.innerText.trim() || '';
      const registeredCapital = item.querySelector('.capital, .reg-capital')?.innerText.trim() || '';
      const establishDate = item.querySelector('.date, .establish-date')?.innerText.trim() || '';

      if (name && id) {
        results.push({
          id: id,
          name: name,
          legalPerson: legalPerson,
          status: status,
          creditCode: creditCode,
          registeredCapital: registeredCapital,
          establishDate: establishDate,
          url: url,
          source: 'qcc'
        });
      }
    });
    return results;
  };

  // ========== 主逻辑 ==========
  // 资源管理（提前声明，确保全路径可 cleanup）
  let resultFound = false;
  let timeoutId = null;
  let observer = null;
  
  const cleanup = () => {
    try {
      if (timeoutId !== null) { clearTimeout(timeoutId); timeoutId = null; }
      if (observer) { observer.disconnect(); observer = null; }
    } catch (e) {}
  };
  
  return new Promise(async (resolve, reject) => {
    // 总超时 12s（一开始就启动，留 3s 余量给 Dart 侧 15s 超时）
    timeoutId = setTimeout(() => {
      if (!resultFound) {
        cleanup();
        const finalResults = scrapeResults();
        if (finalResults.length > 0) {
          resolve(finalResults);
        } else {
          reject('企查查搜索超时，请检查页面是否正常加载或刷新后重试');
        }
      }
    }, 12000);
    
    try {
      // 检查是否在 qcc.com 域名下
      if (!/(^|\\.)qcc\\.com\$/i.test(location.hostname)) {
        cleanup();
        reject('当前不在企查查域名下，请先打开企查查页面');
        return;
      }
      
      // 检查关键词
      if (!keyword || !String(keyword).trim()) {
        cleanup();
        reject('搜索关键词为空');
        return;
      }
      
      // 检查风控页
      if (isRiskOrBlockPage()) {
        cleanup();
        reject('企查查需要验证，请在页面上完成验证后重试');
        return;
      }
      
      // 如果已在搜索结果页，先尝试抓取现有结果
      if (isSearchResultPage()) {
        const existingResults = scrapeResults();
        if (existingResults.length > 0) {
          cleanup();
          resolve(existingResults);
          return;
        }
      }
      
      // 查找搜索框（同步查找，不再 await 等待）
      const input = findSearchInput();
      const button = findSearchSubmit();
      
      if (!input) {
        // 找不到搜索框，提示用户手动操作（不自动跳转，避免 Dart 侧报错）
        cleanup();
        reject('未找到搜索框，请确保在企查查首页或搜索页，然后重试');
        return;
      }
      
      // 填充搜索框并触发搜索
      setNativeValue(input, keyword);
      input.focus();
      
      // 尝试 Enter 键提交
      input.dispatchEvent(new KeyboardEvent('keydown', { bubbles: true, key: 'Enter', code: 'Enter', keyCode: 13, which: 13 }));
      input.dispatchEvent(new KeyboardEvent('keyup', { bubbles: true, key: 'Enter', code: 'Enter', keyCode: 13, which: 13 }));
      
      // 尝试点击按钮
      if (button) button.click();
      else if (input.form) input.form.submit();
      
      // 设置 MutationObserver 监听结果（带节流）
      let lastScrapeTime = 0;
      const observerOptions = { childList: true, subtree: true };
      
      observer = new MutationObserver(() => {
        const now = Date.now();
        if (now - lastScrapeTime < 200) return; // 200ms 节流
        lastScrapeTime = now;
        
        const currentResults = scrapeResults();
        if (currentResults.length > 0) {
          resultFound = true;
          cleanup();
          resolve(currentResults);
        }
      });
      
      // 等待一小段时间让页面开始响应
      await sleep(300);
      
      // 查找结果容器并监听
      const container = document.getElementById('search-result') || 
                        document.querySelector('.search-result') ||
                        document.querySelector('.result-list') ||
                        document.body;
      observer.observe(container, observerOptions);
      
    } catch (e) {
      cleanup();
      reject('搜索出错: ' + String(e));
    }
  })
  .then(results => {
    window.flutter_inappwebview.callHandler('onQichachaSearchResult', requestId, JSON.stringify(results));
  })
  .catch(error => {
    const errorMsg = (error && error.toString) ? error.toString() : String(error);
    window.flutter_inappwebview.callHandler('onQichachaSearchError', requestId, errorMsg);
  });
};
''';
}
