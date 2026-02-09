# Rocket Workshop SDK - Supabase 版本

基于 Supabase 的多应用通用认证与数据同步 SDK，支持 iOS 购买迁移和云端数据同步。

## 项目概述

本项目为「小火箭」系列应用提供统一的认证、购买验证和数据同步服务。

### 核心功能

- ✅ **手机号登录**：支持阿里云短信验证码登录
- ✅ **微信登录**：支持微信 OAuth 登录
- ✅ **购买验证**：iOS 内购收据验证
- ✅ **数据迁移**：设备数据迁移到用户账号
- ✅ **云端同步**：基于阿里云 OSS 的文件同步
- ✅ **多应用支持**：同一套 SDK 支持多个应用

## 项目结构

```
rocket-workshop-supabase/
├── flutter-sdk/                    # Flutter SDK
│   ├── rocket_workshop_auth/      # 认证 SDK 核心
│   │   ├── lib/src/
│   │   │   ├── auth_sdk.dart      # 认证主类
│   │   │   ├── services/
│   │   │   │   ├── cloud_sync_service.dart   # 云同步服务
│   │   │   │   ├── oss_service.dart          # OSS 服务
│   │   │   │   └── purchase_service.dart     # 购买验证服务
│   │   └── pubspec.yaml
│   └── example_app/               # 示例应用
│       ├── lib/
│       │   ├── main.dart
│       │   └── pages/
│       │       ├── login_page.dart
│       │       └── sync_demo_page.dart
│       └── pubspec.yaml
├── supabase/                      # Supabase 配置
│   ├── config.toml               # Supabase 配置文件
│   └── functions/                # Edge Functions
│       ├── auth-wechat/          # 微信登录
│       ├── debug-login/          # 测试登录（仅测试环境）
│       ├── get-oss-sts/          # 获取 OSS STS 凭证
│       ├── migrate-device-purchase/  # 购买迁移
│       ├── send-sms/             # 发送短信
│       └── verify-ios-receipt/   # iOS 收据验证
├── docs/                         # 文档目录
│   ├── setup/                    # 配置指南
│   └── architecture/             # 架构文档
├── tests/                        # 测试脚本
└── README.md                     # 本文件
```

## 快速开始

### 1. 环境要求

- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- Supabase 项目（已配置）
- 阿里云账号（用于 OSS 和短信）

### 2. 安装 SDK

在你的 Flutter 项目中添加依赖：

```yaml
dependencies:
  rocket_workshop_auth:
    path: ../rocket_workshop_auth  # 或使用 git 依赖
```

### 3. 初始化 SDK

```dart
import 'package:rocket_workshop_auth/rocket_workshop_auth.dart';

// 在 main() 中初始化
await RocketWorkshopAuth.instance.initialize(
  AuthConfig(
    url: 'YOUR_SUPABASE_URL',
    anonKey: 'YOUR_SUPABASE_ANON_KEY',
    appId: 'your_app_id',  // 例如: 'shenlun'
    debug: true,
  ),
);
```

### 4. 使用示例

#### 手机号登录

```dart
// 发送验证码
final result = await authSDK.sendSMSCode('13800000000');

// 验证码登录
final loginResult = await authSDK.verifySMSCode('13800000000', '123456');
if (loginResult.success) {
  print('登录成功: ${loginResult.data?.phone}');
}
```

#### 购买迁移

```dart
// 迁移购买数据
final migrateResult = await authSDK.purchaseService.migrateDevicePurchases(
  deviceId: 'old-device-id',
  receiptData: 'base64-encoded-receipt',
);
```

## 环境配置

### 测试环境

```bash
flutter run --dart-define=ENV=test
```

- 使用 `test_public` schema
- OSS 路径前缀：`test/`
- 启用 Debug Login（无需短信验证）

### 生产环境

```bash
flutter run --dart-define=ENV=prod
```

- 使用 `public` schema
- OSS 路径前缀：`prod/`
- 需要真实短信验证

## 配置指南

详细配置文档请查看 `docs/setup/` 目录：

- [Supabase 配置](docs/setup/supabase.md)
- [阿里云 OSS 配置](docs/setup/aliyun-oss.md)
- [阿里云短信配置](docs/setup/aliyun-sms.md)

## 架构文档

- [多应用同步架构](docs/architecture/multi_app_sync.md)
- [购买验证流程](docs/architecture/purchase_verification.md)

## 开发进度

当前版本：**v1.0.0**

### 已完成功能

- ✅ 手机号短信登录（阿里云短信）
- ✅ 微信 OAuth 登录
- ✅ iOS 内购收据验证
- ✅ 设备购买数据迁移
- ✅ 云端文件同步（基于阿里云 OSS）
- ✅ 多应用支持
- ✅ Web 平台支持
- ✅ 测试环境 Debug Login

### 待开发功能

- ⏳ Apple ID 登录
- ⏳ Android 购买验证
- ⏳ 实时数据同步（WebSocket）

详细进度请查看 [PROGRESS.md](PROGRESS.md)

## 测试

### 运行示例应用

```bash
cd flutter-sdk/example_app
flutter run --dart-define=ENV=test
```

### 测试 Edge Functions

```bash
cd tests
node test_deployed_functions.js
```

## 部署

### 部署 Edge Functions

```bash
./deploy_edge_functions.sh
```

### 配置环境变量

在 Supabase Dashboard 中配置以下 Secrets：

```
ALIBABA_CLOUD_ACCESS_KEY_ID=your_access_key_id
ALIBABA_CLOUD_ACCESS_KEY_SECRET=your_access_key_secret
SMS_SIGN_NAME=your_sms_sign_name
SMS_TEMPLATE_CODE=your_sms_template_code
OSS_BUCKET=your_oss_bucket
OSS_REGION=your_oss_region
```

## 安全注意事项

- 🔒 **永远不要**将 `.env.local` 提交到 Git
- 🔒 定期更换 AccessKey
- 🔒 生产环境禁用 Debug Login
- 🔒 使用环境变量管理敏感信息

## 贡献

欢迎提交 Issue 和 Pull Request。

## 许可证

MIT License

## 联系方式

如有问题，请提交 Issue 或联系项目维护者。
