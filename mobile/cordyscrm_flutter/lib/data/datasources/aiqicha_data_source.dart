import '../../domain/datasources/enterprise_data_source.dart';

/// 爱企查（aiqicha.baidu.com）数据源实现
///
/// 提供爱企查网站的 URL 检测和 JavaScript 注入逻辑。
/// 复用现有 EnterpriseWebViewPage 中的 JS 代码。
class AiqichaDataSource extends EnterpriseDataSourceInterface {
  const AiqichaDataSource();

  @override
  String get sourceId => 'iqicha';

  @override
  String get displayName => '爱企查';

  @override
  String get startUrl => 'https://aiqicha.baidu.com';

  @override
  bool isSourceLink(String url) {
    if (url.isEmpty) return false;
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    return host == 'aiqicha.baidu.com' || host.endsWith('.aiqicha.baidu.com');
  }

  @override
  bool isDetailPage(String url) {
    if (url.isEmpty) return false;
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return false;
    if (!isSourceLink(url)) return false;

    final path = uri.path;
    final hasPid = uri.queryParameters['pid']?.isNotEmpty == true;

    // 爱企查详情页格式：
    // - /company_detail_<id>
    // - /detail?pid=<id>
    // - 其他包含 pid 参数的页面
    return path.contains('company_detail') ||
        path.contains('/detail') ||
        hasPid;
  }

  @override
  String get extractDataJs => _extractDataJs;

  @override
  String get injectButtonJs => _injectButtonJs;


  /// 导入按钮注入脚本
  ///
  /// 创建浮动按钮，点击时调用数据提取函数并通过 Flutter 回调传递数据。
  /// 使用紫色渐变样式。
  static const _injectButtonJs = '''
(function() {
  // 防止重复注入
  if (document.getElementById('__crm_import_btn')) return;
  
  // 创建浮动按钮
  const btn = document.createElement('button');
  btn.id = '__crm_import_btn';
  btn.innerHTML = '📥 导入CRM';
  
  // 样式设置（紫色渐变）
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

  /// 数据提取脚本
  ///
  /// 从爱企查页面 DOM 中提取企业信息。
  static const _extractDataJs = '''
window.__extractEnterpriseData = function() {
  const getText = (sel) => {
    const el = document.querySelector(sel);
    return el ? el.textContent.trim() : '';
  };
  
  const getTextByLabel = (label) => {
    const items = document.querySelectorAll('.info-item, .detail-item, tr');
    for (const item of items) {
      if (item.textContent.includes(label)) {
        const value = item.querySelector('.value, td:last-child, span:last-child');
        if (value) return value.textContent.trim();
      }
    }
    return '';
  };
  
  // 从 URL 提取企业 ID
  const urlMatch = location.href.match(/company_detail_(\\w+)/);
  const pidMatch = location.href.match(/pid=(\\w+)/);
  const id = urlMatch ? urlMatch[1] : (pidMatch ? pidMatch[1] : '');
  
  return {
    id: id,
    name: getText('.company-name, .title h1, h1.name') || getText('h1'),
    creditCode: getTextByLabel('统一社会信用代码') || getTextByLabel('信用代码'),
    legalPerson: getTextByLabel('法定代表人') || getTextByLabel('法人'),
    registeredCapital: getTextByLabel('注册资本'),
    establishDate: getTextByLabel('成立日期') || getTextByLabel('成立时间'),
    status: getTextByLabel('经营状态') || getTextByLabel('状态'),
    address: getTextByLabel('注册地址') || getTextByLabel('地址'),
    industry: getTextByLabel('所属行业') || getTextByLabel('行业'),
    businessScope: getTextByLabel('经营范围'),
    phone: getTextByLabel('电话') || getTextByLabel('联系电话'),
    email: getTextByLabel('邮箱') || getTextByLabel('电子邮箱'),
    website: getTextByLabel('官网') || getTextByLabel('网址'),
    source: 'iqicha'
  };
};
''';
}
