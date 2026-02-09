# 多 App 用户数据同步架构设计（设备云存储 → 账号体系）

> 文档目的：将原有"设备级云端存储"升级为"可选的账号体系"  
> 核心变更：OSS 路径从 `{device_id}/` 变为 `users/{user_id}/`  
> 原则：不强制登录，用户主动选择后才迁移到账号体系

---

## 1. 背景与现状

### 1.1 现状（已存在）

```
阿里云 OSS
├── {device_id_a}/                    ← 设备 A 的数据
│   ├── user_data.db                  ← 用户数据（SQLite）
│   ├── purchase.receipt              ← 购买凭证
│   └── backup/
│       └── 20240101.db
│
├── {device_id_b}/                    ← 设备 B 的数据
│   └── user_data.db
│
└── content/                          ← 应用内容（多设备共享）
    └── shenlun/
        └── content.db
```

**当前逻辑**：
- 数据按 `device_id` 存到 OSS
- 换设备 = 新 `device_id` = 数据丢失
- 购买绑定设备，换设备需重新购买

### 1.2 目标

```
阿里云 OSS
├── users/{user_id}/                  ← 新增：用户级存储
│   ├── shenlun/
│   │   └── user_data.db              ← 多设备共享
│   └── xingce/
│       └── user_data.db
│
├── devices/{device_id}/              ← 迁移标记
│   └── migration.json                ← 记录迁移到哪个 user_id
│
├── archive/                          ← 归档（可选）
│   └── {device_id}/                  ← 旧数据保留一段时间
│
└── content/                          ← 不变
    └── shenlun/
        └── content.db
```

**升级后逻辑**：
- 默认：数据仍按 `device_id` 存（维持现状）
- 登录后：数据迁移到 `users/{user_id}/`，多设备共享
- 购买绑定账号，换设备登录即恢复

---

## 2. 整体架构

```
┌─────────────────────────────────────────────────────────────────┐
│  阿里云 OSS                                                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  📁 默认状态（未登录）                                            │
│  ├── {device_id}/                                               │
│  │   ├── user_data.db              ← 用户数据                    │
│  │   └── purchase.receipt          ← 购买凭证（设备绑定）         │
│  └── ...                                                        │
│                                                                 │
│  📁 登录后（多设备同步）                                          │
│  ├── users/{user_id}/                                           │
│  │   ├── shenlun/                                               │
│  │   │   └── user_data.db          ← 多设备共享                  │
│  │   └── xingce/                                                │
│  │       └── user_data.db                                       │
│  │                                                              │
│  └── devices/{device_id}/                                       │
│      └── migration.json            ← 迁移标记（device→user）      │
│                                                                 │
│  📁 公共内容（不变）                                              │
│  └── content/{app_slug}/content.db                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ HTTPS / OSS SDK
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  用户手机（Flutter App）                                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  🟢 Supabase（仅用于登录和元数据）                                 │
│  ├── Auth：手机号/微信/苹果登录                                    │
│  └── user_devices：记录 device→user 映射                         │
│                                                                 │
│  📱 本地 SQLite                                                  │
│  └── user_data.db                  ← 本地缓存                    │
│                                                                 │
│  🔄 Sync Service                                                 │
│  ├── 默认：syncToDevicePath()      ← 上传到 {device_id}/         │
│  └── 登录后：syncToUserPath()      ← 上传到 users/{user_id}/     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## 2.5 账号与鉴权体系 (Identity & Auth)

本系统支持多种登录方式，统一映射到 Supabase `auth.users` 表。

### 2.5.1 支持的登录方式
1.  **手机号 + 验证码**：(已实现) 使用 Supabase Mobile Auth。
2.  **苹果登录 (Sign in with Apple)**：(P0) iOS 必需。使用 Supabase Native Apple Login。
3.  **微信登录**：(P1) 使用自定义 Edge Function `auth-wechat` 交换 OpenID，生成 Custom JWT 或关联现有账号。

### 2.5.2 账号关联逻辑
- 原则：**以手机号为核心**。
- 微信/苹果登录后，建议引导绑定手机号，以实现夸平台（iOS <-> Android）和跨账号体系的数据互通。
- `auth.identities` 表由 Supabase 自动管理多重身份绑定。

---

## 3. 核心流程

### 3.1 默认流程（未登录 - 维持现状）

```dart
class CloudSyncService {
  final String deviceId;
  String? userId;  // 登录后才有
  
  /// 获取当前 OSS 路径
  String get ossPath {
    if (userId != null) {
      return 'users/$userId/$appSlug/user_data.db';
    }
    return '$deviceId/user_data.db';
  }
  
  /// 同步数据到云端（自动调用）
  Future<void> sync() async {
    final localFile = await LocalDB.getFile();
    await OSS.upload(localFile, ossPath);
  }
  
  /// 从云端恢复数据
  Future<void> restore() async {
    if (!await OSS.exists(ossPath)) return;
    
    await OSS.download(ossPath, LocalDB.getPath());
  }
}

// 使用（和现状完全一致）
final sync = CloudSyncService(deviceId: await getDeviceId());

// App 启动时恢复
await sync.restore();

// 数据变更后同步
await sync.sync();
```

### 3.2 用户触发登录 → 数据迁移

```dart
/// 用户点击"开启多设备同步"
Future<void> enableMultiDeviceSync() async {
  // 1. 弹出登录
  final result = await showLoginDialog();
  if (result == null) return;  // 用户取消
  
  final newUserId = result.userId;
  
  // 2. 显示迁移进度
  final progress = showMigrationProgress();
  
  try {
    // 3. 下载设备数据（如有）
    progress.value = "检查现有数据...";
    final hasDeviceData = await OSS.exists('$deviceId/user_data.db');
    
    if (hasDeviceData) {
      // 4. 上传到用户路径
      progress.value = "迁移数据到账号...";
      await OSS.copy(
        '$deviceId/user_data.db',
        'users/$newUserId/$appSlug/user_data.db'
      );
    }
    
    // 5. 迁移购买凭证（关键！）
    progress.value = "恢复购买记录...";
    await _migratePurchase(newUserId);
    
    // 6. 记录迁移标记
    await OSS.writeJson(
      'devices/$deviceId/migration.json',
      {
        'user_id': newUserId,
        'migrated_at': DateTime.now().toIso8601String(),
        'app_slug': appSlug,
      }
    );
    
    // 7. 写入 Supabase（方便查询）
    await Supabase.instance.client.from('user_devices').insert({
      'device_id': deviceId,
      'user_id': newUserId,
      'app_slug': appSlug,
      'migrated_at': DateTime.now().toIso8601String(),
    });
    
    // 8. 切换路径
    userId = newUserId;
    
    progress.value = "完成！";
    await Future.delayed(Duration(seconds: 1));
    
  } catch (e) {
    progress.value = "迁移失败: $e";
    await Future.delayed(Duration(seconds: 2));
  } finally {
    progress.dismiss();
  }
}

/// 迁移购买凭证
Future<void> _migratePurchase(String newUserId) async {
  // 检查设备上的购买凭证
  final receiptExists = await OSS.exists('$deviceId/purchase.receipt');
  if (!receiptExists) return;
  
  final receipt = await OSS.readString('$deviceId/purchase.receipt');
  
  // 调用服务端验证并绑定到新用户
  final result = await Supabase.instance.client.functions.invoke(
    'migrate-device-purchase',
    body: {
      'device_id': deviceId,
      'user_id': newUserId,
      'app_slug': appSlug,
      'receipt': receipt,
    },
  );
  
  if (result.data['success']) {
    // 购买迁移成功，标记设备为会员
    print('购买凭证迁移成功');
  } else {
    // 凭证无效或已使用，提示用户联系客服
    showDialog(
      title: '购买恢复失败',
      content: '请提供购买截图联系客服处理',
    );
  }
}
```

### 3.3 新设备登录 → 恢复数据

```dart
/// 新设备安装 App，用户登录后
Future<void> restoreOnNewDevice() async {
  // 1. 用户登录
  final result = await showLoginDialog();
  if (result == null) return;
  
  final existingUserId = result.userId;
  
  // 2. 检查该用户是否有云端数据
  final hasCloudData = await OSS.exists(
    'users/$existingUserId/$appSlug/user_data.db'
  );
  
  if (hasCloudData) {
    // 3. 下载云端数据
    showLoading('恢复数据中...');
    await OSS.download(
      'users/$existingUserId/$appSlug/user_data.db',
      LocalDB.getPath()
    );
    hideLoading();
    
    showToast('数据恢复成功');
  } else {
    // 4. 该账号无数据，询问是否从其他设备迁移
    final shouldMigrate = await showConfirmDialog(
      title: '未发现云端数据',
      content: '是否从当前设备迁移数据到此账号？',
    );
    
    if (shouldMigrate) {
      // 当前设备数据上传到云端
      await OSS.upload(
        LocalDB.getFile(),
        'users/$existingUserId/$appSlug/user_data.db'
      );
    }
  }
  
  // 5. 设置当前路径为用户路径
  userId = existingUserId;
}
```

### 3.4 多端数据合并（用户在多设备都有数据）

```dart
/// 用户 deviceA 有数据，登录后发现 deviceB 也有数据
Future<void> mergeMultiDeviceData(String userId) async {
  // 1. 查询该用户关联的所有设备
  final devices = await Supabase.instance.client
      .from('user_devices')
      .select('device_id')
      .eq('user_id', userId);
  
  // 2. 收集所有设备数据
  final allData = <Map<String, dynamic>>[];
  
  for (final device in devices) {
    final deviceId = device['device_id'];
    final path = '$deviceId/user_data.db';
    
    if (await OSS.exists(path)) {
      // 下载并读取
      final tempFile = await OSS.downloadToTemp(path);
      final data = await readUserData(tempFile);
      allData.add({
        'device_id': deviceId,
        'data': data,
      });
    }
  }
  
  // 3. 合并数据（按业务规则）
  final merged = _mergeData(allData);
  
  // 4. 上传到用户路径
  final mergedFile = await createDatabase(merged);
  await OSS.upload(
    mergedFile,
    'users/$userId/$appSlug/user_data.db'
  );
}

Map<String, dynamic> _mergeData(List<Map> allData) {
  final merged = <String, dynamic>{
    'favorites': <String>{},  // 并集
    'notes': <String, Map>{}, // 按时间戳
    'history': <String>[],    // 去重合并
  };
  
  for (final deviceData in allData) {
    final data = deviceData['data'];
    
    // 收藏：并集
    merged['favorites'].addAll(data['favorites']?.map((f) => f['item_id']) ?? []);
    
    // 笔记：按更新时间保留最新
    for (final note in data['notes'] ?? []) {
      final existing = merged['notes'][note['item_id']];
      if (existing == null || note['updated_at'] > existing['updated_at']) {
        merged['notes'][note['item_id']] = note;
      }
    }
  }
  
  return merged;
}
```

---

## 4. Supabase 表设计（精简）

只需要 2 张表：

```sql
-- 1. 设备-用户映射表（记录哪些设备迁移到了哪个账号）
create table user_devices (
    id uuid default gen_random_uuid() primary key,
    device_id text not null,
    user_id uuid references auth.users(id) on delete cascade,
    app_slug text not null,
    
    is_migrated boolean default true,
    migrated_at timestamptz default now(),
    
    unique(device_id, app_slug)
);

-- RLS：用户只能看到自己的设备
alter table user_devices enable row level security;
create policy "Users can view own devices"
    on user_devices for select using (auth.uid() = user_id);

-- 2. 购买记录表（验证后写入，用于跨设备恢复）
create table user_purchases (
    id uuid default gen_random_uuid() primary key,
    user_id uuid references auth.users(id) on delete cascade,
    app_slug text not null,
    
    product_id text not null,
    platform text not null,  -- 'ios', 'android'
    
    transaction_id text unique,
    receipt_data text,
    receipt_hash text unique,  -- 去重
    
    migrated_from_device text,  -- 记录从哪个设备迁移
    
    is_valid boolean default true,
    purchased_at timestamptz,
    expires_at timestamptz,
    
    created_at timestamptz default now()
);

-- RLS
create policy "Users can view own purchases"
    on user_purchases for select using (auth.uid() = user_id);
```

---

## 5. Edge Functions

### 5.1 迁移设备购买凭证

```typescript
// supabase/functions/migrate-device-purchase/index.ts

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

serve(async (req) => {
  const { device_id, user_id, app_slug, receipt } = await req.json();
  
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  );
  
  // 1. 验证收据（向苹果/谷歌）
  const verification = await verifyReceipt(receipt, app_slug);
  
  if (!verification.valid) {
    return new Response(JSON.stringify({ 
      success: false, 
      error: 'Invalid receipt' 
    }));
  }
  
  // 2. 检查是否已存在（去重）
  const receiptHash = await hash(receipt);
  const { data: existing } = await supabase
    .from('user_purchases')
    .select('id')
    .eq('receipt_hash', receiptHash)
    .single();
    
  if (existing) {
    return new Response(JSON.stringify({ 
      success: false, 
      error: 'Receipt already used' 
    }));
  }
  
  // 3. 写入购买记录
  await supabase.from('user_purchases').insert({
    user_id,
    app_slug,
    product_id: verification.product_id,
    platform: verification.platform,
    transaction_id: verification.transaction_id,
    receipt_data: receipt,
    receipt_hash: receiptHash,
    migrated_from_device: device_id,
    is_valid: true,
    purchased_at: verification.purchased_at,
    expires_at: verification.expires_at,
  });
  
  return new Response(JSON.stringify({ success: true }));
});
```

---

## 6. 实施步骤（Todo）

### Phase 1：基础设施（Week 1）
- [ ] 创建 Supabase 项目
- [ ] 创建 `user_devices` 表
- [ ] 创建 `user_purchases` 表
- [ ] 配置 RLS 策略
- [ ] 接入 Supabase Auth（手机号）

### Phase 2：购买验证（Week 2）
- [ ] 创建 `migrate-device-purchase` Edge Function
- [ ] 实现苹果收据验证
- [ ] 实现谷歌收据验证
- [ ] 测试购买凭证迁移流程

### Phase 3：数据迁移（Week 3）
- [ ] 实现 `CloudSyncService` 类
- [ ] 实现设备路径 → 用户路径的数据复制
- [ ] 实现多设备数据合并逻辑
- [ ] 实现迁移进度 UI
- [ ] 测试数据完整性

### Phase 4：UI 交互（Week 4）
- [ ] 设计"开启多设备同步"入口
- [ ] 实现登录弹窗
- [ ] 实现迁移进度提示
- [ ] 实现新设备数据恢复流程
- [ ] 购买恢复失败时的客服引导

### Phase 5：多 App 适配（Week 5）
- [ ] 提取通用 SDK（rocket_user_sync）
- [ ] 在申论 App 集成测试
- [ ] 在行测 App 集成测试
- [ ] 验证跨 App 数据隔离

### Phase 6：灰度发布（Week 6）
- [ ] 内部测试（多设备场景）
- [ ] 10% 用户灰度
- [ ] 监控迁移成功率
- [ ] 全量发布

---

## 7. 注意事项

### 7.1 购买凭证处理
- 设备收据只能迁移一次，防止重复绑定
- 收据验证失败时，引导用户联系客服
- 保留原始收据，便于客服人工处理

### 7.2 数据合并策略
- 收藏：取并集
- 笔记：按更新时间保留最新
- 阅读历史：按时间合并去重
- 购买记录：严格去重（transaction_id）

### 7.3 回滚方案
- 迁移失败时保留原设备数据
- 提供"重新迁移"功能
- 用户可联系客服人工处理

### 7.4 成本预估
| 项目 | 费用 | 说明 |
|------|------|------|
| Supabase | 免费 | 初期免费额度够用 |
| OSS 存储 | ~50元/月 | 用户数据 doubling |
| OSS 流量 | ~100元/月 | 多设备同步增加 |

---

## 8. 关键决策点

| # | 问题 | 建议方案 |
|---|------|---------|
| 1 | 旧设备数据是否删除？ | **保留**，标记为已迁移，保留 90 天 |
| 2 | 多设备都有数据如何合并？ | **自动合并**（并集/时间戳优先） |
| 3 | 购买凭证迁移失败？ | **提示联系客服**，提供原始收据 |
| 4 | 用户注销账号？ | **保留 OSS 数据 30 天**，之后删除 |
| 5 | 同步冲突（同时修改）？ | **Last-write-wins**，简单有效 |

---

**文档版本**: 1.0  
**创建时间**: 2024-01-20  
**状态**: 待实施
