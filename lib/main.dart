import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'providers/auth_provider.dart';
import 'providers/dog_provider.dart';
import 'providers/expense_provider.dart';
import 'routes/app_router.dart';
import 'theme/app_theme.dart';
import 'services/local_storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化Supabase - 如果没有配置则使用演示配置
  try {
    String url = SupabaseConfig.url;
    String anonKey = SupabaseConfig.anonKey;
    
    // 如果配置为空，使用虚拟配置以避免初始化错误
    if (url.isEmpty || anonKey.isEmpty) {
      url = 'https://demo.supabase.co';
      anonKey = 'demo-anon-key-placeholder-for-offline-mode';
      print('未配置Supabase，应用将在演示模式下运行');
      print('要启用完整功能，请在lib/config/supabase_config.dart中配置Supabase');
    }
    
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  } catch (e) {
    print('Supabase初始化失败: $e');
    print('应用将在演示模式下运行');
    // 如果初始化失败，使用最小配置重试
    try {
      await Supabase.initialize(
        url: 'https://demo.supabase.co',
        anonKey: 'demo-anon-key-placeholder-for-offline-mode',
      );
    } catch (e2) {
      print('演示模式初始化也失败: $e2');
    }
  }
  
  // Initialize local storage
  await LocalStorageService.init();
  
  runApp(const PetProfitApp());
}

class PetProfitApp extends StatelessWidget {
  const PetProfitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DogProvider()),
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          return MaterialApp.router(
            title: 'Pet Profit Manager',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.system,
            routerConfig: AppRouter.router,
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}