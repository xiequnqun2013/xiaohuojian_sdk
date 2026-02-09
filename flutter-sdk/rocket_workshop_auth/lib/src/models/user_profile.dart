/// 用户资料
class UserProfile {
  /// 用户 ID
  final String id;
  
  /// 昵称
  final String? nickname;
  
  /// 头像 URL
  final String? avatarUrl;
  
  /// 手机号
  final String? phone;
  
  /// 创建时间
  final DateTime createdAt;
  
  /// 更新时间
  final DateTime updatedAt;

  UserProfile({
    required this.id,
    this.nickname,
    this.avatarUrl,
    this.phone,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 从 JSON 解析
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      nickname: json['nickname'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      phone: json['phone'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nickname': nickname,
      'avatar_url': avatarUrl,
      'phone': phone,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// 复制并修改
  UserProfile copyWith({
    String? nickname,
    String? avatarUrl,
  }) {
    return UserProfile(
      id: id,
      nickname: nickname ?? this.nickname,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phone: phone,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
