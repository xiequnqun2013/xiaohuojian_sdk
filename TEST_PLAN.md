# 小火箭 SDK 测试计划

## 📝 测试进度跟踪

### Phase 1: 基础设施 ✅

| 任务 | 状态 | 说明 |
|------|------|------|
| Supabase 项目 | ✅ 完成 | `ra-supabase-sb6xjntrfya75g` |
| 测试环境 schema | ✅ 完成 | `test_public` 已创建 |
| 线上环境 schema | ✅ 完成 | `public` 已创建 |
| 表结构 | ✅ 完成 | 5张表 + RLS 策略 |

### Phase 2: 短信登录 🟡 待测试

| 任务 | 状态 | 说明 |
|------|------|------|
| SDK 短信接口 | ✅ 完成 | `sendSMSCode`, `verifySMSCode` |
| 登录页面 UI | ✅ 完成 | `example_app/lib/pages/login_page.dart` |
| 短信服务商配置 | ✅ 完成 | 阿里云短信已配置 |
| **真机测试** | 🟡 待测 | 需要 Flutter 运行测试 |

### Phase 3: 数据同步 ❌ 未开始

| 任务 | 状态 | 说明 |
|------|------|------|
| CloudSyncService | ❌ 未开始 | 核心同步类 |
| OSS 上传/下载 | ❌ 未开始 | 阿里云 OSS |
| 数据迁移 | ❌ 未开始 | device→user |
| 多设备合并 | ❌ 未开始 | 冲突处理 |

### Phase 4: 购买验证 ❌ 未开始

| 任务 | 状态 | 说明 |
|------|------|------|
| Edge Function | ❌ 未开始 | `verify-purchase` |
| 苹果收据验证 | ❌ 未开始 | App Store |
| 谷歌收据验证 | ❌ 未开始 | Play Store |

---

## 🧪 当前可测试内容

### 测试环境运行

```bash
cd flutter-sdk/example_app
flutter pub get
flutter run --dart-define=ENV=test
```

### 测试步骤

1. **短信登录**
   - [ ] 输入手机号，点击"发送验证码"
   - [ ] 收到短信（检查手机号是否正确收到）
   - [ ] 输入验证码登录
   - [ ] 验证登录成功，显示用户信息

2. **环境隔离验证**
   - [ ] 测试环境登录后，查看 schema 是否为 `test_public`
   - [ ] 切换到线上环境，验证是未登录状态
   - [ ] 在 Supabase Dashboard 检查数据是否正确写入对应 schema

3. **数据库验证**
   ```sql
   -- 检查测试环境数据
   SELECT * FROM test_public.profiles;
   SELECT * FROM test_public.user_apps;
   
   -- 检查线上环境数据
   SELECT * FROM public.profiles;
   SELECT * FROM public.user_apps;
   ```

---

## ⚠️ 需要用户确认

### 短信配置检查

请确认阿里云短信配置是否正确：

1. **模板配置** - 验证码模板是否已审核通过
2. **签名配置** - 短信签名是否已备案
3. **测试手机号** - 是否有测试白名单

### 测试手机号

提供一个测试用的手机号，用于验证短信是否发送成功：
- 手机号：_______________
- 是否收到验证码：□ 是 / □ 否

---

## 📋 下一步开发计划

1. **完成短信测试** - 验证通过后进入下一步
2. **实现 CloudSyncService** - 核心同步功能
3. **实现 Edge Functions** - 购买验证
4. **集成测试** - 完整流程测试
