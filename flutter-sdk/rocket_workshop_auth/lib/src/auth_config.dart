import 'config.dart';

/// 认证配置
class AuthConfig {
  /// Supabase URL
  final String url;
  
  /// Supabase Anon Key
  final String anonKey;
  
  /// App ID（用于多 App 隔离）
  final String appId;
  
  /// 调试模式
  final bool debug;

  AuthConfig({
    String? url,
    String? anonKey,
    required this.appId,
    this.debug = false,
  }) : 
    url = url ?? RocketConfig.supabaseUrl,
    anonKey = anonKey ?? RocketConfig.supabaseAnonKey;

  /// 预发布环境配置
  factory AuthConfig.staging({
    required String appId,
  }) {
    return AuthConfig(
      appId: appId,
      debug: true,
    );
  }

  /// 生产环境配置
  factory AuthConfig.production({
    String? url,
    String? anonKey,
    required String appId,
  }) {
    return AuthConfig(
      url: url,
      anonKey: anonKey,
      appId: appId,
      debug: false,
    );
  }
}
