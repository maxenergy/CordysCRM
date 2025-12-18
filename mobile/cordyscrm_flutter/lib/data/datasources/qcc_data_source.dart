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
  /// 采用"结果页抓取 + Dart 侧导航"策略：
  /// - JS 只负责判断页面状态 + 抓取结果
  /// - 如不在搜索结果页，则返回 needNavigate 让 Dart 调用 loadUrl() 跳转
  /// 支持 requestId 参数用于并发请求关联，避免竞态条件。
  static const _searchJs = '''
window.__searchQcc = function(keyword, requestId) {
  // ========== 工具函数 ==========
  const sleep = (ms) => new Promise(r => setTimeout(r, ms));

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
    return /\\/web\\/search|search\\?key=/.test(href);
  };

  // ========== 结果抓取（多选择器策略） ==========
  const scrapeResults = () => {
    // 多种可能的结果容器选择器（从精确到宽泛）
    const containerSelectors = [
      '#search-result .result-list > div',
      '#searchlist .result-list > div',
      '.search-result .result-list > div',
      '.result-list .list-item',
      '.search-list .list-item',
      '.company-list .company-item',
      '[class*="result"] [class*="item"]',
    ];
    
    let items = [];
    for (const sel of containerSelectors) {
      try {
        const found = document.querySelectorAll(sel);
        if (found.length > 0) {
          items = found;
          break;
        }
      } catch (_) {}
    }
    
    // 如果没找到，尝试更宽泛的选择器
    if (items.length === 0) {
      const links = document.querySelectorAll('a[href*="/firm/"], a[href*="/company/"]');
      const containers = new Set();
      links.forEach(link => {
        let parent = link.parentElement;
        for (let i = 0; i < 5 && parent; i++) {
          if (parent.children.length > 1) {
            containers.add(parent);
            break;
          }
          parent = parent.parentElement;
        }
      });
      items = Array.from(containers);
    }
    
    const results = [];
    items.forEach(item => {
      const a = item.querySelector('a[href*="/firm/"], a[href*="/company/"]') ||
                item.querySelector('a.title, a.name, .title a, .name a, h3 a, h2 a');
      if (!a) return;
      
      const name = (a.innerText || a.textContent || '').trim();
      const url = a.href || '';
      
      const firmMatch = url.match(/\\/firm\\/([^/?#.]+)/i);
      const companyMatch = url.match(/\\/company\\/([^/?#.]+)/i);
      const id = firmMatch ? firmMatch[1] : (companyMatch ? companyMatch[1] : '');
      
      if (!name || !id) return;

      const text = (item.innerText || item.textContent || '');
      
      let legalPerson = '';
      const lpMatch = text.match(/法(?:定代表)?人[：:](\\S+)/);
      if (lpMatch) legalPerson = lpMatch[1].replace(/[\\s\\n]/g, '');
      
      let status = '';
      const statusMatch = text.match(/(存续|在业|注销|吊销|迁出|清算)/);
      if (statusMatch) status = statusMatch[1];
      
      let registeredCapital = '';
      const capMatch = text.match(/注册资本[：:]?([\\d.]+万?[人民币元美元欧元港币]*)/);
      if (capMatch) registeredCapital = capMatch[1];
      
      let establishDate = '';
      const dateMatch = text.match(/成立[日时]?期?[：:]?(\\d{4}[-/年]\\d{1,2}[-/月]\\d{1,2}日?)/);
      if (dateMatch) establishDate = dateMatch[1];

      results.push({
        id: id,
        name: name,
        legalPerson: legalPerson,
        status: status,
        creditCode: '',
        registeredCapital: registeredCapital,
        establishDate: establishDate,
        url: url,
        source: 'qcc'
      });
    });
    return results;
  };

  // ========== 回调函数 ==========
  const replyOk = (payload) => {
    window.flutter_inappwebview.callHandler(
      'onQichachaSearchResult',
      requestId,
      JSON.stringify(payload)
    );
  };

  const replyErr = (error) => {
    const errorMsg = (error && error.toString) ? error.toString() : String(error);
    window.flutter_inappwebview.callHandler('onQichachaSearchError', requestId, errorMsg);
  };

  // ========== 主逻辑 ==========
  try {
    // 检查是否在 qcc.com 域名下
    if (!/(^|\\.)qcc\\.com\$/i.test(location.hostname)) {
      replyErr('当前不在企查查域名下，请先打开企查查页面');
      return;
    }

    // 检查关键词
    if (!keyword || !String(keyword).trim()) {
      replyErr('搜索关键词为空');
      return;
    }

    // 检查风控页
    if (isRiskOrBlockPage()) {
      replyErr('企查查需要验证，请在页面上完成验证后重试');
      return;
    }

    // 不在搜索结果页：交给 Dart 侧导航（避免 JS 上下文销毁）
    if (!isSearchResultPage()) {
      const targetUrl =
        'https://www.qcc.com/web/search?key=' + encodeURIComponent(keyword);
      replyOk({ needNavigate: true, targetUrl: targetUrl });
      return;
    }

    // 已在搜索结果页：轮询抓取结果
    const startedAt = Date.now();
    const maxMs = 12000;
    const poll = async () => {
      while (Date.now() - startedAt < maxMs) {
        const results = scrapeResults();
        if (results && results.length > 0) {
          replyOk(results);
          return;
        }
        await sleep(150);
      }
      replyErr('企查查搜索超时，请检查页面是否正常加载或刷新后重试');
    };

    poll().catch(replyErr);
  } catch (e) {
    replyErr('搜索出错: ' + String(e));
  }
};
''';
}
