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
}
