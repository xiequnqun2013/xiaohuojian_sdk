# 苹果登录 (Sign in with Apple) 配置指南

> ⚠️ **重要**：苹果登录是 App Store 上架的**强制要求**（如果使用第三方登录）

---

## 📋 前置条件

- [ ] Apple Developer 账号（$99/年）
- [ ] 已创建 App ID
- [ ] 已创建 Service ID

---

## 🔧 配置步骤

### 步骤 1：Apple Developer Portal 配置

#### 1.1 开启 Sign in with Apple

1. 登录 [Apple Developer Portal](https://developer.apple.com/)
2. Certificates, Identifiers & Profiles → Identifiers
3. 找到你的 **App ID**（如 `com.yourcompany.shenlun`）
4. 编辑 → 勾选 **Sign in with Apple** → Save

#### 1.2 创建 Service ID

1. Identifiers → 点击 **+** → 选择 **Services IDs**
2. Description: `小火箭登录`（任意）
3. Identifier: `com.yourcompany.shenlun.signin`（建议格式）
4. 创建后点击编辑
5. 勾选 **Sign in with Apple** → Configure
6. Primary App ID: 选择你的 App ID
7. Domains and Subdomains: 
   ```
   rocketapi.lensflow.cn
   ```
8. Return URLs:
   ```
   http://rocketapi.lensflow.cn/auth/v1/callback
   ```
   或（如果有自定义域名）
   ```
   https://api.your-domain.com/auth/v1/callback
   ```
9. Save → Continue → Register

#### 1.3 创建 Private Key

1. Keys → 点击 **+**
2. Key Name: `SignInWithAppleKey`
3. 勾选 **Sign in with Apple** → Configure
4. Primary App ID: 选择你的 App ID
5. Continue → Register
6. **下载 .p8 文件**（⚠️ 只下载一次，保存好！）
7. 记录 **Key ID**（如 `ABC123DEF4`）

#### 1.4 获取 Team ID

1. Membership → 查看 **Team ID**（如 `ABC123DEF4`）

---

### 步骤 2：Supabase 配置

#### 2.1 配置 Apple Provider

1. 登录 Supabase Dashboard
   ```
   http://rocketapi.lensflow.cn/project/default/auth/providers
   ```

2. 找到 **Apple** → 点击 **Enable**

3. 填写配置：
   
   | 字段 | 值 | 来源 |
   |------|-----|------|
   | **Client ID** | `com.yourcompany.shenlun.signin` | Service ID |
   | **Key ID** | `ABC123DEF4` | Private Key |
   | **Team ID** | `ABC123DEF4` | Membership |
   | **Private Key** | `.p8 文件内容` | 下载的 key |

4. Save

---

### 步骤 3：Flutter 代码集成

```dart
import 'package:rocket_workshop_auth/rocket_workshop_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class LoginPage extends StatelessWidget {
  Future<void> _signInWithApple() async {
    try {
      // 1. 触发苹果登录
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // 2. 获取 authorization code
      final authorizationCode = credential.authorizationCode;

      // 3. 使用 Supabase 登录
      final response = await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: credential.identityToken!,
        accessToken: authorizationCode,
      );

      if (response.user != null) {
        print('苹果登录成功: ${response.user!.id}');
      }
    } catch (e) {
      print('苹果登录失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SignInWithAppleButton(
          onPressed: _signInWithApple,
        ),
      ),
    );
  }
}
```

---

### 步骤 4：添加依赖

```yaml
# pubspec.yaml
dependencies:
  sign_in_with_apple: ^5.0.0
  
dev_dependencies:
  # iOS 配置需要
  cider: ^0.2.0
```

---

## ⚠️ 重要注意事项

### iOS 配置

在 `ios/Runner/Info.plist` 添加：

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.yourcompany.shenlun</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.yourcompany.shenlun</string>
        </array>
    </dict>
</array>
```

### Capabilities

Xcode → Signing & Capabilities → + Capability → **Sign in with Apple**

---

## 📱 测试

### 测试步骤

1. **真机测试**（模拟器不支持苹果登录）
2. 点击"使用 Apple 登录"按钮
3. 使用 Face ID / Touch ID 或密码
4. 检查是否登录成功

### 常见问题

| 问题 | 解决方案 |
|------|---------|
| "The operation couldn't be completed" | 检查 Service ID 配置 |
| "invalid_client" | 检查 Client ID 和 Team ID |
| 无法获取 email | 首次登录才会返回 email |
| 模拟器无法测试 | 必须用真机 |

---

## 🔗 相关文档

- [Supabase Apple Auth](https://supabase.com/docs/guides/auth/social-login/auth-apple)
- [Sign in with Apple](https://developer.apple.com/sign-in-with-apple/)
- [Flutter sign_in_with_apple](https://pub.dev/packages/sign_in_with_apple)

---

## ⏰ 时间预估

| 步骤 | 时间 |
|------|------|
| Apple Developer 配置 | 30 分钟 |
| Supabase 配置 | 10 分钟 |
| Flutter 集成 | 1 小时 |
| 真机测试 | 30 分钟 |
| **总计** | **~2.5 小时** |

---

## 🎯 下一步

配置完成后告诉我，我帮你：
1. 集成到 Flutter SDK
2. 添加到登录页面
3. 测试整个流程
