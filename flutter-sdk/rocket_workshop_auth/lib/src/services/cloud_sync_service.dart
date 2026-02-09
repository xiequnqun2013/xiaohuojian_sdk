import 'dart:convert';

import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';
import 'oss_service.dart';
import 'purchase_service.dart';

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

/// 同步结果
class SyncResult {
  final bool success;
  final String? error;
  final DateTime? timestamp;
  final String? path;
  final int? bytesTransferred;

  SyncResult({
    required this.success,
    this.error,
    this.timestamp,
    this.path,
    this.bytesTransferred,
  });

  factory SyncResult.success({
    String? path,
    int? bytesTransferred,
  }) {
    return SyncResult(
      success: true,
      timestamp: DateTime.now(),
      path: path,
      bytesTransferred: bytesTransferred,
    );
  }

  factory SyncResult.failure(String error) {
    return SyncResult(
      success: false,
      error: error,
      timestamp: DateTime.now(),
    );
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

    // 设置 OSS Service 的 JWT
    final jwt = Supabase.instance.client.auth.currentSession?.accessToken;
    if (jwt != null) {
      ossService.setJWT(jwt);
      purchaseService.setJWT(jwt);
    }

    if (kDebugMode) {
      debugPrint('☁️ CloudSyncService 已初始化');
      debugPrint('   环境: ${_config.env}');
      debugPrint('   应用: ${_config.appSlug}');
      debugPrint('   设备: ${_config.deviceId}');
    }
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

  /// 更新 JWT Token（登录后调用）
  void updateJWT(String token) {
    ossService.setJWT(token);
    purchaseService.setJWT(token);
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

  /// 上传文件
  ///
  /// [bytes] 文件内容
  /// [filename] 可选的文件名，默认使用初始化时的路径
  Future<SyncResult> uploadFile(List<int> bytes, {String? filename}) async {
    if (!_initialized) {
      return SyncResult.failure('CloudSyncService 未初始化');
    }

    final path = filename != null
        ? (isLoggedIn ? generateUserPath(filename) : generateDevicePath(filename))
        : currentPath;

    if (kDebugMode) {
      debugPrint('☁️ 上传到: $path');
      debugPrint('   大小: ${bytes.length} bytes');
    }

    try {
      final result = await ossService.upload(
        path: path,
        bytes: bytes,
        env: _config.env,
        appSlug: _config.appSlug,
        contentType: 'application/octet-stream',
      );

      if (result.success) {
        if (kDebugMode) {
          debugPrint('✅ 上传成功');
        }
        return SyncResult.success(
          path: path,
          bytesTransferred: bytes.length,
        );
      } else {
        return SyncResult.failure(result.error ?? '上传失败');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 上传失败: $e');
      }
      return SyncResult.failure('上传失败: $e');
    }
  }

  /// 下载文件
  ///
  /// 返回文件内容，如果文件不存在返回 null
  Future<List<int>?> downloadFile() async {
    if (!_initialized) {
      throw Exception('CloudSyncService 未初始化');
    }

    final path = currentPath;

    if (kDebugMode) {
      debugPrint('☁️ 下载自: $path');
    }

    try {
      final bytes = await ossService.download(
        path: path,
        env: _config.env,
        appSlug: _config.appSlug,
      );

      if (kDebugMode) {
        debugPrint('✅ 下载成功: ${bytes.length} bytes');
      }

      return bytes;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ 下载失败: $e');
      }
      return null;
    }
  }

  /// 检查云端是否存在数据
  Future<bool> checkCloudDataExists() async {
    if (!_initialized) {
      return false;
    }

    final path = currentPath;

    if (kDebugMode) {
      debugPrint('☁️ 检查云端数据: $path');
    }

    try {
      final exists = await ossService.exists(
        path: path,
        env: _config.env,
        appSlug: _config.appSlug,
      );

      if (kDebugMode) {
        debugPrint(exists ? '✅ 云端数据存在' : '❌ 云端数据不存在');
      }

      return exists;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ 检查失败: $e');
      }
      return false;
    }
  }

  /// 检查指定用户是否有云端数据
  Future<bool> checkUserCloudDataExists(String userId) async {
    if (!_initialized) {
      return false;
    }

    final path = '${_config.env}/users/$userId/${_config.appSlug}/user_data.db';

    if (kDebugMode) {
      debugPrint('☁️ 检查用户云端数据: $path');
    }

    try {
      final exists = await ossService.exists(
        path: path,
        env: _config.env,
        appSlug: _config.appSlug,
      );

      if (kDebugMode) {
        debugPrint(exists ? '✅ 用户云端数据存在' : '❌ 用户云端数据不存在');
      }

      return exists;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ 检查失败: $e');
      }
      return false;
    }
  }

  /// 数据迁移（设备 → 用户）
  ///
  /// 将设备数据复制到用户路径
  Future<SyncResult> migrateDeviceToUser() async {
    if (!_initialized) {
      return SyncResult.failure('CloudSyncService 未初始化');
    }

    if (!isLoggedIn) {
      return SyncResult.failure('未登录，无法迁移');
    }

    final userId = currentUserId!;
    final devicePath = generateDevicePath('user_data.db');
    final userPath = generateUserPath('user_data.db');

    if (kDebugMode) {
      debugPrint('🔄 数据迁移:');
      debugPrint('   来源: $devicePath');
      debugPrint('   目标: $userPath');
    }

    try {
      // 1. 检查设备数据是否存在
      final deviceExists = await ossService.exists(
        path: devicePath,
        env: _config.env,
        appSlug: _config.appSlug,
      );

      if (!deviceExists) {
        // 没有设备数据，直接切换到用户路径
        if (kDebugMode) {
          debugPrint('⚠️ 没有设备数据，直接切换到用户路径');
        }
        switchToUserPath(userId);
        return SyncResult.success(path: userPath);
      }

      // 2. 检查用户路径是否已有数据
      final userExists = await ossService.exists(
        path: userPath,
        env: _config.env,
        appSlug: _config.appSlug,
      );

      if (userExists) {
        // 需要合并数据
        if (kDebugMode) {
          debugPrint('⚠️ 用户路径已有数据，需要合并');
        }
        await mergeMultiDeviceData(userId);
      } else {
        // 直接复制设备数据到用户路径
        if (kDebugMode) {
          debugPrint('📤 复制设备数据到用户路径...');
        }
        await ossService.copy(
          sourcePath: devicePath,
          targetPath: userPath,
          env: _config.env,
          appSlug: _config.appSlug,
        );
      }

      // 3. 切换到用户路径
      switchToUserPath(userId);

      // 4. 记录到数据库
      await Supabase.instance.client.from('user_devices').upsert({
        'device_id': _config.deviceId,
        'user_id': userId,
        'app_slug': _config.appSlug,
        'is_migrated': true,
        'migrated_at': DateTime.now().toIso8601String(),
      });

      if (kDebugMode) {
        debugPrint('✅ 数据迁移完成');
      }

      return SyncResult.success(path: userPath);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 迁移失败: $e');
      }
      return SyncResult.failure('迁移失败: $e');
    }
  }

  /// 全量数据迁移（文件 + 购买记录）
  /// 
  /// [receipt] 可选：如果有本地收据，尝试迁移购买记录
  Future<SyncResult> migrateAllData({String? receipt}) async {
    if (!_initialized) return SyncResult.failure('CloudSyncService 未初始化');
    if (!isLoggedIn) return SyncResult.failure('未登录');

    final userId = currentUserId!;
    final List<String> errors = [];

    // 1. 迁移文件
    try {
      final fileResult = await migrateDeviceToUser();
      if (!fileResult.success) {
        errors.add('文件迁移失败: ${fileResult.error}');
      }
    } catch (e) {
      errors.add('文件迁移异常: $e');
    }

    // 2. 迁移购买记录 (如果有)
    if (receipt != null && receipt.isNotEmpty) {
      try {
        await purchaseService.migratePurchase(
          receipt: receipt,
          deviceId: _config.deviceId,
          userId: userId,
          appSlug: _config.appSlug,
        );
      } catch (e) {
        errors.add('购买迁移失败: $e');
      }
    }

    if (errors.isEmpty) {
      return SyncResult.success(path: generateUserPath('user_data.db'));
    } else {
      return SyncResult.failure(errors.join('; '));
    }
  }

  /// 多端数据合并
  ///
  /// 当用户已有其他设备数据时，合并当前设备数据
  Future<SyncResult> mergeMultiDeviceData(String userId) async {
    if (kDebugMode) {
      debugPrint('🔄 合并多设备数据...');
    }

    try {
      // 1. 查询该用户的所有设备
      final devices = await Supabase.instance.client
          .from('user_devices')
          .select('device_id')
          .eq('user_id', userId)
          .eq('app_slug', _config.appSlug);

      if (kDebugMode) {
        debugPrint('   找到 ${devices.length} 个设备');
      }

      // 2. 下载当前设备的数据
      final currentDevicePath = generateDevicePath('user_data.db');
      final currentData = await ossService.download(
        path: currentDevicePath,
        env: _config.env,
        appSlug: _config.appSlug,
      );

      // 3. 下载用户路径的数据（如果有）
      final userPath = generateUserPath('user_data.db');
      List<int>? userData;
      try {
        userData = await ossService.download(
          path: userPath,
          env: _config.env,
          appSlug: _config.appSlug,
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('   用户路径暂无数据');
        }
      }

      // 4. 合并数据（简单策略：保留最新）
      // 实际项目中需要根据业务逻辑实现更复杂的合并
      List<int> mergedData;
      if (userData != null && currentData.isNotEmpty) {
        // 这里简化处理：如果用户路径有数据，保留用户路径的数据
        // 实际应该根据时间戳或业务规则合并
        if (kDebugMode) {
          debugPrint('   合并数据: 用户数据 ${userData.length} bytes, 当前设备 ${currentData.length} bytes');
        }
        // 暂时保留用户路径的数据
        mergedData = userData;
      } else if (userData != null) {
        mergedData = userData;
      } else {
        mergedData = currentData;
      }

      // 5. 上传合并后的数据到用户路径
      await ossService.upload(
        path: userPath,
        bytes: mergedData,
        env: _config.env,
        appSlug: _config.appSlug,
      );

      if (kDebugMode) {
        debugPrint('✅ 数据合并完成');
      }

      return SyncResult.success(
        path: userPath,
        bytesTransferred: mergedData.length,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 合并失败: $e');
      }
      return SyncResult.failure('合并失败: $e');
    }
  }

  /// 从用户路径恢复数据（新设备登录后）
  ///
  /// 下载用户路径的数据到本地
  Future<SyncResult> restoreFromUserPath() async {
    if (!_initialized) {
      return SyncResult.failure('CloudSyncService 未初始化');
    }

    if (!isLoggedIn) {
      return SyncResult.failure('未登录，无法恢复数据');
    }

    final userId = currentUserId!;
    final userPath = generateUserPath('user_data.db');

    if (kDebugMode) {
      debugPrint('📥 从用户路径恢复数据: $userPath');
    }

    try {
      // 检查用户路径是否有数据
      final exists = await ossService.exists(
        path: userPath,
        env: _config.env,
        appSlug: _config.appSlug,
      );

      if (!exists) {
        return SyncResult.failure('用户路径没有数据');
      }

      // 下载数据
      final bytes = await ossService.download(
        path: userPath,
        env: _config.env,
        appSlug: _config.appSlug,
      );

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

      if (kDebugMode) {
        debugPrint('✅ 数据恢复成功: ${bytes.length} bytes');
      }

      return SyncResult.success(
        path: userPath,
        bytesTransferred: bytes.length,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 恢复失败: $e');
      }
      return SyncResult.failure('恢复失败: $e');
    }
  }

  /// 删除设备数据
  Future<SyncResult> deleteDeviceData() async {
    if (!_initialized) {
      return SyncResult.failure('CloudSyncService 未初始化');
    }

    final devicePath = generateDevicePath('user_data.db');

    if (kDebugMode) {
      debugPrint('🗑️ 删除设备数据: $devicePath');
    }

    try {
      await ossService.delete(
        path: devicePath,
        env: _config.env,
        appSlug: _config.appSlug,
      );

      if (kDebugMode) {
        debugPrint('✅ 设备数据已删除');
      }

      return SyncResult.success(path: devicePath);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 删除失败: $e');
      }
      return SyncResult.failure('删除失败: $e');
    }
  }

  /// 获取同步状态信息
  Map<String, dynamic> getSyncStatus() {
    if (!_initialized) {
      return {'error': '未初始化'};
    }

    return {
      'initialized': _initialized,
      'isLoggedIn': isLoggedIn,
      'currentUserId': currentUserId,
      'currentPath': currentPath,
      'deviceId': _config.deviceId,
      'appSlug': _config.appSlug,
      'env': _config.env,
    };
  }
}

/// 全局快捷访问
CloudSyncService get cloudSync => CloudSyncService();
