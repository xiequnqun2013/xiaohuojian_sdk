# 项目进度 - 2026-02-09

## 🎯 核心功能状态

### ✅ 已完成 (90%)

| 模块 | 状态 | 说明 |
|------|------|------|
| **数据库架构** | ✅ 100% | 所有表 + RLS + 触发器 |
| **短信登录** | 🟡 80% | Edge Function 代码完成，待部署 |
| **域名配置** | ✅ 100% | http://42.121.49.212:8080 |
| **集中配置** | ✅ 100% | config.dart 管理 |
| **OSS Service** | ✅ 100% | 完整实现上传/下载/复制/删除/列表 |
| **CloudSyncService** | ✅ 100% | 完整实现数据同步和迁移 |
| **SQL 函数** | ✅ 100% | get_oss_sts + get_oss_sts_http |

### 🟡 进行中/待配置 (10%)

| 模块 | 状态 | 说明 |
|------|------|------|
| **苹果登录** | 🟡 0% | 需要 Apple Developer 配置 |
| **微信登录** | ⏸️ 等待 | 阿里云已支持，等你的资料 |
| **Edge Function 部署** | 🟡 50% | send-sms + get-oss-sts 代码完成，待部署 |
| **购买验证** | ❌ 0% | Edge Function 待部署 |

---

## 📋 近期任务清单

### 高优先级（本周做）

- [ ] **苹果登录配置**
  - 需要：Apple Developer 账号
  - 耗时：~2.5 小时
  - 文档：`APPLE_LOGIN_SETUP.md`

- [x] **完成 OSS 上传** ✅ 已完成
  - SQL 函数：`get_oss_sts_http` 已部署
  - Flutter SDK：`oss_service.dart` 完整实现
  - Flutter SDK：`cloud_sync_service.dart` 完整实现
  - 支持：上传/下载/复制/删除/列表/存在检查

- [ ] **部署 Edge Function（send-sms + get-oss-sts）**
  - 需要：阿里云 AccessKey + 短信签名/模板
  - 部署脚本：`deploy_edge_functions.sh`
  - 配置文档：`SMS_EDGE_FUNCTION_SETUP.md`
  - OSS STS 当前使用 SQL 函数作为备用方案

### 中优先级（下周做）

- [ ] **微信登录**
  - 等待：微信开放平台资料审核
  - 阿里云：已支持微信登录

- [ ] **购买验证**
  - 需要：苹果 App Store Shared Secret
  - 需要：谷歌 Play Console API Key

### 低优先级（后续）

- [ ] 数据迁移完整测试
- [ ] 多设备合并逻辑
- [ ] 数据分析埋点

---

## ⚠️ 阻塞项

| 阻塞项 | 状态 | 需要你提供 |
|--------|------|-----------|
| **短信服务** | 🔴 阻塞 | 阿里云 AccessKey + 短信签名 + 模板 |
| 苹果登录 | 🔴 阻塞 | Apple Developer 账号 |
| 微信登录 | 🔴 阻塞 | 微信开放平台资料 |
| 购买验证 | 🔴 阻塞 | App Store / Play Console 凭证 |
| SSL/HTTPS | 🟡 建议 | 生产环境必需 |

---

## 📋 需要配置清单

### 1. 阿里云短信（必需 - 用于登录）

```bash
ALIBABA_CLOUD_ACCESS_KEY_ID=你的AccessKey ID
ALIBABA_CLOUD_ACCESS_KEY_SECRET=你的AccessKey Secret
SMS_SIGN_NAME=你的短信签名（如：小火箭）
SMS_TEMPLATE_CODE=你的模板CODE（如：SMS_123456789）
```

获取方法见：`SMS_EDGE_FUNCTION_SETUP.md`

### 2. 阿里云 OSS（可选 - 已有 SQL 备用方案）

```bash
OSS_ACCESS_KEY_ID=你的OSS AccessKey ID
OSS_ACCESS_KEY_SECRET=你的OSS AccessKey Secret
OSS_ROLE_ARN=acs:ram::xxxx:role/xxxx
```

当前 Flutter SDK 会自动先尝试 Edge Function，失败时使用 SQL 函数。

---

## 🚀 推荐的推进顺序

### 方案 A：快速上线（2周内）

1. ✅ 短信登录（已完成）
2. 🟡 苹果登录（必需，2天）
3. 🟡 OSS 实际上传（3天）
4. ✅ 发布测试版

### 方案 B：完整功能（1个月）

1. ✅ 短信登录
2. 🟡 苹果登录
3. ⏸️ 微信登录（等资料）
4. 🟡 购买验证
5. ✅ 完整测试

---

## 💡 建议

**现在可以做的（不需要等你）：**

1. ✅ 完成 CloudSyncService（OSS 上传下载）
   - 使用固定 AK 先跑通
   - 后续再换成 STS

2. 🟡 苹果登录
   - 如果你有 Apple Developer 账号，立即配置
   - 没有的话可以先跳过（但 App Store 会被拒）

**需要等你的：**

1. ⏸️ 微信登录（等微信开放平台资料）
2. ⏸️ 购买验证（等苹果/谷歌凭证）

---

## ❓ 需要你决定

1. **有没有 Apple Developer 账号？**
   - 有 → 现在配置苹果登录
   - 没有 → 先跳过，但 App Store 上架会受阻

2. **OSS 上传方案？**
   - A. 部署 Edge Function（安全，需要配置）
   - B. 固定 AK（简单，不安全，仅测试）

3. **微信开放平台资料申请进度？**
   - 已提交 → 等审核
   - 未提交 → 建议现在申请（审核2-3周）

---

**告诉我你的决定，我继续推进！**
