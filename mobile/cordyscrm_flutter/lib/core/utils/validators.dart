/// 表单验证工具类
///
/// 提供统一的表单验证规则，确保 Flutter App 和 Web 端使用相同的验证逻辑。
class Validators {
  Validators._();

  /// 中国大陆手机号正则表达式
  static final _phoneRegExp = RegExp(r'^1[3-9]\d{9}$');

  /// 邮箱正则表达式
  static final _emailRegExp = RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$');

  /// 企业名称正则表达式（2-50个字符）
  static final _companyNameRegExp = RegExp(r'^.{2,50}$');

  /// 统一社会信用代码正则表达式（18位）
  static final _creditCodeRegExp = RegExp(r'^[0-9A-Z]{18}$');

  /// 验证手机号
  ///
  /// 返回 null 表示验证通过，返回错误信息表示验证失败。
  /// 空值被视为有效（非必填字段）。
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) return null;
    if (!_phoneRegExp.hasMatch(value)) {
      return '请输入有效的手机号码';
    }
    return null;
  }

  /// 验证邮箱
  ///
  /// 返回 null 表示验证通过，返回错误信息表示验证失败。
  /// 空值被视为有效（非必填字段）。
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) return null;
    if (!_emailRegExp.hasMatch(value)) {
      return '请输入有效的邮箱地址';
    }
    return null;
  }

  /// 验证必填字段
  ///
  /// 返回 null 表示验证通过，返回错误信息表示验证失败。
  static String? validateRequired(String? value, {String fieldName = '此字段'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName不能为空';
    }
    return null;
  }

  /// 验证企业名称
  ///
  /// 企业名称必须为 2-50 个字符。
  static String? validateCompanyName(String? value) {
    if (value == null || value.isEmpty) {
      return '企业名称不能为空';
    }
    if (!_companyNameRegExp.hasMatch(value)) {
      return '企业名称长度应为2-50个字符';
    }
    return null;
  }

  /// 验证统一社会信用代码
  ///
  /// 统一社会信用代码必须为 18 位数字和大写字母组合。
  static String? validateCreditCode(String? value) {
    if (value == null || value.isEmpty) {
      return '统一社会信用代码不能为空';
    }
    if (!_creditCodeRegExp.hasMatch(value)) {
      return '请输入有效的18位统一社会信用代码';
    }
    return null;
  }

  /// 验证字符串长度
  static String? validateLength(
    String? value, {
    int? minLength,
    int? maxLength,
    String fieldName = '此字段',
  }) {
    if (value == null || value.isEmpty) return null;
    if (minLength != null && value.length < minLength) {
      return '$fieldName长度不能少于$minLength个字符';
    }
    if (maxLength != null && value.length > maxLength) {
      return '$fieldName长度不能超过$maxLength个字符';
    }
    return null;
  }

  /// 检查手机号格式是否有效（不返回错误信息）
  static bool isValidPhone(String? value) {
    if (value == null || value.isEmpty) return false;
    return _phoneRegExp.hasMatch(value);
  }

  /// 检查邮箱格式是否有效（不返回错误信息）
  static bool isValidEmail(String? value) {
    if (value == null || value.isEmpty) return false;
    return _emailRegExp.hasMatch(value);
  }

  /// 检查统一社会信用代码格式是否有效（不返回错误信息）
  static bool isValidCreditCode(String? value) {
    if (value == null || value.isEmpty) return false;
    return _creditCodeRegExp.hasMatch(value);
  }
}
