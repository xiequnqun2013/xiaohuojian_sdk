# 脚本说明

本目录包含项目的部署、测试和工具脚本。

## 目录结构

```
scripts/
├── deploy/              # 部署脚本
│   ├── deploy_edge_functions.sh    # 部署所有 Edge Functions
│   ├── deploy_edge_function.sh     # 部署单个 Edge Function
│   ├── deploy_function.sh          # 通用函数部署脚本
│   └── deploy_oss_full.sh          # OSS 完整部署
├── test/                # 测试脚本
│   ├── test_edge_function.sh       # 测试 Edge Function
│   ├── test_login_complete.sh      # 测试完整登录流程
│   └── test_sms_api.sh             # 测试短信 API
├── backup.sh            # 数据库备份脚本
└── setup_oss_for_flutter.py  # OSS 配置工具
```

## 部署脚本

### deploy_edge_functions.sh

部署所有 Edge Functions 到 Supabase。

**使用方法：**
```bash
cd scripts/deploy
./deploy_edge_functions.sh
```

**功能：**
- 部署 auth-wechat
- 部署 debug-login
- 部署 get-oss-sts
- 部署 migrate-device-purchase
- 部署 send-sms
- 部署 verify-ios-receipt

### deploy_edge_function.sh

部署单个 Edge Function。

**使用方法：**
```bash
cd scripts/deploy
./deploy_edge_function.sh <function-name>
```

## 测试脚本

### test_edge_function.sh

测试已部署的 Edge Function。

**使用方法：**
```bash
cd scripts/test
./test_edge_function.sh
```

### test_login_complete.sh

测试完整的登录流程（发送验证码 + 验证登录）。

**使用方法：**
```bash
cd scripts/test
./test_login_complete.sh
```

### test_sms_api.sh

测试短信发送 API。

**使用方法：**
```bash
cd scripts/test
./test_sms_api.sh
```

## 工具脚本

### backup.sh

备份 Supabase 数据库。

**使用方法：**
```bash
cd scripts
./backup.sh
```

### setup_oss_for_flutter.py

配置阿里云 OSS 用于 Flutter SDK。

**使用方法：**
```bash
cd scripts
python3 setup_oss_for_flutter.py
```

## 环境变量

大部分脚本需要以下环境变量（在 `.env.local` 中配置）：

```bash
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
ALIBABA_CLOUD_ACCESS_KEY_ID=your_access_key_id
ALIBABA_CLOUD_ACCESS_KEY_SECRET=your_access_key_secret
```

## 注意事项

- 🔒 部署脚本需要 Supabase Service Role Key
- 🔒 确保 `.env.local` 文件不被提交到 Git
- ⚠️ 生产环境部署前请先在测试环境验证
