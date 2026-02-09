import 'package:flutter/material.dart';
import 'package:rocket_workshop_auth/rocket_workshop_auth.dart';

/// 登录页面示例
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  
  bool _isLoading = false;
  bool _codeSent = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  /// 发送验证码
  Future<void> _sendCode() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await authSDK.sendSMSCode(_phoneController.text.trim());

    setState(() {
      _isLoading = false;
      if (result.success) {
        _codeSent = true;
      } else {
        _errorMessage = result.error;
      }
    });
  }

  /// 验证登录
  Future<void> _verifyAndLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await authSDK.verifySMSCode(
      _phoneController.text.trim(),
      _codeController.text.trim(),
    );

    setState(() {
      _isLoading = false;
      if (!result.success) {
        _errorMessage = result.error;
      }
    });

    // 登录成功会自动触发 onAuthStateChange，页面自动跳转
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('登录')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 手机号输入
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: '手机号',
                hintText: '请输入手机号',
                prefixIcon: Icon(Icons.phone),
              ),
              enabled: !_codeSent,
            ),
            const SizedBox(height: 16),

            // 发送验证码按钮
            if (!_codeSent)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _sendCode,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('发送验证码'),
                ),
              ),

            // 验证码输入
            if (_codeSent) ...[
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '验证码',
                  hintText: '请输入6位验证码',
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyAndLogin,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('登录'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    _codeSent = false;
                    _codeController.clear();
                  });
                },
                child: const Text('重新发送'),
              ),
            ],

            // 错误提示
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 主页面示例（监听登录状态）
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: authSDK.onAuthStateChange,
      builder: (context, snapshot) {
        if (authSDK.isLoggedIn) {
          return const HomePage();
        } else {
          return const LoginPage();
        }
      },
    );
  }
}

/// 首页示例
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('首页'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => authSDK.signOut(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('登录成功！'),
            const SizedBox(height: 16),
            Text('用户ID: ${authSDK.currentUser?.id ?? ""}'),
          ],
        ),
      ),
    );
  }
}
