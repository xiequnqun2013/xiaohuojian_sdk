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
  String _deviceId = '模拟设备 ID';
  String? _currentPath;
  bool _isLoading = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _currentPath = '$_deviceId/user_data.db';
  }

  void _simulateLogin() {
    setState(() {
      _isLoading = true;
      _message = null;
    });

    // 模拟登录后切换到用户路径
    Future.delayed(const Duration(seconds: 1), () {
      final userId = authSDK.currentUser?.id ?? 'mock-user-id';
      setState(() {
        _currentPath = 'users/$userId/shenlun/user_data.db';
        _isLoading = false;
        _message = '已切换到用户路径（登录状态）';
      });
    });
  }

  void _simulateLogout() {
    setState(() {
      _currentPath = '$_deviceId/user_data.db';
      _message = '已切换到设备路径（未登录）';
    });
  }

  Future<void> _testSync() async {
    setState(() {
      _isLoading = true;
      _message = '正在同步...';
    });

    // TODO: 实际调用 CloudSyncService
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isLoading = false;
      _message = '同步成功！数据已上传到：\n$_currentPath';
    });
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
                  Text('• CloudSyncService 尚未实现'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
