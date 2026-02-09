import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rocket_workshop_auth/rocket_workshop_auth.dart';

import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'pages/sync_demo_page.dart';

/// 环境配置
/// 
/// 测试环境: flutter run --dart-define=ENV=test
/// 线上环境: flutter run --dart-define=ENV=prod
/// 
/// 全局配置在: rocket_workshop_auth/lib/src/config.dart
class Environment {
  static const String env = String.fromEnvironment('ENV', defaultValue: 'test');
  static bool get isTest => env == 'test';
  static bool get isProd => env == 'prod';
  
  static String get schema => isTest ? 'test_public' : 'public';
  static String get ossPrefix => isTest ? 'test' : 'prod';
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化 SDK（配置从 config.dart 读取，无需硬编码）
  await RocketWorkshopAuth().initialize(
    AuthConfig.staging(appId: 'shenlun'),
  );
  
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '小火箭 SDK 测试',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

/// 认证状态包装器
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: authSDK.onAuthStateChange,
      builder: (context, snapshot) {
        if (authSDK.isLoggedIn) {
          return const MainPage();
        } else {
          return const LoginPage();
        }
      },
    );
  }
}

/// 主页面（底部导航）
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;
  
  final _pages = [
    const HomePage(),
    const SyncDemoPage(),
  ];
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.cloud_sync),
            label: '同步测试',
          ),
        ],
      ),
    );
  }
}
