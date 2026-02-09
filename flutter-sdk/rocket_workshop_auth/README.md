# Rocket Workshop Auth SDK

Rocket Workshop 项目的通用认证 SDK，支持多 App 接入。

## 安装

```yaml
dependencies:
  rocket_workshop_auth:
    path: ../rocket_workshop_auth
```

## 使用

### 1. 初始化

```dart
import 'package:rocket_workshop_auth/rocket_workshop_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 方式1: 预发布环境
  await authSDK.initialize(AuthConfig.staging(
    appId: 'shenlun-app-id', // 你的 App ID
  ));
  
  // 方式2: 生产环境
  await authSDK.initialize(AuthConfig.production(
    url: 'https://your-project.supabase.co',
    anonKey: 'your-anon-key',
    appId: 'your-app-id',
  ));
  
  runApp(MyApp());
}
```

### 2. 短信登录

```dart
// 发送验证码
final result = await authSDK.sendSMSCode('18520160445');
if (!result.success) {
  print('发送失败: ${result.error}');
}

// 验证登录
final loginResult = await authSDK.verifySMSCode('18520160445', '123456');
if (loginResult.success) {
  print('登录成功: ${loginResult.data?.id}');
} else {
  print('登录失败: ${loginResult.error}');
}
```

### 3. 监听登录状态

```dart
StreamBuilder(
  stream: authSDK.onAuthStateChange,
  builder: (context, snapshot) {
    if (authSDK.isLoggedIn) {
      return HomePage();
    } else {
      return LoginPage();
    }
  },
)
```

### 4. 用户信息

```dart
// 获取资料
final profileResult = await authSDK.getProfile();
if (profileResult.success) {
  print('昵称: ${profileResult.data?.nickname}');
}

// 更新资料
await authSDK.updateProfile(
  nickname: '新昵称',
  avatarUrl: 'https://example.com/avatar.jpg',
);
```

### 5. 退出登录

```dart
await authSDK.signOut();
```

## 多 App 支持

每个 App 使用独立的 `appId`，用户数据自动隔离：

```dart
// 申论学习 App
authSDK.initialize(AuthConfig.staging(appId: 'shenlun-app'));

// 驾考助手 App  
authSDK.initialize(AuthConfig.staging(appId: 'jiakao-app'));
```

同一手机号在不同 App 是独立的账号。

## 配置说明

| 环境 | URL | 用途 |
|------|-----|------|
| Staging | http://rocketapi.lensflow.cn | 开发测试 |
| Production | 你的生产地址 | 正式上线 |

## 错误处理

所有异步方法返回 `AuthResult<T>`：

```dart
final result = await authSDK.sendSMSCode('18520160445');

if (result.success) {
  // 成功
} else {
  // 失败，result.error 包含错误信息
  showErrorToast(result.error!);
}
```
