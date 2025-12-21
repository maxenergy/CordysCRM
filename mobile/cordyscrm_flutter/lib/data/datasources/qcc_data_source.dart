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
  /// 使用多策略提取方式，提高对 DOM 结构变化的适应性：
  /// 1. 优先使用企查查特定的 CSS 选择器
  /// 2. 回退到通用的标签文本定位（精确匹配，避免字段错位）
  /// 3. 支持多联系人提取（用逗号分隔）
  static const _extractDataJs = '''
window.__extractEnterpriseData = function() {
  // 调试日志
  const debug = (...args) => {
    try {
      window.flutter_inappwebview.callHandler('onQccDebug', '[详情提取] ' + args.map(a => 
        typeof a === 'object' ? JSON.stringify(a) : String(a)
      ).join(' '));
    } catch (_) {
      console.log('[详情提取]', ...args);
    }
  };

  // 文本规范化：去除多余空白
  const norm = (s) => (s || '').replace(/\\s+/g, ' ').trim();
  
  // 清理多余文本
  const clean = (s) => {
    if (!s) return '';
    return s
      .replace(/复制/g, '')
      .replace(/关联企业\\s*\\d*/g, '')
      .replace(/附近企业/g, '')
      .replace(/更多\\s*\\d*/g, '')
      .replace(/邮编\\d+/g, '')
      .replace(/（仅限办公）/g, '')
      .replace(/\\(仅限办公\\)/g, '')
      .replace(/查看更多/g, '')
      .replace(/展开/g, '')
      .replace(/收起/g, '')
      .replace(/\\s+/g, ' ')
      .trim();
  };
  
  // 正则转义
  const escapeRegExp = (s) => { if (!s) return ''; return s.replace(/[.*+?^\${}()|[\\]\\\\]/g, function(m) { return '\\\\' + m; }); };
  
  // 标签规范化：去除冒号
  const normalizeLabel = (s) => norm(s).replace(/[：:]/g, '');
  
  // 检查值是否有意义（非空、非占位符）
  const isMeaningful = (v) => {
    if (!v) return false;
    const trimmed = v.trim();
    if (!trimmed) return false;
    // 过滤无效值
    if (['—', '-', '暂无', '无', '/', '未公开', '未知'].includes(trimmed)) return false;
    // 过滤纯数字且长度小于3的值（避免匹配到 "2" 这样的无效数字）
    if (/^\\d{1,2}\$/.test(trimmed)) return false;
    return true;
  };

  // 通过选择器获取文本
  const getText = (sel) => {
    const el = document.querySelector(sel);
    return el ? clean(norm(el.textContent)) : '';
  };
  
  // ========== 企查查特定选择器策略 ==========
  // 企查查详情页通常使用 table 结构或 div.detail-list 结构
  
  // 策略1：查找包含特定标签的 tr 或 div，然后获取相邻的值（支持多标签）
  const getValueByLabelInTable = (labels) => {
    const labelList = Array.isArray(labels) ? labels : [labels];
    const labelSet = labelList.map(normalizeLabel);
    
    // 查找所有表格行
    const rows = document.querySelectorAll('tr, .detail-item, .info-row, .cominfo-row, .info-line');
    for (const row of rows) {
      const cells = row.querySelectorAll('td, th, .label, .value, .td, span');
      for (let i = 0; i < cells.length; i++) {
        const cellText = norm(cells[i].textContent);
        const normalized = normalizeLabel(cellText);
        
        // 处理 "标签：值" 格式（内联）
        for (const label of labelList) {
          const re = new RegExp('^' + escapeRegExp(label) + '\\\\s*[:：]\\\\s*(.+)\$');
          const inline = cellText.match(re);
          if (inline && inline[1]) {
            const value = clean(inline[1]);
            if (isMeaningful(value)) {
              debug('冒号分隔策略找到', label, '=', value);
              return value;
            }
          }
        }
        
        // 精确标签匹配，取相邻单元格
        if (labelSet.includes(normalized) && cells[i + 1]) {
          const value = clean(norm(cells[i + 1].textContent));
          if (isMeaningful(value)) {
            debug('表格策略找到', cellText, '=', value);
            return value;
          }
        }
      }
    }
    return '';
  };
  
  // 策略2：通过 class 名称查找特定字段
  const getValueByClass = (classPatterns) => {
    for (const pattern of classPatterns) {
      const el = document.querySelector(pattern);
      if (el) {
        const value = clean(norm(el.textContent));
        if (isMeaningful(value)) {
          debug('Class策略找到', pattern, '=', value);
          return value;
        }
      }
    }
    return '';
  };
  
  // 策略3：通用标签扫描（改进版 - 精确匹配，支持多标签）
  const getTextByLabel = (labelOrLabels) => {
    const labels = Array.isArray(labelOrLabels) ? labelOrLabels : [labelOrLabels];
    const labelSet = labels.map(normalizeLabel);
    const isLabelMatch = (text) => labelSet.includes(normalizeLabel(text));
    
    // 从元素中提取值（支持链接 href）
    const extractValueFromEl = (el) => {
      if (!el) return '';
      
      // 首先检查元素本身是否是链接
      if (el.tagName === 'A' && el.hasAttribute('href')) {
        const href = el.getAttribute('href') || '';
        if (href.startsWith('mailto:')) return href.replace('mailto:', '');
        if (href.startsWith('tel:')) return href.replace('tel:', '');
        if (href.startsWith('http') && !href.includes('qcc.com')) return href;
      }
      
      // 然后检查子元素中的链接
      const link = el.querySelector('a[href]');
      if (link) {
        const href = link.getAttribute('href') || '';
        if (href.startsWith('mailto:')) return href.replace('mailto:', '');
        if (href.startsWith('tel:')) return href.replace('tel:', '');
        if (href.startsWith('http') && !href.includes('qcc.com')) return href;
      }
      return clean(norm(el.textContent));
    };
    
    // 先尝试表格策略
    const tableValue = getValueByLabelInTable(labels);
    if (tableValue) return tableValue;
    
    // 精确 label 节点扫描
    const labelSelectors = 'th, dt, .label, .item-label, .info-title, .info-name, .tit, .title, .name, .td-label';
    const labelNodes = document.querySelectorAll(labelSelectors);
    
    for (const node of labelNodes) {
      const text = norm(node.textContent);
      if (!text || text.length > 30) continue;
      
      // 处理 "标签：值" 内联格式
      for (const l of labels) {
        const re = new RegExp('^' + escapeRegExp(l) + '\\\\s*[:：]\\\\s*(.+)\$');
        const inline = text.match(re);
        if (inline && inline[1]) {
          const value = clean(inline[1]);
          if (isMeaningful(value)) {
            debug('内联策略找到', l, '=', value);
            return value;
          }
        }
      }
      
      if (!isLabelMatch(text)) continue;
      
      // 优先取相邻节点
      let value = extractValueFromEl(node.nextElementSibling);
      if (isMeaningful(value) && !isLabelMatch(value)) {
        debug('相邻节点策略找到', text, '=', value);
        return value;
      }
      
      // 次选：同一行（tr/dl）内的下一个单元格
      const row = node.closest('tr, dl, .info-row, .detail-item');
      if (row) {
        const cells = row.querySelectorAll('td, th, dd, dt, .value, .label');
        const cellArray = Array.from(cells);
        const nodeIndex = cellArray.findIndex(c => c === node || c.contains(node));
        if (nodeIndex >= 0 && nodeIndex < cellArray.length - 1) {
          // 取下一个单元格
          const nextCell = cellArray[nodeIndex + 1];
          value = extractValueFromEl(nextCell);
          if (isMeaningful(value) && !isLabelMatch(value)) {
            debug('同行下一单元格策略找到', text, '=', value);
            return value;
          }
        }
      }
      
      // 最后：同一父容器内的 value/dd（限制在小范围内）
      const parent = node.parentElement;
      if (parent && parent.children.length <= 5) {
        const valueEl = parent.querySelector('.value, .val, dd, .copy-value, .item-value');
        value = extractValueFromEl(valueEl);
        if (isMeaningful(value) && !isLabelMatch(value)) {
          debug('父容器策略找到', text, '=', value);
          return value;
        }
      }
    }
    return '';
  };
  
  // ========== 特定字段提取函数 ==========
  
  // 提取统一社会信用代码
  const extractCreditCode = () => {
    debug('开始提取统一社会信用代码');
    
    // 方法1：查找特定选择器
    const codeEl = document.querySelector('.copy-value[data-clipboard-text], .creditCode, [class*="credit"]');
    if (codeEl) {
      const code = codeEl.getAttribute('data-clipboard-text') || codeEl.textContent;
      const match = (code || '').match(/([0-9A-Z]{18})/);
      if (match) {
        debug('信用代码选择器找到:', match[1]);
        return match[1];
      }
    }
    
    // 方法2：通用标签查找
    const raw = getTextByLabel(['统一社会信用代码', '信用代码', '社会信用代码']);
    if (raw) {
      const match = raw.match(/([0-9A-Z]{18})/);
      if (match) {
        debug('信用代码标签找到:', match[1]);
        return match[1];
      }
    }
    
    // 方法3：从页面文本中提取（最后手段）
    const text = document.body.innerText || '';
    const match = text.match(/([0-9A-Z]{18})/);
    if (match) {
      debug('信用代码全文找到:', match[1]);
      return match[1];
    }
    
    debug('未找到统一社会信用代码');
    return '';
  };
  
  // 提取法定代表人
  const extractLegalPerson = () => {
    debug('开始提取法定代表人');
    
    // 方法1：查找特定链接
    const lpLink = document.querySelector('a[href*="/pl/"], a[href*="/people/"], .legal-person a, .legalPerson');
    if (lpLink) {
      const name = clean(norm(lpLink.textContent)).split(/\\s/)[0];
      if (name && name.length >= 2 && name.length <= 10) {
        debug('法人链接找到:', name);
        return name;
      }
    }
    
    // 方法2：通用标签查找（支持多标签）
    const raw = getTextByLabel(['法定代表人', '法人', '法人代表', '负责人']);
    if (raw) {
      const name = raw.split(/\\s/)[0].replace(/[,，]/g, '').substring(0, 20);
      debug('法人标签找到:', name);
      return name;
    }
    
    debug('未找到法定代表人');
    return '';
  };
  
  // 提取成立日期
  const extractDate = () => {
    debug('开始提取成立日期');
    const raw = getTextByLabel(['成立日期', '成立时间', '注册日期', '成立']);
    const match = raw.match(/(\\d{4}[-/年]\\d{1,2}[-/月]\\d{1,2}日?)/);
    const result = match ? match[1].replace(/年/g, '-').replace(/月/g, '-').replace(/日/g, '') : raw;
    debug('成立日期:', result);
    return result;
  };
  
  // 提取经营状态
  const extractStatus = () => {
    debug('开始提取经营状态');
    
    // 方法1：查找状态标签
    const statusEl = document.querySelector('.tag, .status, .state, [class*="status"]');
    if (statusEl) {
      const text = norm(statusEl.textContent);
      const match = text.match(/(存续|在业|在营|开业|在册|注销|吊销|迁出|清算|停业)/);
      if (match) {
        debug('状态标签找到:', match[1]);
        return match[1];
      }
    }
    
    // 方法2：通用查找
    const raw = getTextByLabel(['经营状态', '登记状态', '企业状态', '状态']);
    const match = raw.match(/(存续|在业|在营|开业|在册|注销|吊销|迁出|清算|停业)/);
    const result = match ? match[1] : raw;
    debug('经营状态:', result);
    return result;
  };
  
  // 提取注册地址
  const extractAddress = () => {
    debug('开始提取注册地址');
    const raw = getTextByLabel(['注册地址', '企业地址', '住所', '经营地址', '地址']);
    const result = raw.replace(/（邮编.*?）/g, '').replace(/\\(邮编.*?\\)/g, '').trim();
    debug('注册地址:', result);
    return result;
  };
  
  // 提取所属行业（改进版）
  const extractIndustry = () => {
    debug('开始提取所属行业');
    
    // 方法1：查找行业链接
    const industryLink = document.querySelector('a[href*="/industry/"], a[href*="/hangye/"], .industry a');
    if (industryLink) {
      const industry = clean(norm(industryLink.textContent));
      if (industry && industry.length >= 2 && industry.length <= 50) {
        debug('行业链接找到:', industry);
        return industry;
      }
    }
    
    // 方法2：通用标签查找（支持多标签）
    const result = getTextByLabel(['所属行业', '行业', '行业分类', '行业类别']);
    debug('所属行业:', result);
    return result;
  };
  
  // 提取联系电话（改进版，支持多个电话）
  const extractPhone = () => {
    debug('开始提取联系电话');
    const phones = [];
    
    // 添加电话的辅助函数（带验证）
    const addPhone = (p) => {
      if (!p) return;
      const phone = p.replace(/\\s+/g, '');
      // 验证：至少7位数字
      if (phone.length < 7) {
        debug('电话太短，跳过:', phone);
        return;
      }
      // 验证：必须包含足够的数字
      const digitCount = (phone.match(/\\d/g) || []).length;
      if (digitCount < 7) {
        debug('电话数字不足，跳过:', phone);
        return;
      }
      if (!phones.includes(phone)) {
        phones.push(phone);
        debug('添加电话:', phone);
      }
    };
    
    // 从文本中收集电话
    const collectPhonesFromText = (text) => {
      if (!text) return;
      // 匹配中国电话格式：手机或固话
      const matches = text.match(/(1[3-9]\\d{9}|0\\d{2,3}-?\\d{7,8}|\\d{3,4}-\\d{7,8})/g);
      if (matches) matches.forEach(addPhone);
    };
    
    // 方法1：查找电话链接
    const phoneLinks = document.querySelectorAll('a[href^="tel:"]');
    phoneLinks.forEach(el => {
      const phone = el.getAttribute('href')?.replace('tel:', '');
      addPhone(phone);
    });
    
    // 方法2：查找电话相关元素（但要排除无关元素）
    const phoneEls = document.querySelectorAll('.phone, .tel, [class*="phone"]:not([class*="smartphone"]):not([class*="iphone"])');
    phoneEls.forEach(el => {
      const text = norm(el.textContent);
      collectPhonesFromText(text);
    });
    
    // 方法3：从联系信息区域提取
    const contactSection = document.querySelector('.contact, .contact-info, [class*="contact"]');
    if (contactSection) {
      collectPhonesFromText(contactSection.textContent || '');
    }
    
    // 方法4：联系人列表条目
    const contactItems = document.querySelectorAll('.contact-item, .person-item, [class*="contact"] li');
    contactItems.forEach(item => {
      collectPhonesFromText(item.textContent || '');
      const phoneEl = item.querySelector('a[href^="tel:"], .phone, .tel');
      if (phoneEl) {
        const phone = phoneEl.getAttribute('href')?.replace('tel:', '') || phoneEl.textContent;
        addPhone(phone);
      }
    });
    
    // 方法5：通用标签查找
    if (phones.length === 0) {
      const raw = getTextByLabel(['电话', '联系电话', '联系方式', '联系号码', '手机']);
      collectPhonesFromText(raw);
    }
    
    debug('提取到电话:', phones);
    return phones.join(', ');
  };
  
  // 提取电子邮箱（改进版，支持多个邮箱）
  const extractEmail = () => {
    debug('开始提取电子邮箱');
    const emails = [];
    const emailPattern = /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}/g;
    
    // 添加邮箱的辅助函数
    const addEmail = (e) => {
      if (!e) return;
      const email = e.trim().toLowerCase();
      if (!emails.includes(email)) {
        emails.push(email);
        debug('添加邮箱:', email);
      }
    };
    
    // 从文本中收集邮箱
    const collectEmailsFromText = (text) => {
      if (!text) return;
      const matches = text.match(emailPattern);
      if (matches) matches.forEach(addEmail);
    };
    
    // 方法1：查找邮箱链接
    const emailLinks = document.querySelectorAll('a[href^="mailto:"]');
    emailLinks.forEach(el => {
      const email = el.getAttribute('href')?.replace('mailto:', '');
      addEmail(email);
    });
    
    // 方法2：从联系信息区域查找
    const contactSection = document.querySelector('.contact, .contact-info, [class*="contact"]');
    if (contactSection) {
      collectEmailsFromText(contactSection.textContent || '');
    }
    
    // 方法3：联系人列表条目
    const contactItems = document.querySelectorAll('.contact-item, .person-item, [class*="contact"] li');
    contactItems.forEach(item => collectEmailsFromText(item.textContent || ''));
    
    // 方法4：通用标签查找
    if (emails.length === 0) {
      const raw = getTextByLabel(['邮箱', '电子邮箱', 'Email', '联系邮箱', '企业邮箱']);
      collectEmailsFromText(raw);
    }
    
    debug('提取到邮箱:', emails);
    return emails.join(', ');
  };
  
  // 提取官网（改进版）
  const extractWebsite = () => {
    debug('开始提取官网');
    
    // URL 验证函数 - 排除 mailto: 和 tel: 链接
    const isValidWebsiteUrl = (url) => {
      if (!url) return false;
      const lower = url.toLowerCase();
      // 排除非网站链接
      if (lower.startsWith('mailto:') || lower.startsWith('tel:') || lower.startsWith('javascript:')) {
        return false;
      }
      // 必须是 http/https 或域名格式
      return lower.startsWith('http://') || lower.startsWith('https://') || 
             /^(www\\.)?[a-zA-Z0-9-]+\\.[a-zA-Z]{2,}/.test(url);
    };
    
    // 方法1：通用标签查找（优先，因为更精确）
    const raw = getTextByLabel(['官网', '网址', '企业官网', '网站', '公司网站']);
    if (raw) {
      debug('官网标签找到原始值:', raw);
      // 验证是否是有效的网站 URL
      if (isValidWebsiteUrl(raw)) {
        const result = raw.startsWith('http') ? raw : 'http://' + raw;
        debug('官网已是URL:', result);
        return result;
      }
      // 提取 URL
      const urlMatch = raw.match(/(https?:\\/\\/[^\\s]+|www\\.[^\\s]+|[a-zA-Z0-9-]+\\.[a-zA-Z]{2,}[^\\s]*)/);
      if (urlMatch && isValidWebsiteUrl(urlMatch[1])) {
        const url = urlMatch[1];
        const result = url.startsWith('http') ? url : 'http://' + url;
        debug('官网提取URL:', result);
        return result;
      }
    }
    
    // 方法2：查找官网链接
    const websiteLinks = document.querySelectorAll('a[href*="http"]:not([href*="qcc.com"]):not([href*="qichacha"]):not([href*="baidu.com"])');
    for (const link of websiteLinks) {
      const text = norm(link.textContent);
      const href = link.getAttribute('href') || '';
      
      // 验证 href 是否是有效的网站 URL
      if (!isValidWebsiteUrl(href)) continue;
      
      // 检查是否是官网相关的链接
      if (text.includes('官网') || text.includes('网站') || text.includes('官方')) {
        debug('官网链接找到:', href);
        return href;
      }
      
      // 检查链接文本是否是域名格式
      if (/^(www\\.)?[a-zA-Z0-9-]+\\.[a-zA-Z]{2,}/.test(text)) {
        const result = text.startsWith('http') ? text : 'http://' + text;
        debug('域名格式链接找到:', result);
        return result;
      }
    }
    
    debug('未找到官网');
    return '';
  };
  
  // 提取联系人信息（支持多联系人）
  const extractContacts = () => {
    debug('开始提取联系人');
    const contacts = [];
    
    // 查找联系人列表
    const contactItems = document.querySelectorAll('.contact-item, .person-item, [class*="contact"] li, .key-person');
    contactItems.forEach(item => {
      const name = item.querySelector('.name, .person-name, .contact-name')?.textContent?.trim();
      const phone = item.querySelector('.phone, .tel, a[href^="tel:"]')?.textContent?.trim();
      const position = item.querySelector('.position, .title, .job')?.textContent?.trim();
      if (name || phone) {
        contacts.push({ 
          name: name || '', 
          phone: phone || '',
          position: position || ''
        });
        debug('添加联系人:', { name, phone, position });
      }
    });
    
    debug('提取到联系人数量:', contacts.length);
    return contacts;
  };

  // 从 URL 提取企业 ID
  const firmMatch = location.href.match(/\\/firm\\/([^/?#.]+)\\.html/i);
  const companyMatch = location.href.match(/\\/company\\/([^/?#.]+)\\.html/i);
  const id = firmMatch ? firmMatch[1] : (companyMatch ? companyMatch[1] : '');
  
  // 提取企业名称
  const name = getText('h1') || getText('.title') || getText('.company-name') || 
               document.title.replace(/-.*\$/, '').trim();
  
  debug('========== 开始提取企业详情 ==========');
  debug('企业名称:', name);
  debug('企业ID:', id);
  debug('当前URL:', location.href);
  
  // 打印页面关键区域的 HTML 结构（用于调试）
  const basicInfoSection = document.querySelector('.cominfo-normal, .basic-info, .company-info, table');
  if (basicInfoSection) {
    debug('基本信息区域HTML(前500字符):', basicInfoSection.outerHTML.substring(0, 500));
  }
  
  const contactSection = document.querySelector('.contact, .contact-info, [class*="contact"]');
  if (contactSection) {
    debug('联系信息区域HTML(前500字符):', contactSection.outerHTML.substring(0, 500));
  }
  
  const result = {
    id: id,
    name: name,
    creditCode: extractCreditCode(),
    legalPerson: extractLegalPerson(),
    registeredCapital: getTextByLabel(['注册资本', '注册资金']),
    establishDate: extractDate(),
    status: extractStatus(),
    address: extractAddress(),
    industry: extractIndustry(),
    businessScope: getTextByLabel(['经营范围', '业务范围']),
    phone: extractPhone(),
    email: extractEmail(),
    website: extractWebsite(),
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
  debug('========== 提取完成 ==========');
  
  return result;
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
  
  // 调试日志函数 - 通过 Flutter handler 传递
  const debug = (...args) => {
    try {
      window.flutter_inappwebview.callHandler('onQccDebug', args.map(a => 
        typeof a === 'object' ? JSON.stringify(a) : String(a)
      ).join(' '));
    } catch (_) {}
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
    return /\\/web\\/search|search\\?key=/.test(href);
  };

  // ========== 结果抓取（多选择器策略） ==========
  const scrapeResults = () => {
    debug(' 开始抓取搜索结果');
    
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
    
    // 如果没找到，尝试更宽泛的选择器
    if (items.length === 0) {
      debug(' 标准选择器未匹配，尝试宽泛选择器');
      const links = document.querySelectorAll('a[href*="/firm/"], a[href*="/company/"]');
      debug(' 找到企业链接数:', links.length);
      const containers = new Set();
      links.forEach((link, linkIdx) => {
        let parent = link.parentElement;
        // 向上查找更多层，找到包含详细信息的容器
        for (let i = 0; i < 10 && parent; i++) {
          const text = parent.innerText || '';
          // 如果容器包含"法定代表人"或"注册资本"等关键词，说明找到了正确的容器
          if (text.includes('法定代表人') || text.includes('注册资本') || text.includes('成立日期')) {
            containers.add(parent);
            if (linkIdx < 2) {
              debug(' 链接', linkIdx, '找到包含详情的容器，层级:', i, 'HTML(前300):', parent.outerHTML.substring(0, 300));
            }
            break;
          }
          // 如果容器有多个子元素且文本长度足够，也可能是正确的容器
          if (parent.children.length > 3 && text.length > 100) {
            containers.add(parent);
            if (linkIdx < 2) {
              debug(' 链接', linkIdx, '找到多子元素容器，层级:', i, '子元素数:', parent.children.length);
            }
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
      if (!a) {
        debug(' 元素', idx, '未找到链接');
        return;
      }
      
      const name = (a.innerText || a.textContent || '').trim();
      const url = a.href || '';
      
      const firmMatch = url.match(/\\/firm\\/([^/?#.]+)/i);
      const companyMatch = url.match(/\\/company\\/([^/?#.]+)/i);
      const id = firmMatch ? firmMatch[1] : (companyMatch ? companyMatch[1] : '');
      
      if (!name || !id) {
        debug(' 元素', idx, '缺少name或id, name=', name, 'id=', id);
        return;
      }

      const text = (item.innerText || item.textContent || '');
      
      // 打印前3个元素的原始文本用于调试
      if (idx < 3) {
        debug(' 元素', idx, '原始文本(前500字符):', text.substring(0, 500));
      }
      
      // ========== 改进的字段提取逻辑 ==========
      // 使用非贪婪匹配 + lookahead 策略，适应企查查页面的多行文本格式
      
      // 提取法定代表人 - 改进版
      // 使用 lookahead 确保在遇到下一个字段标签时停止匹配
      let legalPerson = '';
      const lpMatch = text.match(/(?:法定代表人|法人|法人代表)[\\s]*[:：]?[\\s]*([\\s\\S]*?)(?=[\\s]*(?:注册资本|成立日期|经营状态|统一社会信用代码|所属行业|注册地址|电话|邮箱)|\$)/);
      if (lpMatch && lpMatch[1]) {
        // 从匹配到的块中清理并提取第一个词组作为名称
        legalPerson = lpMatch[1].trim().split(/[\\s\\n\\r]/)[0].replace(/[,，]/g, '').substring(0, 20);
      }
      
      // 提取经营状态
      let status = '';
      const statusMatch = text.match(/(存续|在业|注销|吊销|迁出|清算|开业|停业)/);
      if (statusMatch) status = statusMatch[1];
      
      // 提取注册资本 - 改进版
      let registeredCapital = '';
      const capMatch = text.match(/(?:注册资本|注册资金)[\\s]*[:：]?[\\s]*([\\s\\S]*?)(?=[\\s]*(?:法定代表人|成立日期|经营状态|统一社会信用代码|所属行业|注册地址|电话|邮箱)|\$)/);
      if (capMatch && capMatch[1]) {
        // 提取数字和单位
        const capValue = capMatch[1].match(/([\\d,.]+[\\s]*万?[人民币元美元欧元港币]*)/);
        if (capValue) {
          registeredCapital = capValue[1].replace(/[\\s]/g, '');
        }
      }
      
      // 提取成立日期 - 改进版
      let establishDate = '';
      const dateMatch = text.match(/(?:成立日期|成立时间|成立)[\\s]*[:：]?[\\s]*([\\s\\S]*?)(?=[\\s]*(?:法定代表人|注册资本|经营状态|统一社会信用代码|所属行业|注册地址|电话|邮箱)|\$)/);
      if (dateMatch && dateMatch[1]) {
        const d = dateMatch[1].match(/(\\d{4}[-/年]\\d{1,2}[-/月]\\d{1,2}日?)/);
        if (d) establishDate = d[1];
      }
      
      // 提取统一社会信用代码 - 使用 word boundary 确保匹配独立的18位代码
      let creditCode = '';
      const ccMatch = text.match(/([0-9A-Z]{18})/);
      if (ccMatch) creditCode = ccMatch[1];

      if (idx < 3) {
        debug(' 元素', idx, '提取结果:', JSON.stringify({
          name, id, legalPerson, status, registeredCapital, establishDate, creditCode
        }));
      }

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
        // 搜索结果列表页只有基本信息，详细信息需要进入详情页获取
        // 以下字段在列表页无法获取，设为空字符串
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
