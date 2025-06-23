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
  
  // 初始化Supabase - 恢复联网功能
  try {
    print('🌐 正在连接到Supabase数据库...');
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
    print('✅ Supabase连接成功！');
    print('📊 应用将使用在线数据库');
  } catch (e) {
    print('⚠️ Supabase连接失败: $e');
    print('🔄 将使用本地缓存数据，删除功能仍可正常使用');
    // 连接失败不影响应用启动，只是功能会受限
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