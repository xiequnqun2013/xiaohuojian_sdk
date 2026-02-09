import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

/// 购买服务 - 处理内购验证和迁移
class PurchaseService {
  static final PurchaseService _instance = PurchaseService._internal();
  factory PurchaseService() => _instance;
  PurchaseService._internal();

  final String _supabaseUrl = RocketConfig.supabaseUrl;
  String? _jwtToken;

  /// 设置 JWT Token（登录后调用）
  void setJWT(String token) {
    _jwtToken = token;
  }

  /// 验证 iOS 凭证
  /// 
  /// [receipt] Base64 编码的收据数据
  /// 返回验证结果
  Future<Map<String, dynamic>> verifyIosReceipt({
    required String receipt,
  }) async {
    if (_jwtToken == null) {
      // 验证可能需要登录，或者使用 Anon Key？ verify-ios-receipt usually requires Auth if RLS enabled or strictly checked.
      // But usually verify is open or requires at least anon.
      // Let's assume we need a token (Anon or User).
      // If _jwtToken is null, we can't set Bearer properly unless we have Anon key fallback.
      if (kDebugMode) {
        debugPrint('⚠️ Warning: JWT Token is null for verifyIosReceipt');
      }
    }

    final url = '$_supabaseUrl/functions/v1/verify-ios-receipt';
    
    if (kDebugMode) {
      debugPrint('💰 验证 iOS 凭证: $url');
    }

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer ${_jwtToken ?? RocketConfig.supabaseAnonKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'receiptData': receipt,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (kDebugMode) {
          debugPrint('✅ 验证成功: ${data['status']}');
        }
        return data;
      } else {
        throw Exception('验证失败: ${data['error'] ?? response.body}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 验证异常: $e');
      }
      rethrow;
    }
  }

  /// 迁移设备购买记录到用户账号
  /// 
  /// [receipt] Base64 编码的收据数据
  /// [deviceId] 设备 ID
  /// [userId] 目标用户 ID
  /// [appSlug] 应用标识
  Future<void> migratePurchase({
    required String receipt,
    required String deviceId,
    required String userId,
    required String appSlug,
  }) async {
     if (_jwtToken == null) {
      throw Exception('未登录，无法迁移购买记录');
    }

    final url = '$_supabaseUrl/functions/v1/migrate-device-purchase';

    if (kDebugMode) {
      debugPrint('💰 迁移购买记录: $url');
      debugPrint('   Device: $deviceId -> User: $userId');
    }

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $_jwtToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'receipt': receipt,
          'device_id': deviceId,
          'user_id': userId,
          'app_slug': appSlug,
          // 'platform': 'ios', // Default is ios in function
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (kDebugMode) {
          debugPrint('✅ 购买迁移成功');
        }
      } else {
        throw Exception('购买迁移失败: ${data['error'] ?? response.body}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 购买迁移异常: $e');
      }
      rethrow;
    }
  }
}

/// 全局快捷访问
PurchaseService get purchaseService => PurchaseService();
