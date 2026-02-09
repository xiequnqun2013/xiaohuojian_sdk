import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// OSS 配置
class OSSConfig {
  final String bucket;
  final String endpoint;
  final String region;
  final String accessKeyId;
  final String accessKeySecret;
  final String? securityToken;
  final DateTime? expiration;

  const OSSConfig({
    required this.bucket,
    required this.endpoint,
    required this.region,
    required this.accessKeyId,
    required this.accessKeySecret,
    this.securityToken,
    this.expiration,
  });

  bool get isExpired {
    if (expiration == null) return false;
    // 提前 5 分钟认为过期
    return DateTime.now().isAfter(expiration!.subtract(const Duration(minutes: 5)));
  }

  factory OSSConfig.fromJson(Map<String, dynamic> json) {
    return OSSConfig(
      bucket: json['bucket'],
      endpoint: json['endpoint'],
      region: json['region'],
      accessKeyId: json['accessKeyId'],
      accessKeySecret: json['accessKeySecret'],
      securityToken: json['securityToken'],
      expiration: json['expiration'] != null 
          ? DateTime.parse(json['expiration']) 
          : null,
    );
  }
}

/// OSS 服务 - 处理云存储
class OSSService {
  static final OSSService _instance = OSSService._internal();
  factory OSSService() => _instance;
  OSSService._internal();

  OSSConfig? _config;
  final String _supabaseUrl = 'http://8.161.114.102:80';
  String? _jwtToken;

  /// 设置 JWT Token（登录后调用）
  void setJWT(String token) {
    _jwtToken = token;
  }

  /// 清除凭证（退出登录时调用）
  void clear() {
    _config = null;
    _jwtToken = null;
  }

  /// 获取 STS 临时凭证
  Future<void> _refreshCredentials({
    required String env,
    required String appSlug,
  }) async {
    if (_jwtToken == null) {
      throw Exception('未登录，无法获取 OSS 凭证');
    }

    final response = await http.post(
      Uri.parse('$_supabaseUrl/functions/v1/get-oss-sts'),
      headers: {
        'Authorization': 'Bearer $_jwtToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'env': env,
        'appSlug': appSlug,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('获取 STS 凭证失败: ${response.body}');
    }

    final data = jsonDecode(response.body);
    _config = OSSConfig.fromJson(data);
  }

  /// 确保凭证有效
  Future<void> _ensureCredentials({
    required String env,
    required String appSlug,
  }) async {
    if (_config == null || _config!.isExpired) {
      await _refreshCredentials(env: env, appSlug: appSlug);
    }
  }

  /// 生成存储路径
  String generatePath({
    required String userId,
    required String appSlug,
    required String filename,
    required String env,
  }) {
    return '$env/users/$userId/$appSlug/$filename';
  }

  /// 生成设备路径（未登录时使用）
  String generateDevicePath({
    required String deviceId,
    required String filename,
    required String env,
  }) {
    return '$env/devices/$deviceId/$filename';
  }

  /// 上传文件
  Future<void> upload({
    required String path,
    required List<int> bytes,
    required String env,
    required String appSlug,
    String? contentType,
  }) async {
    await _ensureCredentials(env: env, appSlug: appSlug);
    // 实际实现需要 crypto 包进行签名
    throw UnimplementedError('需要添加 crypto 包依赖');
  }

  /// 下载文件
  Future<List<int>> download({
    required String path,
    required String env,
    required String appSlug,
  }) async {
    await _ensureCredentials(env: env, appSlug: appSlug);
    throw UnimplementedError('需要添加 crypto 包依赖');
  }

  /// 检查文件是否存在
  Future<bool> exists({
    required String path,
    required String env,
    required String appSlug,
  }) async {
    try {
      await _ensureCredentials(env: env, appSlug: appSlug);
      throw UnimplementedError('需要添加 crypto 包依赖');
    } catch (e) {
      return false;
    }
  }

  /// 复制文件
  Future<void> copy({
    required String sourcePath,
    required String targetPath,
    required String env,
    required String appSlug,
  }) async {
    await _ensureCredentials(env: env, appSlug: appSlug);
    throw UnimplementedError('需要添加 crypto 包依赖');
  }
}

/// 全局快捷访问
OSSService get ossService => OSSService();
