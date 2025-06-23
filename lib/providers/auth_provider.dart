import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/user.dart';
import '../models/dog.dart';
import '../models/expense.dart';
import '../services/auth_service.dart';
import '../services/local_storage_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  
  AppUser? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isInitialized = false;

  AppUser? get currentUser => _currentUser;
  AppUser? get user => _currentUser; // Alias for compatibility
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;
  bool get isInitialized => _isInitialized;
  bool get canEdit => _currentUser?.isOwner ?? false;

  AuthProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    _setLoading(true);
    
    try {
      // 检查是否在演示模式
      final isDemo = _isInDemoMode();
      
      if (!isDemo) {
        // Check if user is already logged in
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          await _loadUserProfile(session.user.id);
        }
        
        // Listen to auth state changes
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
          final event = data.event;
          final session = data.session;
          
          if (event == AuthChangeEvent.signedIn && session != null) {
            _loadUserProfile(session.user.id);
          } else if (event == AuthChangeEvent.signedOut) {
            _clearUser();
          }
        });
      } else {
        // 演示模式：尝试从本地存储加载用户信息
        final savedUser = await LocalStorageService.getCachedUser();
        if (savedUser != null) {
          _currentUser = savedUser;
        }
      }
      
    } catch (e) {
      print('AuthProvider初始化失败: $e');
      // 在演示模式下，尝试从本地存储加载
      try {
        final savedUser = await LocalStorageService.getCachedUser();
        if (savedUser != null) {
          _currentUser = savedUser;
        }
      } catch (e2) {
        print('本地存储加载失败: $e2');
      }
    } finally {
      _isInitialized = true;
      _setLoading(false);
    }
  }

  bool _isInDemoMode() {
    try {
      // 检查Supabase配置是否为演示配置
      return SupabaseConfig.url.isEmpty || 
             SupabaseConfig.url.contains('demo.supabase.co');
    } catch (e) {
      return true; // 如果无法访问，假设是演示模式
    }
  }

  Future<bool> signIn(String email, String password) async {
    _setLoading(true);
    _clearError();
    
    try {
      if (_isInDemoMode()) {
        // 演示模式：创建演示用户
        _currentUser = AppUser(
          id: '00000000-0000-0000-0000-000000000002',
          email: email,
          displayName: email.split('@')[0],
          role: UserRole.owner,
          createdAt: DateTime.now(),
        );
        await LocalStorageService.cacheUser(_currentUser!);
        notifyListeners();
        return true;
      } else {
        final response = await _authService.signIn(email, password);
        if (response.user != null) {
          await _loadUserProfile(response.user!.id);
          return true;
        }
        return false;
      }
    } catch (e) {
      _setError('登录失败: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signUp(String email, String password, {String? displayName}) async {
    _setLoading(true);
    _clearError();
    
    try {
      if (_isInDemoMode()) {
        // 演示模式：创建演示用户并直接登录
        _currentUser = AppUser(
          id: '00000000-0000-0000-0000-000000000002',
          email: email,
          displayName: displayName ?? email.split('@')[0],
          role: UserRole.owner,
          createdAt: DateTime.now(),
        );
        await LocalStorageService.cacheUser(_currentUser!);
        notifyListeners();
        return true;
      } else {
        final response = await _authService.signUp(email, password, displayName: displayName);
        if (response.user != null) {
          // User will be automatically signed in after email confirmation
          return true;
        }
        return false;
      }
    } catch (e) {
      _setError('注册失败: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signInWithMagicLink(String email) async {
    _setLoading(true);
    _clearError();
    
    try {
      if (_isInDemoMode()) {
        // 演示模式：模拟成功
        return true;
      } else {
        await _authService.signInWithMagicLink(email);
        return true;
      }
    } catch (e) {
      _setError('发送魔法链接失败: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// 演示登录 - 创建演示管理员账号
  Future<bool> signInAsDemo() async {
    _setLoading(true);
    _clearError();
    
    try {
      // 创建演示管理员用户
      _currentUser = AppUser(
        id: '00000000-0000-0000-0000-000000000001',
        email: 'admin@demo.com',
        displayName: '演示管理员',
        role: UserRole.owner,
        createdAt: DateTime.now(),
      );
      
      // 保存到本地存储
      await LocalStorageService.cacheUser(_currentUser!);
      
      // 创建一些演示数据
      await _createDemoData();
      
      notifyListeners();
      return true;
    } catch (e) {
      _setError('演示登录失败: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// 创建演示数据
  Future<void> _createDemoData() async {
    try {
      await _createDemoDogs();
      await _createDemoExpenseCategories();
      await _createDemoExpenses();
      print('演示数据已准备就绪');
    } catch (e) {
      print('创建演示数据时出错: $e');
    }
  }

  /// 创建演示狗狗数据
  Future<void> _createDemoDogs() async {
    final demoDogs = [
      {
        'dog_id': 'demo-dog-1',
        'name': '小白',
        'breed': '比熊犬',
        'date_of_birth': DateTime.now().subtract(const Duration(days: 365)).toIso8601String(),
        'sex': 'female',
        'weight': 3.5,
        'description': '温顺可爱的小比熊，毛色纯白，性格活泼',
        'purchase_price': 3000.0,
        'sale_price': null,
        'status': 'available',
        'image_urls': [],
        'created_by': '00000000-0000-0000-0000-000000000001',
        'created_at': DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
        'updated_at': DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
      },
      {
        'dog_id': 'demo-dog-2',
        'name': '金金',
        'breed': '金毛犬',
        'date_of_birth': DateTime.now().subtract(const Duration(days: 730)).toIso8601String(),
        'sex': 'male',
        'weight': 25.8,
        'description': '聪明温顺的金毛，训练有素，适合家庭饲养',
        'purchase_price': 2500.0,
        'sale_price': 4200.0,
        'status': 'sold',
        'image_urls': [],
        'created_by': '00000000-0000-0000-0000-000000000001',
        'created_at': DateTime.now().subtract(const Duration(days: 60)).toIso8601String(),
        'updated_at': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
      },
      {
        'dog_id': 'demo-dog-3',
        'name': '可可',
        'breed': '泰迪犬',
        'date_of_birth': DateTime.now().subtract(const Duration(days: 180)).toIso8601String(),
        'sex': 'female',
        'weight': 2.1,
        'description': '棕色小泰迪，刚刚完成疫苗接种',
        'purchase_price': 1800.0,
        'sale_price': null,
        'status': 'available',
        'image_urls': [],
        'created_by': '00000000-0000-0000-0000-000000000001',
        'created_at': DateTime.now().subtract(const Duration(days: 15)).toIso8601String(),
        'updated_at': DateTime.now().subtract(const Duration(days: 15)).toIso8601String(),
      },
    ];

    await LocalStorageService.cacheDogs(demoDogs.map((e) => Dog.fromMap(e)).toList());
  }

  /// 创建演示费用类别
  Future<void> _createDemoExpenseCategories() async {
    final demoCategories = [
      ExpenseCategory(
        catId: 'demo-cat-1',
        name: '食物费用',
        isShared: true,
      ),
      ExpenseCategory(
        catId: 'demo-cat-2',
        name: '医疗费用',
        isShared: false,
      ),
      ExpenseCategory(
        catId: 'demo-cat-3',
        name: '美容费用',
        isShared: false,
      ),
    ];

    await LocalStorageService.cacheCategories(demoCategories);
  }

  /// 创建演示费用记录
  Future<void> _createDemoExpenses() async {
    final demoExpenses = [
      Expense(
        expId: 'demo-exp-1',
        catId: 'demo-cat-1',
        amount: 120.0,
        date: DateTime.now().subtract(const Duration(days: 7)),
        note: '购买狗粮 - 皇家小型犬成犬粮',
        createdBy: '00000000-0000-0000-0000-000000000001',
        createdAt: DateTime.now().subtract(const Duration(days: 7)),
        dogLinks: [
          ExpenseDogLink(
            expId: 'demo-exp-1',
            dogId: 'demo-dog-1',
            shareRatio: 0.6,
          ),
          ExpenseDogLink(
            expId: 'demo-exp-1',
            dogId: 'demo-dog-3',
            shareRatio: 0.4,
          ),
        ],
      ),
      Expense(
        expId: 'demo-exp-2',
        catId: 'demo-cat-2',
        amount: 280.0,
        date: DateTime.now().subtract(const Duration(days: 14)),
        note: '小白疫苗接种 - 第二剂',
        createdBy: '00000000-0000-0000-0000-000000000001',
        createdAt: DateTime.now().subtract(const Duration(days: 14)),
        dogLinks: [
          ExpenseDogLink(
            expId: 'demo-exp-2',
            dogId: 'demo-dog-1',
            shareRatio: 1.0,
          ),
        ],
      ),
      Expense(
        expId: 'demo-exp-3',
        catId: 'demo-cat-3',
        amount: 80.0,
        date: DateTime.now().subtract(const Duration(days: 3)),
        note: '可可洗澡美容',
        createdBy: '00000000-0000-0000-0000-000000000001',
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        dogLinks: [
          ExpenseDogLink(
            expId: 'demo-exp-3',
            dogId: 'demo-dog-3',
            shareRatio: 1.0,
          ),
        ],
      ),
    ];

    await LocalStorageService.cacheExpenses(demoExpenses);
  }

  Future<void> signOut() async {
    _setLoading(true);
    
    try {
      if (!_isInDemoMode()) {
        await _authService.signOut();
      }
      await LocalStorageService.clearAll();
      _clearUser();
    } catch (e) {
      print('登出失败: $e');
      // 即使出错也要清除本地用户信息
      _clearUser();
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> resetPassword(String email) async {
    _setLoading(true);
    _clearError();
    
    try {
      if (_isInDemoMode()) {
        // 演示模式：模拟成功
        return true;
      } else {
        await _authService.resetPassword(email);
        return true;
      }
    } catch (e) {
      _setError('重置密码失败: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateProfile({
    String? displayName,
    String? avatarUrl,
  }) async {
    if (_currentUser == null) return false;
    
    _setLoading(true);
    _clearError();
    
    try {
      final updatedUser = await _authService.updateUserProfile(
        _currentUser!.id,
        displayName: displayName,
        avatarUrl: avatarUrl,
      );
      
      if (updatedUser != null) {
        _currentUser = updatedUser;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _setError('更新资料失败: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updatePassword(String currentPassword, String newPassword) async {
    _setLoading(true);
    _clearError();
    
    try {
      await _authService.updatePassword(currentPassword, newPassword);
      return true;
    } catch (e) {
      _setError('修改密码失败: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _loadUserProfile(String userId) async {
    try {
      final user = await _authService.getUserProfile(userId);
      if (user != null) {
        _currentUser = user;
        notifyListeners();
      }
    } catch (e) {
      _setError('加载用户资料失败: $e');
    }
  }

  void _clearUser() {
    _currentUser = null;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _clearError();
  }
}