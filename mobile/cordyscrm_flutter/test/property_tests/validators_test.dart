import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:cordyscrm_flutter/core/utils/validators.dart';

/// **Feature: crm-mobile-enterprise-ai, Property 2: 表单验证规则一致性**
/// **Validates: Requirements 1.4**
///
/// For any 客户信息输入，Flutter App 和 Web 端应用相同的验证规则，
/// 对于相同的输入应该产生相同的验证结果。
void main() {
  final random = Random();

  /// 生成随机字符串
  String randomString(int length, {String chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'}) {
    return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// 生成有效的中国大陆手机号
  String generateValidPhone() {
    final prefix = ['13', '14', '15', '16', '17', '18', '19'][random.nextInt(7)];
    final suffix = List.generate(9, (_) => random.nextInt(10)).join();
    return '$prefix$suffix';
  }

  /// 生成无效的手机号
  String generateInvalidPhone() {
    final types = [
      // 太短
      () => '1${random.nextInt(9) + 3}${List.generate(random.nextInt(8), (_) => random.nextInt(10)).join()}',
      // 太长
      () => '1${random.nextInt(9) + 3}${List.generate(12, (_) => random.nextInt(10)).join()}',
      // 错误的前缀
      () => '10${List.generate(9, (_) => random.nextInt(10)).join()}',
      () => '11${List.generate(9, (_) => random.nextInt(10)).join()}',
      () => '12${List.generate(9, (_) => random.nextInt(10)).join()}',
      // 包含字母
      () => '1${random.nextInt(9) + 3}${randomString(9, chars: '0123456789abc')}',
    ];
    return types[random.nextInt(types.length)]();
  }

  /// 生成有效的邮箱
  String generateValidEmail() {
    final localPart = randomString(random.nextInt(10) + 3, chars: 'abcdefghijklmnopqrstuvwxyz0123456789._-');
    final domain = randomString(random.nextInt(8) + 3, chars: 'abcdefghijklmnopqrstuvwxyz');
    final tld = ['com', 'cn', 'org', 'net', 'io'][random.nextInt(5)];
    return '$localPart@$domain.$tld';
  }

  /// 生成无效的邮箱
  String generateInvalidEmail() {
    final types = [
      // 缺少 @
      () => '${randomString(10)}${randomString(5)}.com',
      // 缺少域名
      () => '${randomString(10)}@',
      // 缺少 TLD
      () => '${randomString(10)}@${randomString(5)}',
      // 多个 @
      () => '${randomString(5)}@${randomString(5)}@${randomString(5)}.com',
      // 空格
      () => '${randomString(5)} ${randomString(5)}@${randomString(5)}.com',
    ];
    return types[random.nextInt(types.length)]();
  }

  /// 生成有效的统一社会信用代码
  String generateValidCreditCode() {
    const chars = '0123456789ABCDEFGHJKLMNPQRTUWXY';
    return List.generate(18, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// 生成无效的统一社会信用代码
  String generateInvalidCreditCode() {
    final types = [
      // 太短
      () => randomString(random.nextInt(17), chars: '0123456789ABCDEFGHJKLMNPQRTUWXY'),
      // 太长
      () => randomString(random.nextInt(10) + 19, chars: '0123456789ABCDEFGHJKLMNPQRTUWXY'),
      // 包含无效字符
      () => randomString(18, chars: '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'),
    ];
    return types[random.nextInt(types.length)]();
  }

  group('Property 2: 表单验证规则一致性', () {
    group('手机号验证', () {
      /// Property Test: 有效手机号应该通过验证
      test('should accept valid phone numbers', () {
        for (var i = 0; i < 100; i++) {
          final phone = generateValidPhone();
          final result = Validators.validatePhone(phone);
          expect(result, isNull, reason: 'Valid phone "$phone" should pass validation');
          expect(Validators.isValidPhone(phone), isTrue);
        }
      });

      /// Property Test: 无效手机号应该被拒绝
      test('should reject invalid phone numbers', () {
        for (var i = 0; i < 100; i++) {
          final phone = generateInvalidPhone();
          final result = Validators.validatePhone(phone);
          // 无效手机号应该返回错误信息或被 isValidPhone 拒绝
          if (phone.length == 11 && RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) {
            // 如果碰巧生成了有效的手机号，跳过
            continue;
          }
          expect(Validators.isValidPhone(phone), isFalse,
              reason: 'Invalid phone "$phone" should fail validation');
        }
      });

      /// Property Test: 空值应该通过验证（非必填）
      test('should accept empty phone values', () {
        expect(Validators.validatePhone(null), isNull);
        expect(Validators.validatePhone(''), isNull);
      });
    });

    group('邮箱验证', () {
      /// Property Test: 有效邮箱应该通过验证
      test('should accept valid email addresses', () {
        for (var i = 0; i < 100; i++) {
          final email = generateValidEmail();
          final result = Validators.validateEmail(email);
          expect(result, isNull, reason: 'Valid email "$email" should pass validation');
          expect(Validators.isValidEmail(email), isTrue);
        }
      });

      /// Property Test: 无效邮箱应该被拒绝
      test('should reject invalid email addresses', () {
        for (var i = 0; i < 100; i++) {
          final email = generateInvalidEmail();
          expect(Validators.isValidEmail(email), isFalse,
              reason: 'Invalid email "$email" should fail validation');
        }
      });

      /// Property Test: 空值应该通过验证（非必填）
      test('should accept empty email values', () {
        expect(Validators.validateEmail(null), isNull);
        expect(Validators.validateEmail(''), isNull);
      });
    });

    group('统一社会信用代码验证', () {
      /// Property Test: 有效信用代码应该通过验证
      test('should accept valid credit codes', () {
        for (var i = 0; i < 100; i++) {
          final code = generateValidCreditCode();
          final result = Validators.validateCreditCode(code);
          expect(result, isNull, reason: 'Valid credit code "$code" should pass validation');
          expect(Validators.isValidCreditCode(code), isTrue);
        }
      });

      /// Property Test: 无效信用代码应该被拒绝
      test('should reject invalid credit codes', () {
        for (var i = 0; i < 100; i++) {
          final code = generateInvalidCreditCode();
          if (code.length == 18 && RegExp(r'^[0-9A-Z]{18}$').hasMatch(code)) {
            // 如果碰巧生成了有效的信用代码，跳过
            continue;
          }
          expect(Validators.isValidCreditCode(code), isFalse,
              reason: 'Invalid credit code "$code" should fail validation');
        }
      });

      /// Property Test: 空值应该被拒绝（必填）
      test('should reject empty credit code values', () {
        expect(Validators.validateCreditCode(null), isNotNull);
        expect(Validators.validateCreditCode(''), isNotNull);
      });
    });

    group('企业名称验证', () {
      /// Property Test: 有效企业名称应该通过验证
      test('should accept valid company names', () {
        for (var i = 0; i < 100; i++) {
          final length = random.nextInt(49) + 2; // 2-50 个字符
          final name = randomString(length);
          final result = Validators.validateCompanyName(name);
          expect(result, isNull, reason: 'Valid company name "$name" (length: $length) should pass validation');
        }
      });

      /// Property Test: 太短的企业名称应该被拒绝
      test('should reject company names that are too short', () {
        for (var i = 0; i < 50; i++) {
          final name = randomString(1);
          final result = Validators.validateCompanyName(name);
          expect(result, isNotNull, reason: 'Company name "$name" (length: 1) should fail validation');
        }
      });

      /// Property Test: 太长的企业名称应该被拒绝
      test('should reject company names that are too long', () {
        for (var i = 0; i < 50; i++) {
          final length = random.nextInt(50) + 51; // 51-100 个字符
          final name = randomString(length);
          final result = Validators.validateCompanyName(name);
          expect(result, isNotNull, reason: 'Company name "$name" (length: $length) should fail validation');
        }
      });

      /// Property Test: 空值应该被拒绝（必填）
      test('should reject empty company name values', () {
        expect(Validators.validateCompanyName(null), isNotNull);
        expect(Validators.validateCompanyName(''), isNotNull);
      });
    });

    group('必填字段验证', () {
      /// Property Test: 非空值应该通过验证
      test('should accept non-empty values', () {
        for (var i = 0; i < 100; i++) {
          final value = randomString(random.nextInt(50) + 1);
          final result = Validators.validateRequired(value);
          expect(result, isNull, reason: 'Non-empty value "$value" should pass validation');
        }
      });

      /// Property Test: 空值应该被拒绝
      test('should reject empty values', () {
        expect(Validators.validateRequired(null), isNotNull);
        expect(Validators.validateRequired(''), isNotNull);
        expect(Validators.validateRequired('   '), isNotNull); // 只有空格
        expect(Validators.validateRequired('\t\n'), isNotNull); // 只有空白字符
      });
    });

    group('长度验证', () {
      /// Property Test: 符合长度要求的值应该通过验证
      test('should accept values within length limits', () {
        for (var i = 0; i < 100; i++) {
          final minLength = random.nextInt(5) + 1;
          final maxLength = minLength + random.nextInt(20) + 1;
          final length = minLength + random.nextInt(maxLength - minLength + 1);
          final value = randomString(length);

          final result = Validators.validateLength(
            value,
            minLength: minLength,
            maxLength: maxLength,
          );
          expect(result, isNull,
              reason: 'Value of length $length should pass validation (min: $minLength, max: $maxLength)');
        }
      });

      /// Property Test: 太短的值应该被拒绝
      test('should reject values that are too short', () {
        for (var i = 0; i < 50; i++) {
          final minLength = random.nextInt(10) + 5;
          final length = random.nextInt(minLength);
          if (length == 0) continue; // 空值单独处理
          final value = randomString(length);

          final result = Validators.validateLength(value, minLength: minLength);
          expect(result, isNotNull,
              reason: 'Value of length $length should fail validation (min: $minLength)');
        }
      });

      /// Property Test: 太长的值应该被拒绝
      test('should reject values that are too long', () {
        for (var i = 0; i < 50; i++) {
          final maxLength = random.nextInt(10) + 5;
          final length = maxLength + random.nextInt(20) + 1;
          final value = randomString(length);

          final result = Validators.validateLength(value, maxLength: maxLength);
          expect(result, isNotNull,
              reason: 'Value of length $length should fail validation (max: $maxLength)');
        }
      });
    });
  });
}
