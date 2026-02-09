import 'package:flutter/material.dart';
import 'package:rocket_workshop_auth/rocket_workshop_auth.dart';
import '../main.dart';

/// 同步测试页面
class SyncDemoPage extends StatefulWidget {
  const SyncDemoPage({super.key});

  @override
  State<SyncDemoPage> createState() => _SyncDemoPageState();
}

class _SyncDemoPageState extends State<SyncDemoPage> {
  String _deviceId = 'test-device-id-001'; // Mock Device ID
  String? _currentPath;
  bool _isLoading = false;
  String? _message;
  final TextEditingController _receiptController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentPath = '$_deviceId/user_data.db';
    
    // Initialize CloudSyncService with mock config for demo
    cloudSync.initialize(CloudSyncConfig(
      env: Environment.env,
      appSlug: 'shenlun',
      deviceId: _deviceId,
    ));
  }

  @override
  void dispose() {
    _receiptController.dispose();
    super.dispose();
  }

  void _simulateLogin() {
    // Check if real login exists
    if (!authSDK.isLoggedIn) {
       setState(() => _message = '请先在"首页"登录 Supabase 账号');
       return;
    }
    
    setState(() {
      _isLoading = true;
      _message = null;
    });

    // Simulate switching context
    Future.delayed(const Duration(milliseconds: 500), () {
      final userId = authSDK.currentUser!.id;
      // Switch to user path in service
      cloudSync.switchToUserPath(userId);
      
      setState(() {
        _currentPath = cloudSync.currentPath;
        _isLoading = false;
        _message = '已切换到用户路径: $_currentPath';
      });
    });
  }

  void _simulateLogout() {
    cloudSync.switchToDevicePath();
    setState(() {
      _currentPath = cloudSync.currentPath;
      _message = '已切换回设备路径';
    });
  }

  Future<void> _testSync() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _message = '正在执行全量迁移...';
    });

    try {
      final result = await cloudSync.migrateAllData(
        receipt: _receiptController.text.isNotEmpty ? _receiptController.text : null,
      );
      
      setState(() {
        _isLoading = false;
        if (result.success) {
           _message = '✅ 迁移成功！\n数据已同步到: ${result.path}';
           _currentPath = result.path;
        } else {
           _message = '❌ 迁移失败: ${result.error}';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _message = '❌ 异常: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('云同步测试'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 环境信息
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '环境信息',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text('Schema: ${Environment.schema}'),
                    Text('OSS Prefix: ${Environment.ossPrefix}'),
                    Text('App ID: shenlun'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 设备/用户状态
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '当前存储路径',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: SelectableText(
                        _currentPath ?? '未知',
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _currentPath?.startsWith('users/') == true
                          ? '✅ 已登录状态 - 数据多设备共享'
                          : '📱 设备模式 - 数据仅本设备可用',
                      style: TextStyle(
                        color: _currentPath?.startsWith('users/') == true
                            ? Colors.green
                            : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 操作按钮
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _simulateLogin,
                    icon: const Icon(Icons.login),
                    label: const Text('模拟登录'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _simulateLogout,
                    icon: const Icon(Icons.logout),
                    label: const Text('模拟退出'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testSync,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload),
              label: const Text('测试同步'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),

            // 消息显示
            if (_message != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(_message!),
              ),
            ],

            const Spacer(),

            // 提示
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.yellow.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.yellow.shade200),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💡 测试说明',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text('• 测试环境数据与线上隔离'),
                  Text('• 真实登录请使用"首页"功能'),
                  Text('• 输入 Receipt 数据测试购买迁移'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
