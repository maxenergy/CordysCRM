import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/providers/app_mode_provider.dart';
import '../../../core/services/login_settings_service.dart';
import '../../routing/app_router.dart';
import '../../theme/app_theme.dart';
import 'auth_provider.dart';

/// 登录页面
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _serverUrlController = TextEditingController();
  final _loginSettingsService = LoginSettingsService();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberPassword = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initSettings();
  }

  Future<void> _initSettings() async {
    await _loginSettingsService.init();
    
    // 加载服务器地址
    final serverUrl = _loginSettingsService.getServerUrl();
    _serverUrlController.text = serverUrl;
    DioClient.instance.updateBaseUrl(serverUrl);
    
    // 加载记住密码设置
    _rememberPassword = _loginSettingsService.getRememberPassword();
    
    // 如果记住密码，加载保存的凭据
    if (_rememberPassword) {
      final savedUsername = await _loginSettingsService.getSavedUsername();
      final savedPassword = await _loginSettingsService.getSavedPassword();
      if (savedUsername != null) {
        _usernameController.text = savedUsername;
      }
      if (savedPassword != null) {
        _passwordController.text = savedPassword;
      }
    } else if (kDebugMode) {
      // 开发模式下预填用户名和密码
      _usernameController.text = 'admin';
      _passwordController.text = 'admin123';
    }
    
    setState(() => _isInitialized = true);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _serverUrlController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 保存服务器地址
      await _loginSettingsService.setServerUrl(_serverUrlController.text.trim());
      DioClient.instance.updateBaseUrl(_serverUrlController.text.trim());
      
      // 保存记住密码设置
      await _loginSettingsService.setRememberPassword(_rememberPassword);
      
      // 如果记住密码，保存凭据
      if (_rememberPassword) {
        await _loginSettingsService.saveCredentials(
          _usernameController.text.trim(),
          _passwordController.text,
        );
      }
      
      await ref.read(authProvider.notifier).login(
        _usernameController.text.trim(),
        _passwordController.text,
      );
      
      if (mounted) {
        context.go(AppRoutes.home);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('登录失败: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showServerSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('服务器设置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _serverUrlController,
              decoration: const InputDecoration(
                labelText: '服务器地址',
                hintText: 'http://192.168.1.226:8081',
                prefixIcon: Icon(Icons.dns_outlined),
                helperText: '输入服务器IP地址或域名',
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final url = _serverUrlController.text.trim();
              if (url.isNotEmpty) {
                await _loginSettingsService.setServerUrl(url);
                DioClient.instance.updateBaseUrl(url);
                if (!context.mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('服务器地址已保存')),
                );
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: _showServerSettingsDialog,
            tooltip: '服务器设置',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                
                // Logo
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.business,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // 标题
                const Text(
                  'CordysCRM',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                const Text(
                  '客户关系管理系统',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // 服务器地址显示
                GestureDetector(
                  onTap: _showServerSettingsDialog,
                  child: Text(
                    '服务器: ${_serverUrlController.text}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textTertiary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // 用户名输入框
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: '用户名',
                    hintText: '请输入用户名',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入用户名';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                // 密码输入框
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: '密码',
                    hintText: '请输入密码',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _handleLogin(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入密码';
                    }
                    if (value.length < 6) {
                      return '密码长度不能少于6位';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                // 记住密码
                Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _rememberPassword,
                        onChanged: (value) {
                          setState(() => _rememberPassword = value ?? false);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '记住密码',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        // TODO: 忘记密码
                      },
                      child: const Text('忘记密码？'),
                    ),
                  ],
                ),
                
                const SizedBox(height: 32),
                
                // 登录按钮
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('登录'),
                ),
                
                const SizedBox(height: 16),
                
                // 模拟模式开关
                Consumer(
                  builder: (context, ref, child) {
                    final isMockMode = ref.watch(isMockModeProvider);
                    return SwitchListTile(
                      title: const Text(
                        '演示模式',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        isMockMode ? '使用模拟数据（admin/admin123）' : '连接真实服务器',
                        style: const TextStyle(
                          color: AppTheme.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                      value: isMockMode,
                      onChanged: (value) {
                        ref.read(isMockModeProvider.notifier).state = value;
                      },
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    );
                  },
                ),
                
                const SizedBox(height: 16),
                
                // 版本信息
                const Text(
                  'v1.0.0',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
