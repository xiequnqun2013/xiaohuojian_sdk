# 短信服务 Edge Function 配置指南

> 新 PolarDB Supabase 实例没有内置短信提供商，需要使用 Edge Function 发送短信

## 📋 配置清单

你需要提供以下阿里云短信配置：

| 配置项 | 环境变量名 | 说明 | 获取方式 |
|--------|-----------|------|---------|
| AccessKey ID | `ALIBABA_CLOUD_ACCESS_KEY_ID` | 阿里云访问密钥 ID | [阿里云控制台](https://ram.console.aliyun.com/manage/ak) |
| AccessKey Secret | `ALIBABA_CLOUD_ACCESS_KEY_SECRET` | 阿里云访问密钥 Secret | 同上 |
| 短信签名 | `SMS_SIGN_NAME` | 已备案的短信签名 | [短信服务控制台](https://dysms.console.aliyun.com/quickstart) |
| 短信模板 Code | `SMS_TEMPLATE_CODE` | 验证码模板 CODE | 同上 |

---

## 🔧 获取配置步骤

### 1. 阿里云 AccessKey

1. 访问 [阿里云 RAM 控制台](https://ram.console.aliyun.com/manage/ak)
2. 创建 AccessKey（或使用已有）
3. 记录 `AccessKey ID` 和 `AccessKey Secret`

⚠️ **安全提示**：建议使用 RAM 子账号，并仅授予短信服务权限

```json
{
  "Version": "1",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dysms:SendSms",
        "dysms:QuerySendDetails"
      ],
      "Resource": "*"
    }
  ]
}
```

### 2. 短信签名

1. 访问 [阿里云短信服务控制台](https://dysms.console.aliyun.com/quickstart)
2. 进入「签名管理」
3. 申请/查看已备案的签名名称（如：`小火箭`）

### 3. 短信模板

1. 进入「模板管理」
2. 申请验证码模板，内容类似：
   ```
   您的验证码是：${code}，请勿泄露给他人。
   ```
3. 记录模板 Code（如：`SMS_123456789`）

---

## 🚀 部署 Edge Function

### 方法 1：使用脚本部署（推荐）

```bash
# 运行部署脚本
./deploy_sms_function.sh
```

### 方法 2：手动部署

```bash
# 1. 登录 Supabase
supabase login

# 2. 链接项目
supabase link --project-ref default

# 3. 设置环境变量
supabase secrets set ALIBABA_CLOUD_ACCESS_KEY_ID=your-access-key-id
supabase secrets set ALIBABA_CLOUD_ACCESS_KEY_SECRET=your-access-key-secret
supabase secrets set SMS_SIGN_NAME=你的签名
supabase secrets set SMS_TEMPLATE_CODE=SMS_xxxxxx

# 4. 部署函数
supabase functions deploy send-sms
```

---

## 🧪 测试短信发送

### 使用 curl 测试

```bash
curl -X POST "http://42.121.49.212:8080/functions/v1/send-sms" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "phone": "+8618520160445",
    "templateParam": {
      "code": "123456"
    }
  }'
```

### 响应示例

```json
{
  "success": true,
  "message": "验证码发送成功",
  "requestId": "12345678-1234-1234-1234-123456789012"
}
```

---

## 📱 Flutter SDK 集成

部署完成后，需要修改 Flutter SDK 使用新的短信接口：

```dart
// 在 auth_sdk.dart 中修改 sendSMSCode 方法

/// 发送短信验证码（使用 Edge Function）
Future<AuthResult<void>> sendSMSCode(String phone) async {
  try {
    final fullPhone = _formatPhone(phone);

    // 调用 Edge Function 发送短信
    final response = await _client.functions.invoke(
      'send-sms',
      body: {
        'phone': fullPhone,
      },
    );

    if (response.data['success'] == true) {
      return AuthResult.success(null);
    } else {
      return AuthResult.failure(response.data['error'] ?? '发送失败');
    }
  } catch (e) {
    return AuthResult.failure('发送失败: $e');
  }
}
```

---

## ⚠️ 常见问题

### 1. 短信发送失败

检查：
- AccessKey 是否有短信服务权限
- 签名是否已审核通过
- 模板是否已审核通过
- 手机号格式是否正确（支持 +86 前缀）

### 2. 频率限制

阿里云短信服务有频率限制：
- 同一手机号：1 分钟 1 条，1 小时 5 条，1 天 10 条

### 3. 费用

按发送条数计费，约 ¥0.045/条。

---

## 📋 总结

需要提供给我的配置：

```bash
ALIBABA_CLOUD_ACCESS_KEY_ID=你的AccessKey ID
ALIBABA_CLOUD_ACCESS_KEY_SECRET=你的AccessKey Secret
SMS_SIGN_NAME=你的短信签名
SMS_TEMPLATE_CODE=你的模板CODE
```

提供后我可以帮你部署和测试。
