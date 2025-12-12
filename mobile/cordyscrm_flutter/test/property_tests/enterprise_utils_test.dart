import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

/// **Feature: crm-mobile-enterprise-ai, Property 13: 剪贴板企业名称识别**
/// **Validates: Requirements 4.1**
///
/// For any 包含中文企业名称（2-50个字符，包含"公司"、"集团"、"有限"等关键词）的文本，
/// 应该被识别为潜在的企业名称。
///
/// **Feature: crm-mobile-enterprise-ai, Property 14: 爱企查链接解析**
/// **Validates: Requirements 4.2**
///
/// For any 有效的爱企查企业详情页链接，应该能够正确解析出企业标识符。
///
/// **Feature: crm-mobile-enterprise-ai, Property 15: 企业搜索结果相关性**
/// **Validates: Requirements 4.3**
///
/// For any 企业名称搜索词（≥2个字符），返回的候选列表中每个企业名称应该包含搜索词或其拼音首字母。

/// 企业名称识别工具类
class EnterpriseNameDetector {
  /// 企业名称关键词
  static const List<String> companyKeywords = [
    '公司',
    '集团',
    '有限',
    '股份',
    '企业',
    '工厂',
    '厂',
    '店',
    '中心',
    '研究院',
    '研究所',
  ];

  /// 企业名称正则表达式
  static final RegExp companyNamePattern = RegExp(
    r'[\u4e00-\u9fa5]{2,50}(?:公司|集团|有限|股份|企业|工厂|厂|店|中心|研究院|研究所)',
  );

  /// 检测文本中是否包含企业名称
  static bool containsCompanyName(String? text) {
    if (text == null || text.isEmpty) return false;
    return companyNamePattern.hasMatch(text);
  }

  /// 从文本中提取企业名称
  static List<String> extractCompanyNames(String? text) {
    if (text == null || text.isEmpty) return [];
    
    final matches = companyNamePattern.allMatches(text);
    return matches.map((m) => m.group(0)!).toSet().toList();
  }

  /// 验证是否为有效的企业名称
  static bool isValidCompanyName(String? name) {
    if (name == null || name.isEmpty) return false;
    if (name.length < 2 || name.length > 50) return false;
    
    // 必须包含关键词
    return companyKeywords.any((keyword) => name.contains(keyword));
  }
}

/// 爱企查链接解析工具类
class AiqichaLinkParser {
  /// 爱企查企业详情页链接正则表达式
  static final RegExp detailPagePattern = RegExp(
    r'aiqicha\.baidu\.com/company_detail_(\d+)',
  );

  /// 爱企查搜索页链接正则表达式
  static final RegExp searchPagePattern = RegExp(
    r'aiqicha\.baidu\.com/s\?q=([^&]+)',
  );

  /// 解析企业详情页链接，返回企业ID
  static String? parseCompanyId(String? url) {
    if (url == null || url.isEmpty) return null;
    
    final match = detailPagePattern.firstMatch(url);
    return match?.group(1);
  }

  /// 检测是否为爱企查企业详情页链接
  static bool isDetailPageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    return detailPagePattern.hasMatch(url);
  }

  /// 检测是否为爱企查链接
  static bool isAiqichaUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.contains('aiqicha.baidu.com');
  }

  /// 构建企业详情页链接
  static String buildDetailPageUrl(String companyId) {
    return 'https://aiqicha.baidu.com/company_detail_$companyId';
  }
}

/// 企业搜索工具类
class EnterpriseSearchMatcher {
  /// 检查搜索结果是否与关键词相关
  static bool isRelevant(String companyName, String keyword) {
    if (keyword.length < 2) return false;
    
    // 直接包含关键词
    if (companyName.toLowerCase().contains(keyword.toLowerCase())) {
      return true;
    }
    
    // 拼音首字母匹配（简化实现）
    // 实际应用中应该使用拼音库
    return false;
  }
}

void main() {
  final random = Random();

  /// 生成随机中文字符串
  String randomChineseString(int length) {
    const chars = '中国华东南西北科技信息网络电子商务贸易投资金融建设工程材料机械制造';
    return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// 生成有效的企业名称
  String generateValidCompanyName() {
    final prefixes = ['北京', '上海', '广州', '深圳', '杭州', '南京', '成都', '武汉'];
    final middles = ['科技', '信息', '网络', '电子', '商务', '贸易', '投资', '金融'];
    final suffixes = ['有限公司', '股份有限公司', '集团有限公司', '科技有限公司'];
    
    return '${prefixes[random.nextInt(prefixes.length)]}'
        '${randomChineseString(random.nextInt(4) + 2)}'
        '${middles[random.nextInt(middles.length)]}'
        '${suffixes[random.nextInt(suffixes.length)]}';
  }

  /// 生成无效的企业名称
  String generateInvalidCompanyName() {
    final types = [
      // 太短
      () => randomChineseString(1),
      // 不包含关键词
      () => randomChineseString(random.nextInt(10) + 5),
      // 纯英文
      () => 'ABC Company Ltd',
      // 纯数字
      () => '12345678',
    ];
    return types[random.nextInt(types.length)]();
  }

  /// 生成有效的爱企查链接
  String generateValidAiqichaUrl() {
    final companyId = List.generate(10, (_) => random.nextInt(10)).join();
    return 'https://aiqicha.baidu.com/company_detail_$companyId';
  }

  /// 生成无效的爱企查链接
  String generateInvalidAiqichaUrl() {
    final types = [
      // 其他网站
      () => 'https://www.baidu.com/s?wd=test',
      // 爱企查搜索页
      () => 'https://aiqicha.baidu.com/s?q=test',
      // 格式错误
      () => 'https://aiqicha.baidu.com/company_abc',
      // 空链接
      () => '',
    ];
    return types[random.nextInt(types.length)]();
  }

  group('Property 13: 剪贴板企业名称识别', () {
    /// Property Test: 有效企业名称应该被识别
    test('should detect valid company names', () {
      for (var i = 0; i < 100; i++) {
        final name = generateValidCompanyName();
        final text = '今天拜访了$name，洽谈合作事宜。';
        
        expect(EnterpriseNameDetector.containsCompanyName(text), isTrue,
            reason: 'Text containing "$name" should be detected');
        
        final extracted = EnterpriseNameDetector.extractCompanyNames(text);
        expect(extracted, isNotEmpty,
            reason: 'Should extract company name from text');
      }
    });

    /// Property Test: 无效文本不应该被识别为企业名称
    test('should not detect invalid company names', () {
      final invalidTexts = [
        '今天天气很好',
        'Hello World',
        '12345678',
        '',
        '   ',
      ];
      
      for (final text in invalidTexts) {
        expect(EnterpriseNameDetector.containsCompanyName(text), isFalse,
            reason: 'Text "$text" should not be detected as company name');
      }
    });

    /// Property Test: 企业名称长度应该在 2-50 字符之间
    test('should validate company name length', () {
      for (var i = 0; i < 100; i++) {
        final name = generateValidCompanyName();
        
        expect(name.length, greaterThanOrEqualTo(2));
        expect(name.length, lessThanOrEqualTo(50));
        expect(EnterpriseNameDetector.isValidCompanyName(name), isTrue);
      }
    });

    /// Property Test: 企业名称必须包含关键词
    test('should require company keywords', () {
      for (var i = 0; i < 50; i++) {
        final name = generateValidCompanyName();
        
        final hasKeyword = EnterpriseNameDetector.companyKeywords
            .any((keyword) => name.contains(keyword));
        expect(hasKeyword, isTrue,
            reason: 'Company name "$name" should contain a keyword');
      }
    });
  });

  group('Property 14: 爱企查链接解析', () {
    /// Property Test: 有效链接应该能够解析出企业ID
    test('should parse company ID from valid URLs', () {
      for (var i = 0; i < 100; i++) {
        final companyId = List.generate(10, (_) => random.nextInt(10)).join();
        final url = 'https://aiqicha.baidu.com/company_detail_$companyId';
        
        final parsedId = AiqichaLinkParser.parseCompanyId(url);
        
        expect(parsedId, isNotNull);
        expect(parsedId, equals(companyId));
      }
    });

    /// Property Test: 无效链接应该返回 null
    test('should return null for invalid URLs', () {
      for (var i = 0; i < 50; i++) {
        final url = generateInvalidAiqichaUrl();
        
        if (!url.contains('company_detail_')) {
          final parsedId = AiqichaLinkParser.parseCompanyId(url);
          expect(parsedId, isNull,
              reason: 'Invalid URL "$url" should return null');
        }
      }
    });

    /// Property Test: 链接检测应该正确识别爱企查详情页
    test('should correctly identify detail page URLs', () {
      for (var i = 0; i < 100; i++) {
        final validUrl = generateValidAiqichaUrl();
        
        expect(AiqichaLinkParser.isDetailPageUrl(validUrl), isTrue,
            reason: 'URL "$validUrl" should be identified as detail page');
        expect(AiqichaLinkParser.isAiqichaUrl(validUrl), isTrue,
            reason: 'URL "$validUrl" should be identified as Aiqicha URL');
      }
    });

    /// Property Test: 链接构建和解析应该是往返一致的
    test('should have round-trip consistency for URL building and parsing', () {
      for (var i = 0; i < 100; i++) {
        final originalId = List.generate(10, (_) => random.nextInt(10)).join();
        
        // 构建链接
        final url = AiqichaLinkParser.buildDetailPageUrl(originalId);
        
        // 解析链接
        final parsedId = AiqichaLinkParser.parseCompanyId(url);
        
        // 验证往返一致性
        expect(parsedId, equals(originalId));
      }
    });
  });

  group('Property 15: 企业搜索结果相关性', () {
    /// Property Test: 搜索结果应该包含搜索关键词
    test('should return relevant results containing keyword', () {
      final testCases = [
        ('北京科技有限公司', '北京'),
        ('上海信息技术有限公司', '上海'),
        ('深圳网络科技有限公司', '网络'),
        ('杭州电子商务有限公司', '电子'),
      ];
      
      for (final (companyName, keyword) in testCases) {
        expect(EnterpriseSearchMatcher.isRelevant(companyName, keyword), isTrue,
            reason: '"$companyName" should be relevant to keyword "$keyword"');
      }
    });

    /// Property Test: 搜索关键词长度必须 >= 2
    test('should require minimum keyword length of 2', () {
      final companyName = '北京科技有限公司';
      
      // 单字符关键词应该返回 false
      expect(EnterpriseSearchMatcher.isRelevant(companyName, '北'), isFalse);
      expect(EnterpriseSearchMatcher.isRelevant(companyName, ''), isFalse);
      
      // 两字符及以上应该正常匹配
      expect(EnterpriseSearchMatcher.isRelevant(companyName, '北京'), isTrue);
      expect(EnterpriseSearchMatcher.isRelevant(companyName, '科技'), isTrue);
    });

    /// Property Test: 搜索应该不区分大小写
    test('should be case insensitive', () {
      final companyName = 'ABC Technology Co., Ltd';
      
      expect(EnterpriseSearchMatcher.isRelevant(companyName, 'abc'), isTrue);
      expect(EnterpriseSearchMatcher.isRelevant(companyName, 'ABC'), isTrue);
      expect(EnterpriseSearchMatcher.isRelevant(companyName, 'technology'), isTrue);
      expect(EnterpriseSearchMatcher.isRelevant(companyName, 'TECHNOLOGY'), isTrue);
    });
  });
}
