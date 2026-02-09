/// 小火箭 SDK 全局配置
/// 
/// 修改此文件即可更新所有地方的配置
class RocketConfig {
  // ==================== Supabase 配置 ====================
  
  /// Supabase URL
  /// 
  /// 开发环境: http://rocketapi.lensflow.cn
  /// 生产环境: https://your-production-domain.com
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'http://rocketapi.lensflow.cn',
  );
  
  /// Supabase Anon Key (Public)
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNzcwNDQ0NjQ0LCJleHAiOjEzMjgxMDg0NjQ0fQ.b8jrVt73j4A3vlAN34TAntvPKy-9H3bMFdP37zux3pQ',
  );
  
  // ==================== OSS 配置 ====================
  
  /// OSS Bucket 名称
  static const String ossBucket = 'rocket-workshop';
  
  /// OSS Endpoint
  static const String ossEndpoint = 'oss-cn-beijing.aliyuncs.com';
  
  /// OSS Region
  static const String ossRegion = 'cn-beijing';
  
  /// OSS 访问域名
  static String get ossUrl => 'https://$ossBucket.$ossEndpoint';
  
  // ==================== 环境配置 ====================
  
  /// 当前环境
  /// 
  /// 通过 --dart-define=ENV=prod 传入
  static const String env = String.fromEnvironment('ENV', defaultValue: 'test');
  
  /// 是否测试环境
  static bool get isTest => env == 'test';
  
  /// 是否生产环境
  static bool get isProd => env == 'prod';
  
  /// 数据库 Schema
  static String get schema => isTest ? 'test_public' : 'public';
  
  /// OSS 路径前缀
  static String get ossPrefix => isTest ? 'test' : 'prod';
  
  // ==================== 应用配置 ====================
  
  /// 默认应用标识
  static const String defaultAppSlug = 'shenlun';
  
  /// 验证码有效期（秒）
  static const int smsCodeExpirySeconds = 60;
  
  /// STS 凭证有效期（秒）
  static const int stsExpirySeconds = 3600;
  
  // ==================== API 路径 ====================
  
  /// Edge Function 基础 URL
  static String get edgeFunctionUrl => '$supabaseUrl/functions/v1';
  
  /// REST API 基础 URL
  static String get restUrl => '$supabaseUrl/rest/v1';
  
  /// Auth API 基础 URL
  static String get authUrl => '$supabaseUrl/auth/v1';
}
