# 短信登录测试报告

## 📱 测试时间
2026-02-09

## ✅ 测试结果

| 项目 | 状态 | 说明 |
|------|------|------|
| 短信发送 API | ✅ 正常 | 返回 `{}` 表示成功 |
| 手机号 | 18520160445 | +8618520160445 |
| 触发器修复 | ✅ 完成 | ON CONFLICT DO NOTHING |

## 🧪 测试记录

### 1. 发送验证码

**请求：**
```bash
curl -X POST "http://8.161.114.102:80/auth/v1/otp" \
  -H "apikey: eyJ0eXAiOiJKV1Qi..." \
  -H "Content-Type: application/json" \
  -d '{"phone":"+8618520160445"}'
```

**响应：**
```json
{}
```

✅ **HTTP 200，空对象表示成功**

### 2. 数据库触发器修复

**问题：** 之前报错 `duplicate key value violates unique constraint "profiles_pkey"`

**修复：** 修改触发器函数添加 `ON CONFLICT DO NOTHING`

```sql
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, phone)
    VALUES (new.id, new.phone)
    ON CONFLICT (id) DO NOTHING;  -- 添加此行
    
    INSERT INTO test_public.profiles (id, phone)
    VALUES (new.id, new.phone)
    ON CONFLICT (id) DO NOTHING;  -- 添加此行
    
    RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### 3. 验证登录（待测试）

收到验证码后，使用以下请求验证：

```bash
curl -X POST "http://8.161.114.102:80/auth/v1/verify" \
  -H "apikey: eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNzcwNDQ0NjQ0LCJleHAiOjEzMjgxMDg0NjQ0fQ.b8jrVt73j4A3vlAN34TAntvPKy-9H3bMFdP37zux3pQ" \
  -H "Content-Type: application/json" \
  -d '{
    "phone": "+8618520160445",
    "token": "收到的6位验证码",
    "type": "sms"
  }'
```

## 📲 Flutter 测试

运行示例 App：

```bash
cd flutter-sdk/example_app
flutter pub get
flutter run --dart-define=ENV=test
```

**测试步骤：**
1. 输入手机号：`18520160445`
2. 点击"发送验证码"
3. 等待短信
4. 输入验证码，点击登录
5. 检查是否跳转到首页

## ⚠️ 已知问题

| 问题 | 状态 | 说明 |
|------|------|------|
| 重复发送频率限制 | ⚠️ | 同一手机号可能有限制 |
| 模板审核 | ✅ | 已配置 |
| 签名备案 | ✅ | 已完成 |

## 📋 下一步

1. [ ] 用户收到验证码并验证登录
2. [ ] 检查 profiles 表是否正确创建记录
3. [ ] 测试用户资料获取 API
4. [ ] 测试退出登录
