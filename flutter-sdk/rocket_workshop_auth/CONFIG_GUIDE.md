# 配置指南

## 🎯 快速修改配置

**所有配置都在一个文件：**

```
lib/src/config.dart
```

## 📝 常用配置项

### 1. 修改 Supabase URL

```dart
// lib/src/config.dart

// 旧配置
static const String supabaseUrl = 'http://rocketapi.lensflow.cn';

// 新配置（修改这里即可）
static const String supabaseUrl = 'https://your-new-domain.com';
```

### 2. 修改 Supabase Anon Key

```dart
// lib/src/config.dart

static const String supabaseAnonKey = 'your-new-anon-key';
```

### 3. 修改 OSS Bucket

```dart
// lib/src/config.dart

static const String ossBucket = 'your-bucket-name';
static const String ossEndpoint = 'oss-cn-beijing.aliyuncs.com';
```

## 🌍 环境切换

### 命令行参数

```bash
# 测试环境（默认）
flutter run

# 或显式指定
flutter run --dart-define=ENV=test

# 生产环境
flutter run --dart-define=ENV=prod
flutter build apk --dart-define=ENV=prod
```

### 代码中使用

```dart
import 'package:rocket_workshop_auth/rocket_workshop_auth.dart';

// 检查环境
if (RocketConfig.isTest) {
  print('当前是测试环境');
}

if (RocketConfig.isProd) {
  print('当前是生产环境');
}

// 获取配置
print('URL: ${RocketConfig.supabaseUrl}');
print('Schema: ${RocketConfig.schema}');
print('OSS Prefix: ${RocketConfig.ossPrefix}');
```

## 🔧 高级配置

### 环境变量覆盖

可以在命令行通过环境变量覆盖配置：

```bash
flutter run --dart-define=SUPABASE_URL=https://custom-url.com
flutter run --dart-define=SUPABASE_ANON_KEY=custom-key
```

### 运行时配置

```dart
// 自定义配置（不使用默认值）
await RocketWorkshopAuth().initialize(
  AuthConfig(
    url: 'https://custom-url.com',
    anonKey: 'custom-anon-key',
    appId: 'my-app',
    debug: true,
  ),
);
```

## 📁 配置文件结构

```
lib/src/
├── config.dart           # ⭐ 集中配置文件
├── auth_config.dart      # 认证配置类
├── auth_sdk.dart         # SDK 主类
└── services/
    ├── oss_service.dart  # 使用 config.dart
    └── cloud_sync_service.dart
```

## ⚠️ 重要提示

1. **不要提交敏感信息到 Git**
   - Anon Key 可以提交（它是 Public 的）
   - Service Role Key **绝对不要提交**

2. **修改配置后需要重启 App**
   - Flutter Hot Restart 即可

3. **生产环境建议**
   - 使用 HTTPS
   - 配置自定义域名
   - 启用 SSL 证书
