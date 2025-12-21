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
  static const _injectButtonJs = '''
(function() {
  if (document.getElementById('__crm_import_btn')) return;
  
  const btn = document.createElement('button');
  btn.id = '__crm_import_btn';
  btn.innerHTML = '📥 导入CRM';
  
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
  
  btn.onmouseenter = () => {
    btn.style.transform = 'scale(1.05)';
    btn.style.boxShadow = '0 6px 20px rgba(37, 99, 235, 0.45)';
  };
  btn.onmouseleave = () => {
    btn.style.transform = 'scale(1)';
    btn.style.boxShadow = '0 4px 15px rgba(37, 99, 235, 0.35)';
  };
  
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
  /// 核心改进：
  /// 1. findValueByLabel - 按标签文本查找相邻值，解决"提取到标签本身"的问题
  /// 2. 支持多联系人提取（返回 contactsJSON）
  /// 3. 增强的调试日志
  static const _extractDataJs = r'''
window.__extractEnterpriseData = function() {
  // ========== 调试日志 ==========
  const debug = (...args) => {
    try {
      window.flutter_inappwebview.callHandler('onQccDebug', '[详情提取] ' + args.map(a => 
        typeof a === 'object' ? JSON.stringify(a) : String(a)
      ).join(' '));
    } catch (_) {
      console.log('[详情提取]', ...args);
    }
  };

  // ========== 工具函数 ==========
  const norm = (s) => (s || '').replace(/\s+/g, ' ').trim();
  
  const clean = (s) => {
    if (!s) return '';
    return s
      .replace(/复制/g, '')
      .replace(/关联企业\s*\d*/g, '')
      .replace(/附近企业/g, '')
      .replace(/更多\s*\d*/g, '')
      .replace(/邮编\d+/g, '')
      .replace(/（仅限办公）/g, '')
      .replace(/\(仅限办公\)/g, '')
      .replace(/查看更多/g, '')
      .replace(/查看地图/g, '')
      .replace(/附近公司/g, '')
      .replace(/展开/g, '')
      .replace(/收起/g, '')
      .replace(/详情/g, '')
      .replace(/\s+/g, ' ')
      .trim();
  };
  
  const normalizeLabel = (s) => norm(s).replace(/[：:]/g, '');
  
  // 检查值是否有意义
  const isMeaningful = (v, labels) => {
    if (!v) return false;
    const trimmed = v.trim();
    if (!trimmed) return false;
    const invalidValues = ['—', '-', '暂无', '无', '/', '未公开', '未知', '查看', '详情', '查看地图', '附近公司'];
    if (invalidValues.includes(trimmed)) return false;
    if (/^\d{1,2}$/.test(trimmed)) return false;
    // 过滤值与标签完全相同的情况（不是包含关系）
    if (labels) {
      const labelList = Array.isArray(labels) ? labels : [labels];
      const normalizedValue = normalizeLabel(trimmed);
      // 只排除完全相同或以标签开头后面只有冒号的情况
      if (labelList.some(l => {
        const normalizedLabel = normalizeLabel(l);
        return normalizedValue === normalizedLabel || 
               normalizedValue === normalizedLabel + '：' ||
               normalizedValue === normalizedLabel + ':';
      })) {
        return false;
      }
    }
    return true;
  };

  // 从元素中提取文本值
  const extractValueFromEl = (el) => {
    if (!el) return '';
    const copyValueEl = el.querySelector('.copy-value, [data-clipboard-text]');
    if (copyValueEl) {
      const clipText = copyValueEl.getAttribute('data-clipboard-text');
      if (clipText) return norm(clipText);
      return norm(copyValueEl.textContent);
    }
    if (el.tagName === 'A' && el.hasAttribute('href')) {
      const href = el.getAttribute('href') || '';
      if (href.startsWith('mailto:')) return href.replace('mailto:', '');
      if (href.startsWith('tel:')) return href.replace('tel:', '');
    }
    return clean(el.textContent);
  };

  // ========== 核心函数：按标签文本查找对应的值 ==========
  const findValueByLabel = (labels, rootSelector) => {
    const labelList = Array.isArray(labels) ? labels : [labels];
    debug('查找标签:', labelList.join('/'));
    
    // 确定搜索范围（优先在基本信息区域搜索）
    const root = rootSelector 
      ? document.querySelector(rootSelector) 
      : document.querySelector('.cominfo-normal, .basic-info, .company-info, .ntable') || document;
    
    // 策略0：检查同节点"标签：值"格式
    const checkInlineValue = (el) => {
      const text = el.textContent || '';
      for (const label of labelList) {
        const re = new RegExp(label + '[：:]\\s*(.+)', 'i');
        const match = text.match(re);
        if (match && match[1]) {
          const value = clean(match[1].split(/[\n\r]/)[0]);
          if (isMeaningful(value, labelList)) {
            debug('同节点冒号策略找到', label, '=', value);
            return value;
          }
        }
      }
      return null;
    };
    
    // 策略1：查找 ntable 中的 td.tb 标签单元格（企查查特有结构）
    const ntable = root.querySelector('.ntable, table.cominfo-normal, .cominfo-normal table, .basic-info table') || root.querySelector('table');
    if (ntable) {
      const rows = ntable.querySelectorAll('tr');
      for (const row of rows) {
        const cells = row.querySelectorAll('td');
        for (let i = 0; i < cells.length; i++) {
          const cell = cells[i];
          const cellText = norm(cell.textContent);
          const isLabelCell = cell.classList.contains('tb') || cellText.length < 20;
          
          if (isLabelCell && labelList.some(l => cellText.includes(l))) {
            // 先检查同节点格式
            const inlineValue = checkInlineValue(cell);
            if (inlineValue) return inlineValue;
            
            const nextCell = cells[i + 1];
            if (nextCell && !nextCell.classList.contains('tb')) {
              const value = extractValueFromEl(nextCell);
              if (isMeaningful(value, labelList)) {
                debug('ntable策略找到', cellText, '=', value);
                return value;
              }
            }
          }
        }
      }
    }
    
    // 策略2：遍历所有可能的标签元素
    const selectors = 'td, th, dt, div, span, label';
    const elements = root.querySelectorAll(selectors);
    
    for (const el of elements) {
      const text = el.textContent || '';
      const hasDirectText = Array.from(el.childNodes).some(n => n.nodeType === 3 && norm(n.textContent));
      if (!hasDirectText && el.children.length > 2) continue;
      
      const normalizedText = normalizeLabel(text);
      if (normalizedText.length > 30) continue;
      
      if (labelList.some(label => normalizedText.includes(normalizeLabel(label)))) {
        // 先检查同节点格式
        const inlineValue = checkInlineValue(el);
        if (inlineValue) return inlineValue;
        
        // 策略2a: 下一个兄弟元素
        let nextEl = el.nextElementSibling;
        if (nextEl) {
          const value = extractValueFromEl(nextEl);
          if (isMeaningful(value, labelList)) {
            debug('兄弟节点策略找到', text, '=', value);
            return value;
          }
        }
        
        // 策略2b: 父行中的值元素
        const parentRow = el.closest('tr, .row, .ant-descriptions-row, .detail-item, .info-row, dl');
        if (parentRow && parentRow !== el) {
          const cells = parentRow.querySelectorAll('td, dd, .value, .val, .item-value');
          for (const cell of cells) {
            if (cell === el || cell.contains(el)) continue;
            const value = extractValueFromEl(cell);
            if (isMeaningful(value, labelList)) {
              debug('父行策略找到', text, '=', value);
              return value;
            }
          }
        }
      }
    }
    
    // 策略3：如果在限定范围内没找到，扩展到全局搜索
    if (root !== document) {
      debug('在限定范围内未找到，扩展到全局搜索');
      return findValueByLabel(labels, null);
    }
    
    debug('未找到', labelList.join('/'), '的值');
    return '';
  };

  const getText = (sel) => {
    const el = document.querySelector(sel);
    return el ? clean(norm(el.textContent)) : '';
  };

  // ========== 特定字段提取函数 ==========
  
  const extractCreditCode = () => {
    debug('开始提取统一社会信用代码');
    const codeEl = document.querySelector('.copy-value[data-clipboard-text], .creditCode, [class*="credit"]');
    if (codeEl) {
      const code = codeEl.getAttribute('data-clipboard-text') || codeEl.textContent;
      const match = (code || '').match(/([0-9A-Z]{18})/);
      if (match) {
        debug('信用代码选择器找到:', match[1]);
        return match[1];
      }
    }
    const raw = findValueByLabel(['统一社会信用代码', '信用代码', '社会信用代码']);
    if (raw) {
      const match = raw.match(/([0-9A-Z]{18})/);
      if (match) return match[1];
    }
    const text = document.body.innerText || '';
    const match = text.match(/([0-9A-Z]{18})/);
    return match ? match[1] : '';
  };
  
  const extractLegalPerson = () => {
    debug('开始提取法定代表人');
    const lpLink = document.querySelector('a[href*="/pl/"], a[href*="/people/"], .legal-person a, .legalPerson');
    if (lpLink) {
      const name = clean(norm(lpLink.textContent)).split(/\s/)[0];
      if (name && name.length >= 2 && name.length <= 10) {
        debug('法人链接找到:', name);
        return name;
      }
    }
    const raw = findValueByLabel(['法定代表人', '法人', '法人代表', '负责人']);
    if (raw) {
      const name = raw.split(/\s/)[0].replace(/[,，]/g, '').substring(0, 20);
      debug('法人标签找到:', name);
      return name;
    }
    return '';
  };
  
  const extractDate = () => {
    debug('开始提取成立日期');
    const raw = findValueByLabel(['成立日期', '成立时间', '注册日期', '成立']);
    const match = raw.match(/(\d{4}[-/年]\d{1,2}[-/月]\d{1,2}日?)/);
    const result = match ? match[1].replace(/年/g, '-').replace(/月/g, '-').replace(/日/g, '') : raw;
    debug('成立日期:', result);
    return result;
  };
  
  const extractStatus = () => {
    debug('开始提取经营状态');
    const statusEl = document.querySelector('.tag, .status, .state, [class*="status"]');
    if (statusEl) {
      const text = norm(statusEl.textContent);
      const match = text.match(/(存续|在业|在营|开业|在册|注销|吊销|迁出|清算|停业)/);
      if (match) return match[1];
    }
    const raw = findValueByLabel(['经营状态', '登记状态', '企业状态', '状态']);
    const match = raw.match(/(存续|在业|在营|开业|在册|注销|吊销|迁出|清算|停业)/);
    return match ? match[1] : raw;
  };
  
  const extractAddress = () => {
    debug('开始提取注册地址');
    const raw = findValueByLabel(['注册地址', '企业地址', '住所', '经营地址', '地址']);
    return raw.replace(/（邮编.*?）/g, '').replace(/\(邮编.*?\)/g, '').trim();
  };
  
  const extractIndustry = () => {
    debug('开始提取所属行业');
    const industryLink = document.querySelector('a[href*="/industry/"], a[href*="/hangye/"], .industry a');
    if (industryLink) {
      const industry = clean(norm(industryLink.textContent));
      if (industry && industry.length >= 2 && industry.length <= 50) {
        debug('行业链接找到:', industry);
        return industry;
      }
    }
    return findValueByLabel(['所属行业', '行业', '行业分类', '行业类别']);
  };
  
  const extractPhone = () => {
    debug('开始提取联系电话');
    const phones = new Set();
    const phonePattern = /(1[3-9]\d{9}|0\d{2,3}-?\d{7,8}|\d{3,4}-\d{7,8})/g;
    
    const addPhone = (p) => {
      if (!p) return;
      const phone = p.replace(/\s+/g, '');
      if (phone.length < 7) return;
      const digitCount = (phone.match(/\d/g) || []).length;
      if (digitCount < 7) return;
      phones.add(phone);
    };
    
    const collectPhonesFromText = (text) => {
      if (!text) return;
      const matches = text.match(phonePattern);
      if (matches) matches.forEach(addPhone);
    };
    
    document.querySelectorAll('a[href^="tel:"]').forEach(el => {
      const href = el.getAttribute('href');
      if (href) addPhone(href.replace('tel:', ''));
    });
    
    document.querySelectorAll('.phone, .tel, [class*="phone"]:not([class*="smartphone"])').forEach(el => {
      collectPhonesFromText(norm(el.textContent));
    });
    
    const contactSection = document.querySelector('.contact, .contact-info, [class*="contact"]');
    if (contactSection) collectPhonesFromText(contactSection.textContent || '');
    
    if (phones.size === 0) {
      collectPhonesFromText(findValueByLabel(['电话', '联系电话', '联系方式', '手机']));
    }
    
    return Array.from(phones).join(', ');
  };
  
  const extractEmail = () => {
    debug('开始提取电子邮箱');
    const emails = new Set();
    const emailPattern = /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g;
    
    const collectEmailsFromText = (text) => {
      if (!text) return;
      const matches = text.match(emailPattern);
      if (matches) matches.forEach(e => emails.add(e.trim().toLowerCase()));
    };
    
    document.querySelectorAll('a[href^="mailto:"]').forEach(el => {
      const href = el.getAttribute('href');
      const email = href ? href.replace('mailto:', '') : '';
      if (email) emails.add(email.trim().toLowerCase());
    });
    
    const contactSection = document.querySelector('.contact, .contact-info, [class*="contact"]');
    if (contactSection) collectEmailsFromText(contactSection.textContent || '');
    
    if (emails.size === 0) {
      collectEmailsFromText(findValueByLabel(['邮箱', '电子邮箱', 'Email', '联系邮箱']));
    }
    
    return Array.from(emails).join(', ');
  };
  
  const extractWebsite = () => {
    debug('开始提取官网');
    const isValidUrl = (url) => {
      if (!url) return false;
      const lower = url.toLowerCase();
      if (lower.startsWith('mailto:') || lower.startsWith('tel:') || lower.startsWith('javascript:')) return false;
      return lower.startsWith('http://') || lower.startsWith('https://') || /^(www\.)?[a-zA-Z0-9-]+\.[a-zA-Z]{2,}/.test(url);
    };
    
    const raw = findValueByLabel(['官网', '网址', '企业官网', '网站']);
    if (raw && isValidUrl(raw)) {
      return raw.startsWith('http') ? raw : 'http://' + raw;
    }
    
    const websiteLinks = document.querySelectorAll('a[href*="http"]:not([href*="qcc.com"]):not([href*="baidu.com"])');
    for (const link of websiteLinks) {
      const text = norm(link.textContent);
      const href = link.getAttribute('href') || '';
      if (!isValidUrl(href)) continue;
      if (text.includes('官网') || text.includes('网站') || text.includes('官方')) return href;
      if (/^(www\.)?[a-zA-Z0-9-]+\.[a-zA-Z]{2,}/.test(text)) {
        return text.startsWith('http') ? text : 'http://' + text;
      }
    }
    return '';
  };
  
  // 提取联系人信息（支持多联系人）
  const extractContacts = () => {
    debug('开始提取联系人');
    const contacts = [];
    const addedContacts = new Set();
    
    const itemSelectors = '.contact-item, .person-item, [class*="contact"] li, .key-person, .partner-item, .staff-item';
    document.querySelectorAll(itemSelectors).forEach(item => {
      const nameEl = item.querySelector('.name, .person-name, .contact-name, .partner-name, a[href*="/pl/"]');
      const phoneEl = item.querySelector('.phone, .tel, a[href^="tel:"]');
      const positionEl = item.querySelector('.position, .title, .job, .partner-title');
      
      const name = nameEl ? norm(nameEl.textContent).split(/\s/)[0] : '';
      const phoneHref = phoneEl ? phoneEl.getAttribute('href') : null;
      const phone = phoneEl ? norm(phoneHref ? phoneHref.replace('tel:', '') : phoneEl.textContent) : '';
      const position = positionEl ? norm(positionEl.textContent) : '';
      
      if (name || phone) {
        const key = name + '|' + phone + '|' + position;
        if (!addedContacts.has(key)) {
          contacts.push({ name, phone, position });
          addedContacts.add(key);
          debug('添加联系人:', { name, phone, position });
        }
      }
    });
    
    debug('提取到联系人数量:', contacts.length);
    return contacts;
  };

  // ========== 主提取逻辑 ==========
  const firmMatch = location.href.match(/\/firm\/([^/?#.]+)\.html/i);
  const companyMatch = location.href.match(/\/company\/([^/?#.]+)\.html/i);
  const id = firmMatch ? firmMatch[1] : (companyMatch ? companyMatch[1] : '');
  
  const name = getText('h1') || getText('.title') || getText('.company-name') || 
               document.title.replace(/-.*$/, '').trim();
  
  debug('========== 开始提取企业详情 ==========');
  debug('企业名称:', name);
  debug('企业ID:', id);
  debug('当前URL:', location.href);
  
  // 打印页面关键区域的 HTML 结构（用于调试）
  const basicInfoSection = document.querySelector('.cominfo-normal, .basic-info, .company-info, table');
  if (basicInfoSection) {
    debug('基本信息区域HTML(前500字符):', basicInfoSection.outerHTML.substring(0, 500));
  }
  
  const contacts = extractContacts();
  
  const result = {
    id: id,
    name: name,
    creditCode: extractCreditCode(),
    legalPerson: extractLegalPerson(),
    registeredCapital: findValueByLabel(['注册资本', '注册资金']),
    establishDate: extractDate(),
    status: extractStatus(),
    address: extractAddress(),
    industry: extractIndustry(),
    businessScope: findValueByLabel(['经营范围', '业务范围']),
    phone: extractPhone(),
    email: extractEmail(),
    website: extractWebsite(),
    contactsJSON: JSON.stringify(contacts),
    source: 'qcc'
  };
  
  debug('========== 提取结果汇总 ==========');
  debug('统一社会信用代码:', result.creditCode);
  debug('法定代表人:', result.legalPerson);
  debug('注册资本:', result.registeredCapital);
  debug('成立日期:', result.establishDate);
  debug('经营状态:', result.status);
  debug('注册地址:', result.address);
  debug('所属行业:', result.industry);
  debug('联系电话:', result.phone);
  debug('电子邮箱:', result.email);
  debug('官网:', result.website);
  debug('联系人:', result.contactsJSON);
  debug('========== 提取完成 ==========');
  
  return result;
};
''';


  /// 搜索执行和结果抓取脚本
  static const _searchJs = r'''
window.__searchQcc = function(keyword, requestId) {
  const sleep = (ms) => new Promise(r => setTimeout(r, ms));
  
  const debug = (...args) => {
    try {
      window.flutter_inappwebview.callHandler('onQccDebug', args.map(a => 
        typeof a === 'object' ? JSON.stringify(a) : String(a)
      ).join(' '));
    } catch (_) {}
  };

  const isRiskOrBlockPage = () => {
    const href = String(location.href || '');
    const bodyText = document.body ? (document.body.innerText || '') : '';
    return /overseaApply|verify|captcha/i.test(href) || 
           bodyText.includes('海外产品使用') || 
           bodyText.includes('访问受限') || 
           bodyText.includes('安全验证') ||
           bodyText.includes('请完成验证');
  };

  const isSearchResultPage = () => {
    const href = String(location.href || '');
    return /\/web\/search|search\?key=/.test(href);
  };

  const scrapeResults = () => {
    debug(' 开始抓取搜索结果');
    
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
    let matchedSelector = '';
    for (const sel of containerSelectors) {
      try {
        const found = document.querySelectorAll(sel);
        if (found.length > 0) {
          items = found;
          matchedSelector = sel;
          debug(' 匹配选择器:', sel, '元素数:', found.length);
          break;
        }
      } catch (_) {}
    }
    
    if (items.length === 0) {
      debug(' 标准选择器未匹配，尝试宽泛选择器');
      const links = document.querySelectorAll('a[href*="/firm/"], a[href*="/company/"]');
      debug(' 找到企业链接数:', links.length);
      const containers = new Set();
      links.forEach((link, linkIdx) => {
        let parent = link.parentElement;
        for (let i = 0; i < 10 && parent; i++) {
          const text = parent.innerText || '';
          if (text.includes('法定代表人') || text.includes('注册资本') || text.includes('成立日期')) {
            containers.add(parent);
            break;
          }
          if (parent.children.length > 3 && text.length > 100) {
            containers.add(parent);
            break;
          }
          parent = parent.parentElement;
        }
      });
      items = Array.from(containers);
      matchedSelector = 'fallback-parent-search';
    }
    
    debug(' 最终元素数:', items.length, '选择器:', matchedSelector);
    
    const results = [];
    items.forEach((item, idx) => {
      const a = item.querySelector('a[href*="/firm/"], a[href*="/company/"]') ||
                item.querySelector('a.title, a.name, .title a, .name a, h3 a, h2 a');
      if (!a) return;
      
      const name = (a.innerText || a.textContent || '').trim();
      const url = a.href || '';
      
      const firmMatch = url.match(/\/firm\/([^/?#.]+)/i);
      const companyMatch = url.match(/\/company\/([^/?#.]+)/i);
      const id = firmMatch ? firmMatch[1] : (companyMatch ? companyMatch[1] : '');
      
      if (!name || !id) return;

      const text = (item.innerText || item.textContent || '');
      
      let legalPerson = '';
      const lpMatch = text.match(/(?:法定代表人|法人|法人代表)[\s]*[:：]?[\s]*([\s\S]*?)(?=[\s]*(?:注册资本|成立日期|经营状态|统一社会信用代码|所属行业|注册地址|电话|邮箱)|$)/);
      if (lpMatch && lpMatch[1]) {
        legalPerson = lpMatch[1].trim().split(/[\s\n\r]/)[0].replace(/[,，]/g, '').substring(0, 20);
      }
      
      let status = '';
      const statusMatch = text.match(/(存续|在业|注销|吊销|迁出|清算|开业|停业)/);
      if (statusMatch) status = statusMatch[1];
      
      let registeredCapital = '';
      const capMatch = text.match(/(?:注册资本|注册资金)[\s]*[:：]?[\s]*([\s\S]*?)(?=[\s]*(?:法定代表人|成立日期|经营状态|统一社会信用代码|所属行业|注册地址|电话|邮箱)|$)/);
      if (capMatch && capMatch[1]) {
        const capValue = capMatch[1].match(/([\d,.]+[\s]*万?[人民币元美元欧元港币]*)/);
        if (capValue) registeredCapital = capValue[1].replace(/[\s]/g, '');
      }
      
      let establishDate = '';
      const dateMatch = text.match(/(?:成立日期|成立时间|成立)[\s]*[:：]?[\s]*([\s\S]*?)(?=[\s]*(?:法定代表人|注册资本|经营状态|统一社会信用代码|所属行业|注册地址|电话|邮箱)|$)/);
      if (dateMatch && dateMatch[1]) {
        const d = dateMatch[1].match(/(\d{4}[-/年]\d{1,2}[-/月]\d{1,2}日?)/);
        if (d) establishDate = d[1];
      }
      
      let creditCode = '';
      const ccMatch = text.match(/([0-9A-Z]{18})/);
      if (ccMatch) creditCode = ccMatch[1];

      results.push({
        id: id,
        name: name,
        legalPerson: legalPerson,
        status: status,
        creditCode: creditCode,
        registeredCapital: registeredCapital,
        establishDate: establishDate,
        url: url,
        source: 'qcc',
        address: '',
        industry: '',
        businessScope: '',
        phone: '',
        email: '',
        website: ''
      });
    });
    
    debug(' 抓取完成，结果数:', results.length);
    return results;
  };

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

  try {
    if (!/(^|\.)qcc\.com$/i.test(location.hostname)) {
      replyErr('当前不在企查查域名下，请先打开企查查页面');
      return;
    }

    if (!keyword || !String(keyword).trim()) {
      replyErr('搜索关键词为空');
      return;
    }

    if (isRiskOrBlockPage()) {
      replyErr('企查查需要验证，请在页面上完成验证后重试');
      return;
    }

    if (!isSearchResultPage()) {
      const targetUrl = 'https://www.qcc.com/web/search?key=' + encodeURIComponent(keyword);
      replyOk({ needNavigate: true, targetUrl: targetUrl });
      return;
    }

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
