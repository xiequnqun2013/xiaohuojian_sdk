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
    required this.url,
    required this.anonKey,
    required this.appId,
    this.debug = false,
  });

  /// 预发布环境配置
  factory AuthConfig.staging({
    required String appId,
  }) {
    return AuthConfig(
      url: 'http://rocketapi.lensflow.cn',
      anonKey: 'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNzcwNDQ0NjQ0LCJleHAiOjEzMjgxMDg0NjQ0fQ.b8jrVt73j4A3vlAN34TAntvPKy-9H3bMFdP37zux3pQ',
      appId: appId,
      debug: true,
    );
  }

  /// 生产环境配置
  factory AuthConfig.production({
    required String url,
    required String anonKey,
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
