import 'package:flutter/material.dart';
import 'package:rocket_workshop_auth/rocket_workshop_auth.dart';
import '../main.dart';

/// 首页
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Map<String, dynamic>? _profile;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await authSDK.getProfile();

    setState(() {
      _isLoading = false;
      if (result.success) {
        _profile = result.data!.toJson();
      } else {
        _error = result.error;
      }
    });
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认退出'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('退出'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await authSDK.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = authSDK.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('用户信息'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: '退出登录',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 环境标签
            Card(
              child: ListTile(
                leading: Icon(
                  Environment.isTest ? Icons.bug_report : Icons.cloud,
                  color: Environment.isTest ? Colors.orange : Colors.green,
                ),
                title: const Text('当前环境'),
                subtitle: Text(Environment.isTest ? '测试环境' : '线上环境'),
                trailing: Chip(
                  label: Text(Environment.schema),
                  backgroundColor: Environment.isTest 
                      ? Colors.orange.shade100 
                      : Colors.green.shade100,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 登录信息
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.person),
                    title: const Text('用户 ID'),
                    subtitle: Text(user?.id ?? '未知'),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () {
                        // 复制到剪贴板
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('用户 ID 已复制')),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.phone),
                    title: const Text('手机号'),
                    subtitle: Text(user?.phone ?? '未绑定'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.email),
                    title: const Text('邮箱'),
                    subtitle: Text(user?.email ?? '未绑定'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 用户资料
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    title: const Text(
                      '用户资料',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: _isLoading 
                        ? const SizedBox(
                            width: 20, 
                            height: 20, 
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: _loadProfile,
                          ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _error!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    )
                  else if (_profile != null) ...[
                    ListTile(
                      title: const Text('昵称'),
                      subtitle: Text(_profile!['nickname'] ?? '未设置'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('头像'),
                      subtitle: Text(_profile!['avatar_url'] ?? '未设置'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('创建时间'),
                      subtitle: Text(_profile!['created_at'] ?? '未知'),
                    ),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
