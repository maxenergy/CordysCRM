import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_mode_provider.dart';
import '../../../data/repositories/auth_repository_impl.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../services/sync/api_client_monitor.dart';
import '../../../services/sync/dio_sync_api_client.dart';
import '../../../core/network/dio_client.dart';
import '../../../services/sync/sync_provider.dart';

/// 认证仓库 Provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl();
});

/// 模拟用户数据
const _mockUser = User(
  id: 1,
  username: 'admin',
  name: '管理员',
  email: 'admin@cordys.cn',
  phone: '13800138000',
  avatar: null,
  roles: ['admin'],
);

/// 认证状态
enum AuthStatus {
  initial,
  authenticated,
  unauthenticated,
  loading,
}

/// 认证状态类
class AuthState {
  final AuthStatus status;
  final User? user;
  final String? error;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.error,
  });

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? error,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
    );
  }
}

/// 认证状态 Notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  final Ref _ref;
  late final ApiClientMonitor _clientMonitor;

  AuthNotifier(this._repository, this._ref) : super(const AuthState()) {
    // Import sync_provider to access apiClientMonitorProvider
    _clientMonitor = _ref.read(apiClientMonitorProvider);
    _checkAuthStatus();
  }

  /// 检查认证状态
  Future<void> _checkAuthStatus() async {
    final isMockMode = _ref.read(isMockModeProvider);
    
    // 模拟模式下，默认未登录
    if (isMockMode) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }
    
    try {
      final isLoggedIn = await _repository.isLoggedIn();
      if (isLoggedIn) {
        final user = await _repository.getCurrentUser();
        state = AuthState(
          status: AuthStatus.authenticated,
          user: user,
        );
      } else {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    } catch (e) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  /// 登录
  Future<void> login(String username, String password) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    
    final isMockMode = _ref.read(isMockModeProvider);

    // 模拟模式登录
    if (isMockMode) {
      await Future.delayed(const Duration(milliseconds: 500)); // 模拟网络延迟
      
      if (username == 'admin' && password == 'admin123') {
        state = const AuthState(
          status: AuthStatus.authenticated,
          user: _mockUser,
        );
        return;
      } else {
        state = const AuthState(
          status: AuthStatus.unauthenticated,
          error: '用户名或密码错误（模拟模式：admin/admin123）',
        );
        throw Exception('用户名或密码错误');
      }
    }

    // 真实模式登录
    try {
      final user = await _repository.login(username, password);
      
      // Update ApiClientMonitor (Requirement 6.5)
      final syncClient = DioSyncApiClient(DioClient.instance);
      _clientMonitor.setClient(syncClient);
      
      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
      );
    } catch (e) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        error: e.toString(),
      );
      rethrow;
    }
  }

  /// 登出
  Future<void> logout() async {
    await _repository.logout();
    _clientMonitor.clearClient(); // Clear API client (Requirement 6.2)
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// 刷新 Token
  Future<void> refreshToken() async {
    try {
      await _repository.refreshToken();
    } catch (e) {
      // Token 刷新失败，登出
      await logout();
      rethrow;
    }
  }
}

/// 认证状态 Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthNotifier(repository, ref);
});

/// 当前用户 Provider
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authProvider).user;
});

/// 是否已登录 Provider
final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).status == AuthStatus.authenticated;
});
