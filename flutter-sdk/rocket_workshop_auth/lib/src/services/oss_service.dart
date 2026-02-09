import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import '../config.dart';

// ... (existing code)



/// OSS 配置
class OSSConfig {
  final String bucket;
  final String endpoint;
  final String region;
  final String accessKeyId;
  final String accessKeySecret;
  final String? securityToken;
  final DateTime? expiration;
  final String pathPrefix;

  const OSSConfig({
    required this.bucket,
    required this.endpoint,
    required this.region,
    required this.accessKeyId,
    required this.accessKeySecret,
    this.securityToken,
    this.expiration,
    required this.pathPrefix,
  });

  bool get isExpired {
    if (expiration == null) return false;
    // 提前 5 分钟认为过期
    return DateTime.now().isAfter(expiration!.subtract(const Duration(minutes: 5)));
  }

  factory OSSConfig.fromJson(Map<String, dynamic> json) {
    return OSSConfig(
      bucket: json['bucket'] ?? '',
      endpoint: json['endpoint'] ?? '',
      region: json['region'] ?? '',
      accessKeyId: json['accessKeyId'] ?? '',
      accessKeySecret: json['accessKeySecret'] ?? '',
      securityToken: json['securityToken'],
      expiration: json['expiration'] != null
          ? DateTime.parse(json['expiration'])
          : null,
      pathPrefix: json['pathPrefix'] ?? json['path'] ?? '',
    );
  }
}

/// OSS 上传结果
class OSSUploadResult {
  final bool success;
  final String? url;
  final String? error;
  final String etag;

  OSSUploadResult({
    required this.success,
    this.url,
    this.error,
    this.etag = '',
  });
}

/// OSS 服务 - 处理云存储
class OSSService {
  static final OSSService _instance = OSSService._internal();
  factory OSSService() => _instance;
  OSSService._internal();

  OSSConfig? _config;
  final String _supabaseUrl = RocketConfig.supabaseUrl;
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

    // 检查是否返回了错误
    if (data['error'] != null) {
      throw Exception('获取 STS 凭证失败: ${data['error']}');
    }

    _config = OSSConfig.fromJson(data);

    if (kDebugMode) {
      debugPrint('🔑 STS 凭证已刷新，过期时间: ${_config?.expiration}');
    }
  }

  /// 使用 SQL 函数获取 OSS 配置（备用方案）
  Future<void> _refreshCredentialsViaSQL({
    required String env,
    required String appSlug,
  }) async {
    if (_jwtToken == null) {
      throw Exception('未登录，无法获取 OSS 凭证');
    }

    final response = await http.post(
      Uri.parse('$_supabaseUrl/rest/v1/rpc/get_oss_sts_http'),
      headers: {
        'Authorization': 'Bearer $_jwtToken',
        'Content-Type': 'application/json',
        'apikey': RocketConfig.supabaseAnonKey,
      },
      body: jsonEncode({
        'env': env,
        'app_slug': appSlug,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('获取 OSS 配置失败: ${response.body}');
    }

    final data = jsonDecode(response.body);

    if (data['error'] != null) {
      throw Exception('获取 OSS 配置失败: ${data['error']}');
    }

    _config = OSSConfig.fromJson(data);

    if (kDebugMode) {
      debugPrint('🔑 OSS 配置已获取');
    }
  }

  /// 确保凭证有效
  Future<void> _ensureCredentials({
    required String env,
    required String appSlug,
  }) async {
    if (_config == null || _config!.isExpired) {
      try {
        // 先尝试 Edge Function
        await _refreshCredentials(env: env, appSlug: appSlug);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ Edge Function 失败，使用 SQL 备用方案: $e');
        }
        // 如果 Edge Function 失败，使用 SQL 函数
        await _refreshCredentialsViaSQL(env: env, appSlug: appSlug);
      }
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

  /// 生成签名
  /// 参考阿里云 OSS 签名文档: https://help.aliyun.com/document_detail/31951.html
  Map<String, String> _generateSignature({
    required String method,
    required String path,
    required Map<String, String> headers,
    String? contentMd5,
    String? contentType,
  }) {
    if (_config == null) {
      throw Exception('OSS 配置未初始化');
    }

    final date = _formatHttpDate(DateTime.now().toUtc());

    // 构建 CanonicalizedOSSHeaders
    final ossHeaders = headers.entries
        .where((e) => e.key.toLowerCase().startsWith('x-oss-'))
        .map((e) => '${e.key.toLowerCase()}:${e.value}')
        .join('\n');

    // 构建签名字符串
    final stringToSign = [
      method,
      contentMd5 ?? '',
      contentType ?? '',
      date,
      if (ossHeaders.isNotEmpty) ossHeaders,
      '/${_config!.bucket}/$path',
    ].join('\n');

    // HMAC-SHA1 签名
    final key = utf8.encode(_config!.accessKeySecret);
    final bytes = utf8.encode(stringToSign);
    final hmac = Hmac(sha1, key);
    final digest = hmac.convert(bytes);
    final signature = base64.encode(digest.bytes);

    // 构建认证头
    final authHeader = 'OSS ${_config!.accessKeyId}:$signature';

    return {
      'Authorization': authHeader,
      'Date': date,
      ...headers,
    };
  }

  /// 格式化 HTTP 日期 (RFC1123) - 替代 dart:io HttpDate
  String _formatHttpDate(DateTime date) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    
    final day = weekdays[date.weekday - 1];
    final month = months[date.month - 1];
    final d = date.day.toString().padLeft(2, '0');
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    final s = date.second.toString().padLeft(2, '0');
    
    return '$day, $d $month ${date.year} $h:$m:$s GMT';
  }

  /// 上传文件
  ///
  /// [path] OSS 上的文件路径，如 'test/users/xxx/shenlun/user_data.db'
  /// [bytes] 文件内容
  /// [env] 环境，如 'test' 或 'prod'
  /// [appSlug] 应用标识，如 'shenlun'
  /// [contentType] 可选的 Content-Type
  Future<OSSUploadResult> upload({
    required String path,
    required List<int> bytes,
    required String env,
    required String appSlug,
    String? contentType,
  }) async {
    await _ensureCredentials(env: env, appSlug: appSlug);

    final headers = {
      'Host': '${_config!.bucket}.${_config!.endpoint}',
      'Content-Type': contentType ?? 'application/octet-stream',
      'Content-Length': bytes.length.toString(),
    };

    // 如果有 STS Token，添加它
    if (_config?.securityToken != null && _config!.securityToken!.isNotEmpty) {
      headers['x-oss-security-token'] = _config!.securityToken!;
    }

    final signedHeaders = _generateSignature(
      method: 'PUT',
      path: path,
      headers: headers,
      contentType: headers['Content-Type'],
    );

    final url = Uri.parse('https://${_config!.bucket}.${_config!.endpoint}/$path');

    if (kDebugMode) {
      debugPrint('☁️ 上传文件到: $url');
      debugPrint('   大小: ${bytes.length} bytes');
    }

    try {
      final response = await http.put(
        url,
        headers: signedHeaders,
        body: Uint8List.fromList(bytes),
      );

      if (response.statusCode == 200) {
        final etag = response.headers['etag'] ?? '';
        final fileUrl = 'https://${_config!.bucket}.${_config!.endpoint}/$path';

        if (kDebugMode) {
          debugPrint('✅ 上传成功: $fileUrl');
        }

        return OSSUploadResult(
          success: true,
          url: fileUrl,
          etag: etag,
        );
      } else {
        final errorMsg = '上传失败: HTTP ${response.statusCode}, ${response.body}';
        if (kDebugMode) {
          debugPrint('❌ $errorMsg');
        }
        return OSSUploadResult(
          success: false,
          error: errorMsg,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 上传异常: $e');
      }
      return OSSUploadResult(
        success: false,
        error: '上传异常: $e',
      );
    }
  }

  /// 下载文件
  ///
  /// [path] OSS 上的文件路径
  /// [env] 环境
  /// [appSlug] 应用标识
  Future<List<int>> download({
    required String path,
    required String env,
    required String appSlug,
  }) async {
    await _ensureCredentials(env: env, appSlug: appSlug);

    final headers = {
      'Host': '${_config!.bucket}.${_config!.endpoint}',
    };

    // 如果有 STS Token，添加它
    if (_config?.securityToken != null && _config!.securityToken!.isNotEmpty) {
      headers['x-oss-security-token'] = _config!.securityToken!;
    }

    final signedHeaders = _generateSignature(
      method: 'GET',
      path: path,
      headers: headers,
    );

    final url = Uri.parse('https://${_config!.bucket}.${_config!.endpoint}/$path');

    if (kDebugMode) {
      debugPrint('☁️ 下载文件: $url');
    }

    try {
      final response = await http.get(url, headers: signedHeaders);

      if (response.statusCode == 200) {
        if (kDebugMode) {
          debugPrint('✅ 下载成功: ${response.bodyBytes.length} bytes');
        }
        return response.bodyBytes;
      } else if (response.statusCode == 404) {
        throw Exception('文件不存在: $path');
      } else {
        throw Exception('下载失败: HTTP ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 下载异常: $e');
      }
      rethrow;
    }
  }

  /// 检查文件是否存在
  Future<bool> exists({
    required String path,
    required String env,
    required String appSlug,
  }) async {
    try {
      await _ensureCredentials(env: env, appSlug: appSlug);

      final headers = {
        'Host': '${_config!.bucket}.${_config!.endpoint}',
      };

      // 如果有 STS Token，添加它
      if (_config?.securityToken != null && _config!.securityToken!.isNotEmpty) {
        headers['x-oss-security-token'] = _config!.securityToken!;
      }

      final signedHeaders = _generateSignature(
        method: 'HEAD',
        path: path,
        headers: headers,
      );

      final url = Uri.parse('https://${_config!.bucket}.${_config!.endpoint}/$path');

      final response = await http.head(url, headers: signedHeaders);

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ 检查文件存在性失败: $e');
      }
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

    final headers = {
      'Host': '${_config!.bucket}.${_config!.endpoint}',
      'x-oss-copy-source': '/${_config!.bucket}/$sourcePath',
    };

    // 如果有 STS Token，添加它
    if (_config?.securityToken != null && _config!.securityToken!.isNotEmpty) {
      headers['x-oss-security-token'] = _config!.securityToken!;
    }

    final signedHeaders = _generateSignature(
      method: 'PUT',
      path: targetPath,
      headers: headers,
    );

    final url = Uri.parse('https://${_config!.bucket}.${_config!.endpoint}/$targetPath');

    if (kDebugMode) {
      debugPrint('☁️ 复制文件: $sourcePath -> $targetPath');
    }

    final response = await http.put(url, headers: signedHeaders);

    if (response.statusCode != 200) {
      throw Exception('复制失败: HTTP ${response.statusCode}, ${response.body}');
    }

    if (kDebugMode) {
      debugPrint('✅ 复制成功');
    }
  }

  /// 删除文件
  Future<void> delete({
    required String path,
    required String env,
    required String appSlug,
  }) async {
    await _ensureCredentials(env: env, appSlug: appSlug);

    final headers = {
      'Host': '${_config!.bucket}.${_config!.endpoint}',
    };

    // 如果有 STS Token，添加它
    if (_config?.securityToken != null && _config!.securityToken!.isNotEmpty) {
      headers['x-oss-security-token'] = _config!.securityToken!;
    }

    final signedHeaders = _generateSignature(
      method: 'DELETE',
      path: path,
      headers: headers,
    );

    final url = Uri.parse('https://${_config!.bucket}.${_config!.endpoint}/$path');

    if (kDebugMode) {
      debugPrint('☁️ 删除文件: $path');
    }

    final response = await http.delete(url, headers: signedHeaders);

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('删除失败: HTTP ${response.statusCode}, ${response.body}');
    }

    if (kDebugMode) {
      debugPrint('✅ 删除成功');
    }
  }

  /// 列出文件（带前缀）
  Future<List<String>> list({
    required String prefix,
    required String env,
    required String appSlug,
  }) async {
    await _ensureCredentials(env: env, appSlug: appSlug);

    final headers = {
      'Host': '${_config!.bucket}.${_config!.endpoint}',
    };

    // 如果有 STS Token，添加它
    if (_config?.securityToken != null && _config!.securityToken!.isNotEmpty) {
      headers['x-oss-security-token'] = _config!.securityToken!;
    }

    final signedHeaders = _generateSignature(
      method: 'GET',
      path: '',
      headers: headers,
    );

    final url = Uri.parse(
      'https://${_config!.bucket}.${_config!.endpoint}/?prefix=$prefix',
    );

    final response = await http.get(url, headers: signedHeaders);

    if (response.statusCode != 200) {
      throw Exception('列出文件失败: HTTP ${response.statusCode}');
    }

    // 解析 XML 响应
    final xmlString = response.body;
    final keys = <String>[];

    // 简单的 XML 解析
    final keyRegex = RegExp(r'<Key>([^<]+)</Key>');
    final matches = keyRegex.allMatches(xmlString);
    for (final match in matches) {
      keys.add(match.group(1)!);
    }

    return keys;
  }
}

/// 全局快捷访问
OSSService get ossService => OSSService();
