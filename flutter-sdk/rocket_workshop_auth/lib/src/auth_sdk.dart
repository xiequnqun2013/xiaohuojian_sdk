import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_config.dart';
import 'models/user_profile.dart';
import 'services/oss_service.dart';
import 'services/cloud_sync_service.dart';

/// 认证结果
class AuthResult<T> {
  final T? data;
  final String? error;
  final bool success;

  AuthResult._({this.data, this.error, required this.success});

  factory AuthResult.success(T data) => AuthResult._(data: data, success: true);
  factory AuthResult.failure(String error) => AuthResult._(error: error, success: false);
}

/// Rocket Workshop 认证 SDK
class RocketWorkshopAuth {
  static final RocketWorkshopAuth _instance = RocketWorkshopAuth._internal();
  factory RocketWorkshopAuth() => _instance;
  RocketWorkshopAuth._internal();

  late final AuthConfig _config;
  bool _initialized = false;

  /// 初始化 SDK
  Future<void> initialize(AuthConfig config) async {
    if (_initialized) {
      if (kDebugMode) {
        debugPrint('RocketWorkshopAuth already initialized, skipping');
      }
      return;
    }

    _config = config;

    await Supabase.initialize(
      url: config.url,
      anonKey: config.anonKey,
      debug: config.debug,
    );

    _initialized = true;

    if (config.debug) {
      debugPrint('RocketWorkshopAuth initialized');
      debugPrint('App ID: ${config.appId}');
    }
  }

  SupabaseClient get _client => Supabase.instance.client;

  /// ========== 短信登录 ==========

  /// 发送短信验证码
  /// 
  /// [phone] 手机号（不需要 +86 前缀）
  Future<AuthResult<void>> sendSMSCode(String phone) async {
    try {
      final fullPhone = _formatPhone(phone);

      await _client.auth.signInWithOtp(
        phone: fullPhone,
      );

      return AuthResult.success(null);
    } on AuthException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      return AuthResult.failure('发送失败: $e');
    }
  }

  /// 验证短信验证码并登录
  /// 
  /// [phone] 手机号
  /// [code] 6位验证码
  Future<AuthResult<User>> verifySMSCode(String phone, String code) async {
    try {
      final fullPhone = _formatPhone(phone);

      final response = await _client.auth.verifyOTP(
        phone: fullPhone,
        token: code,
        type: OtpType.sms,
      );

      if (response.user == null) {
        return AuthResult.failure('登录失败');
      }

      // 记录用户关联到当前 App
      await _associateUserWithApp(response.user!.id);

      // 更新 OSS Service 的 JWT
      final jwt = response.session?.accessToken;
      if (jwt != null) {
        ossService.setJWT(jwt);
        cloudSync.updateJWT(jwt);
      }

      return AuthResult.success(response.user!);
    } on AuthException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      return AuthResult.failure('验证失败: $e');
    }
  }

  /// 匿名登录 (仅测试用)
  Future<AuthResult<User>> signInAnonymously() async {
    try {
      final response = await _client.auth.signInAnonymously();
      
      if (response.user == null) {
        return AuthResult.failure('登录失败');
      }

      // 更新 JWT
      final jwt = response.session?.accessToken;
      if (jwt != null) {
        ossService.setJWT(jwt);
        // cloudSync.updateJWT is handled by onAuthStateChange listener
      }

      return AuthResult.success(response.user!);
    } on AuthException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      return AuthResult.failure('匿名登录失败: $e');
    }
  }

  /// 调试登录 (仅测试用)
  /// 
  /// 绕过短信验证，直接使用手机号登录
  Future<AuthResult<User>> signInWithDebugPhone(String phone) async {
    try {
      // 调用 Edge Function
      final response = await http.post(
        Uri.parse('${_config.url}/functions/v1/debug-login'),
        headers: {
          'Authorization': 'Bearer ${_config.anonKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'phone': phone}),
      );

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body)['error'] ?? '调试登录失败';
        return AuthResult.failure(error);
      }

      final data = jsonDecode(response.body);
      final session = data['session'];
      
      if (session == null || session['refresh_token'] == null) {
        return AuthResult.failure('未返回有效会话');
      }

      // 设置 Supabase 会话
      final authResponse = await _client.auth.setSession(session['refresh_token']);
      
      if (authResponse.user == null) {
        return AuthResult.failure('设置会话失败');
      }

      // 更新 JWT (onAuthStateChange 会自动处理，但为了保险起见也可以手动设置)
      // onAuthStateChange handles it.

      return AuthResult.success(authResponse.user!);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('调试登录异常: $e');
      }
      return AuthResult.failure('调试登录异常: $e');
    }
  }

  /// ========== 用户信息 ==========

  /// 获取当前登录用户
  User? get currentUser => _client.auth.currentUser;

  /// 是否已登录
  bool get isLoggedIn => currentUser != null;

  /// 监听登录状态变化
  Stream<AuthState> get onAuthStateChange {
    return _client.auth.onAuthStateChange.map((state) {
      // 自动更新 JWT Token
      final session = state.session;
      if (session != null) {
        ossService.setJWT(session.accessToken);
        cloudSync.updateJWT(session.accessToken);
      } else {
        ossService.clear();
      }
      return state;
    });
  }

  /// 获取用户资料
  Future<AuthResult<UserProfile>> getProfile() async {
    try {
      final user = currentUser;
      if (user == null) {
        return AuthResult.failure('未登录');
      }

      final response = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (response == null) {
        return AuthResult.failure('用户资料不存在');
      }

      final profile = UserProfile.fromJson(response);
      return AuthResult.success(profile);
    } on PostgrestException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      return AuthResult.failure('获取资料失败: $e');
    }
  }

  /// 更新用户资料
  Future<AuthResult<void>> updateProfile({
    String? nickname,
    String? avatarUrl,
  }) async {
    try {
      final user = currentUser;
      if (user == null) {
        return AuthResult.failure('未登录');
      }

      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (nickname != null) updates['nickname'] = nickname;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

      await _client
          .from('profiles')
          .update(updates)
          .eq('id', user.id);

      return AuthResult.success(null);
    } on PostgrestException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      return AuthResult.failure('更新失败: $e');
    }
  }

  /// ========== 退出登录 ==========

  /// 退出登录
  Future<AuthResult<void>> signOut() async {
    try {
      await _client.auth.signOut();
      // 清除 OSS Service 的 JWT
      ossService.clear();
      return AuthResult.success(null);
    } on AuthException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      return AuthResult.failure('退出失败: $e');
    }
  }

  /// ========== 工具方法 ==========

  /// 格式化手机号（自动添加 +86）
  String _formatPhone(String phone) {
    if (phone.startsWith('+')) return phone;
    return '+86$phone';
  }

  /// 将用户关联到当前 App
  Future<void> _associateUserWithApp(String userId) async {
    try {
      await _client.from('user_apps').upsert({
        'user_id': userId,
        'app_id': _config.appId,
      });
    } catch (e) {
      // 静默处理，不影响登录流程
      if (_config.debug) {
        debugPrint('Associate user with app failed: $e');
      }
    }
  }
}

/// 全局快捷访问
RocketWorkshopAuth get authSDK => RocketWorkshopAuth();
