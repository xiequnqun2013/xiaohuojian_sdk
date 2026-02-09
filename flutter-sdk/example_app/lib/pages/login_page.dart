import 'package:flutter/material.dart';
import 'package:rocket_workshop_auth/rocket_workshop_auth.dart';
import '../main.dart';

/// 登录页面
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
  int _countdown = 0;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  /// 发送验证码
  Future<void> _sendCode() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length != 11) {
      setState(() => _errorMessage = '请输入正确的11位手机号');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await authSDK.sendSMSCode(phone);

    setState(() {
      _isLoading = false;
      if (result.success) {
        _codeSent = true;
        _startCountdown();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('验证码已发送')),
        );
      } else {
        _errorMessage = result.error;
      }
    });
  }

  /// 开始倒计时
  void _startCountdown() {
    setState(() => _countdown = 60);
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() => _countdown--);
      }
      return _countdown > 0 && mounted;
    });
  }

  /// 验证登录
  Future<void> _verifyAndLogin() async {
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();
    
    if (code.isEmpty || code.length != 6) {
      setState(() => _errorMessage = '请输入6位验证码');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await authSDK.verifySMSCode(phone, code);

    setState(() => _isLoading = false);

    if (!result.success) {
      setState(() => _errorMessage = result.error);
    }
    // 登录成功会自动触发 onAuthStateChange，页面自动跳转
  }

  /// 测试账号登录 (Bypass)
  Future<void> _loginAsTestUser() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _errorMessage = '请输入测试手机号');
      return;
    }
    
    debugPrint('Attempts to login with debug phone: $phone');

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 尝试调试登录
      final result = await authSDK.signInWithDebugPhone(phone);
      if (!result.success) {
        setState(() => _errorMessage = result.error);
      }
    } catch (e) {
      setState(() => _errorMessage = '测试登录失败: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('小火箭 SDK 测试'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 环境标签
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Environment.isTest ? Colors.orange.shade100 : Colors.green.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '当前环境: ${Environment.isTest ? "测试环境" : "线上环境"}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Environment.isTest ? Colors.orange.shade800 : Colors.green.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            // 标题
            const Text(
              '手机号登录',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // 手机号输入
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              maxLength: 11,
              decoration: InputDecoration(
                labelText: '手机号',
                hintText: '请输入11位手机号',
                prefixIcon: const Icon(Icons.phone),
                border: const OutlineInputBorder(),
                counterText: '',
                enabled: !_codeSent,
              ),
            ),
            const SizedBox(height: 16),

            // 发送验证码按钮
            if (!_codeSent)
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _sendCode,
                icon: _isLoading 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: const Text('发送验证码'),
                style: ElevatedButton.styleFrom(
                ),
              ),

             // 测试环境快捷登录
            if (Environment.isTest && !_codeSent) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _loginAsTestUser,
                icon: const Icon(Icons.bug_report),
                label: const Text('测试登录 (New)'),
              ),
            ],

            // 验证码输入
            if (_codeSent) ...[
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: '验证码',
                  hintText: '请输入6位验证码',
                  prefixIcon: const Icon(Icons.lock),
                  border: const OutlineInputBorder(),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 16),
              
              ElevatedButton(
                onPressed: _isLoading ? null : _verifyAndLogin,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('登录'),
              ),
              const SizedBox(height: 8),
              
              TextButton(
                onPressed: _countdown > 0 
                    ? null 
                    : () {
                        setState(() {
                          _codeSent = false;
                          _codeController.clear();
                        });
                      },
                child: Text(
                  _countdown > 0 
                      ? '重新发送 ($_countdown)' 
                      : '重新发送',
                ),
              ),
            ],

            // 错误提示
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
