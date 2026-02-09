import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// 云同步配置
class CloudSyncConfig {
  final String env;
  final String appSlug;
  final String deviceId;
  
  const CloudSyncConfig({
    required this.env,
    required this.appSlug,
    required this.deviceId,
  });
}

/// OSS 凭证
class OSSCredentials {
  final String accessKeyId;
  final String accessKeySecret;
  final String? securityToken;
  final DateTime? expiration;
  final String bucket;
  final String endpoint;
  final String region;
  final String pathPrefix;

  OSSCredentials({
    required this.accessKeyId,
    required this.accessKeySecret,
    this.securityToken,
    this.expiration,
    required this.bucket,
    required this.endpoint,
    required this.region,
    required this.pathPrefix,
  });

  bool get isExpired {
    if (expiration == null) return false;
    return DateTime.now().isAfter(expiration!.subtract(const Duration(minutes: 5)));
  }
}

/// 云同步服务 - 核心类
class CloudSyncService {
  static final CloudSyncService _instance = CloudSyncService._internal();
  factory CloudSyncService() => _instance;
  CloudSyncService._internal();

  late final CloudSyncConfig _config;
  bool _initialized = false;
  
  // 当前存储路径
  String? _currentPath;
  String? _userId;

  /// 初始化
  void initialize(CloudSyncConfig config) {
    _config = config;
    _initialized = true;
    
    // 设置默认路径为设备路径
    _currentPath = generateDevicePath('user_data.db');
  }

  /// 获取当前用户 ID（登录后）
  String? get currentUserId => Supabase.instance.client.auth.currentUser?.id;

  /// 是否已登录
  bool get isLoggedIn => currentUserId != null;

  /// 获取当前存储路径
  String get currentPath {
    if (isLoggedIn && _userId != null) {
      return generateUserPath('user_data.db');
    }
    return _currentPath ?? generateDevicePath('user_data.db');
  }

  /// 生成设备路径（未登录）
  String generateDevicePath(String filename) {
    return '${_config.env}/devices/${_config.deviceId}/${_config.appSlug}/$filename';
  }

  /// 生成用户路径（已登录）
  String generateUserPath(String filename) {
    final userId = currentUserId ?? _userId;
    if (userId == null) {
      throw Exception('未登录，无法生成用户路径');
    }
    return '${_config.env}/users/$userId/${_config.appSlug}/$filename';
  }

  /// 获取 OSS 配置（使用 SQL 函数替代 Edge Function）
  Future<Map<String, dynamic>> getOSSConfig() async {
    final response = await Supabase.instance.client
        .rpc('get_oss_sts_http', params: {
          'env': _config.env,
          'app_slug': _config.appSlug,
        });

    if (response == null) {
      throw Exception('获取 OSS 配置失败');
    }

    if (response['error'] != null) {
      throw Exception(response['error']);
    }

    return response;
  }

  /// 切换到用户路径（登录后调用）
  void switchToUserPath(String userId) {
    _userId = userId;
    _currentPath = generateUserPath('user_data.db');
    
    if (kDebugMode) {
      debugPrint('☁️ 切换到用户路径: $_currentPath');
    }
  }

  /// 切换回设备路径（登出后调用）
  void switchToDevicePath() {
    _userId = null;
    _currentPath = generateDevicePath('user_data.db');
    
    if (kDebugMode) {
      debugPrint('📱 切换回设备路径: $_currentPath');
    }
  }

  /// 上传文件（占位实现）
  Future<void> uploadFile(List<int> bytes, {String? filename}) async {
    if (!_initialized) {
      throw Exception('CloudSyncService 未初始化');
    }

    final path = filename != null 
        ? (isLoggedIn ? generateUserPath(filename) : generateDevicePath(filename))
        : currentPath;

    if (kDebugMode) {
      debugPrint('☁️ 上传到: $path');
    }

    // TODO: 实际 OSS 上传实现
    // 1. 获取 STS 凭证
    // 2. 使用阿里云 OSS SDK 上传
    
    throw UnimplementedError('OSS 上传功能待实现');
  }

  /// 下载文件（占位实现）
  Future<List<int>> downloadFile() async {
    if (!_initialized) {
      throw Exception('CloudSyncService 未初始化');
    }

    final path = currentPath;

    if (kDebugMode) {
      debugPrint('☁️ 下载自: $path');
    }

    // TODO: 实际 OSS 下载实现
    throw UnimplementedError('OSS 下载功能待实现');
  }

  /// 检查云端是否存在数据
  Future<bool> checkCloudDataExists() async {
    // TODO: 实现 OSS 文件存在检查
    return false;
  }

  /// 数据迁移（设备 → 用户）
  Future<void> migrateDeviceToUser() async {
    if (!isLoggedIn) {
      throw Exception('未登录，无法迁移');
    }

    final userId = currentUserId!;
    final devicePath = generateDevicePath('user_data.db');
    final userPath = generateUserPath('user_data.db');

    if (kDebugMode) {
      debugPrint('🔄 数据迁移:');
      debugPrint('   来源: $devicePath');
      debugPrint('   目标: $userPath');
    }

    // TODO: 实际迁移逻辑
    // 1. 下载设备数据
    // 2. 上传到用户路径
    // 3. 记录迁移标记

    // 切换到用户路径
    switchToUserPath(userId);

    // 记录到数据库
    await Supabase.instance.client.from('user_devices').upsert({
      'device_id': _config.deviceId,
      'user_id': userId,
      'app_slug': _config.appSlug,
      'is_migrated': true,
      'migrated_at': DateTime.now().toIso8601String(),
    });
  }

  /// 多端数据合并
  Future<void> mergeMultiDeviceData(String userId) async {
    if (kDebugMode) {
      debugPrint('🔄 合并多设备数据...');
    }

    // TODO: 实现数据合并逻辑
    // 1. 查询该用户的所有设备
    // 2. 下载各设备数据
    // 3. 按业务规则合并
    // 4. 上传合并后的数据
  }
}

/// 全局快捷访问
CloudSyncService get cloudSync => CloudSyncService();
