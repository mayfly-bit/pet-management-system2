import 'package:flutter/foundation.dart';
import '../models/expense.dart';
import '../services/expense_service.dart';
import '../services/local_storage_service.dart';
import '../services/auth_service.dart';
import '../config/supabase_config.dart';

class ExpenseProvider extends ChangeNotifier {
  final ExpenseService _expenseService = ExpenseService();
  
  List<Expense> _expenses = [];
  List<ExpenseCategory> _categories = [];
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _categoryFilter;
  String _searchQuery = '';

  List<Expense> get expenses => _getFilteredExpenses();
  List<Expense> get allExpenses => _expenses;
  List<Expense> get filteredExpenses => _getFilteredExpenses();
  List<ExpenseCategory> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get error => _errorMessage;
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;
  String? get categoryFilter => _categoryFilter;
  String get searchQuery => _searchQuery;

  // Statistics
  double get totalExpenses => _getFilteredExpenses()
      .fold(0.0, (sum, expense) => sum + expense.amount);
  
  double get monthlyExpenses {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);
    
    return _expenses
        .where((expense) => 
            expense.date.isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
            expense.date.isBefore(endOfMonth.add(const Duration(days: 1))))
        .fold(0.0, (sum, expense) => sum + expense.amount);
  }

  double get monthlyExpense => monthlyExpenses;

  Map<String, double> get expensesByCategory {
    final Map<String, double> result = {};
    
    for (final expense in _getFilteredExpenses()) {
      final categoryName = expense.category?.name ?? '未分类';
      result[categoryName] = (result[categoryName] ?? 0) + expense.amount;
    }
    
    return result;
  }
  
  Map<String, double> getExpensesByCategory() {
    return expensesByCategory;
  }
  
  double getDogExpenses(String dogId) {
    return getTotalExpensesForDog(dogId);
  }
  
  Map<String, double> getMonthlyExpensesData() {
    final Map<String, double> monthlyData = {};
    final now = DateTime.now();
    
    for (int month = 1; month <= 12; month++) {
      final monthKey = '${now.year}-${month.toString().padLeft(2, '0')}';
      final startOfMonth = DateTime(now.year, month, 1);
      final endOfMonth = DateTime(now.year, month + 1, 0);
      
      final monthlyExpenses = _expenses.where((expense) {
        return expense.date.isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
               expense.date.isBefore(endOfMonth.add(const Duration(days: 1)));
      });
      
      monthlyData[monthKey] = monthlyExpenses.fold(0.0, (sum, expense) => sum + expense.amount);
    }
    
    return monthlyData;
  }
  
  List<Expense> getExpensesForMonth(DateTime month) {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);
    
    return _expenses.where((expense) {
      return expense.date.isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
             expense.date.isBefore(endOfMonth.add(const Duration(days: 1)));
    }).toList();
  }
  
  List<Expense> get recentExpenses {
    final recent = _expenses.toList();
    recent.sort((a, b) => b.date.compareTo(a.date));
    return recent.take(10).toList();
  }

  Future<void> loadExpenses({bool forceRefresh = false}) async {
    if (_isLoading) return; // 防止重复加载
    
    _setLoadingWithoutNotify(true);
    _clearErrorWithoutNotify();
    
    try {
      // Try to load from cache first if not forcing refresh
      if (!forceRefresh) {
        final cachedExpenses = await LocalStorageService.getCachedExpenses();
        if (cachedExpenses.isNotEmpty) {
          _expenses = cachedExpenses;
        }
      }
      
      // Load from server
      final expenses = await _expenseService.getAllExpenses();
      _expenses = expenses;
      
      // Cache the data
      await LocalStorageService.cacheExpenses(expenses);
      
    } catch (e) {
      _errorMessage = '加载费用记录失败: $e';
      print('加载费用失败: $e');
    } finally {
      _isLoading = false;
      notifyListeners(); // 只在最后调用一次
    }
  }

  Future<void> loadCategories({bool forceRefresh = false}) async {
    if (_isLoading) return; // 防止重复加载
    
    _setLoadingWithoutNotify(true);
    _clearErrorWithoutNotify();
    
    try {
      // Try to load from cache first if not forcing refresh
      if (!forceRefresh) {
        final cachedCategories = await LocalStorageService.getCachedCategories();
        if (cachedCategories.isNotEmpty) {
          _categories = cachedCategories;
        }
      }
      
      // Load from server
      try {
        final categories = await _expenseService.getCategories();
        
        // If no categories exist, initialize default categories
        if (categories.isEmpty) {
          if (!_isInDemoMode()) {
            // Only initialize on server if not in demo mode
            await _expenseService.initializeDefaultCategories();
            final defaultCategories = await _expenseService.getCategories();
            _categories = defaultCategories;
          } else {
            // In demo mode, create default categories locally
            _categories = _getDefaultCategories();
          }
        } else {
          _categories = categories;
        }
        
        // Cache the data
        await LocalStorageService.cacheCategories(_categories);
      } catch (e) {
        print('服务器加载类别失败: $e');
        // Fallback to cached or default categories
        final cachedCategories = await LocalStorageService.getCachedCategories();
        if (cachedCategories.isNotEmpty) {
          _categories = cachedCategories;
        } else {
          // Use default categories as last resort
          _categories = _getDefaultCategories();
          await LocalStorageService.cacheCategories(_categories);
        }
      }
      
    } catch (e) {
      _errorMessage = '加载费用类别失败: $e';
      print('加载类别失败: $e');
      // Last resort: use default categories
      _categories = _getDefaultCategories();
      await LocalStorageService.cacheCategories(_categories);
    } finally {
      _isLoading = false;
      notifyListeners(); // 只在最后调用一次
    }
  }

  // Get default categories for demo mode or fallback
  List<ExpenseCategory> _getDefaultCategories() {
    return [
      ExpenseCategory(
        catId: 'default-cat-001',
        name: '食物费用',
        isShared: true,
      ),
      ExpenseCategory(
        catId: 'default-cat-002',
        name: '医疗费用',
        isShared: true,
      ),
      ExpenseCategory(
        catId: 'default-cat-003',
        name: '美容费用',
        isShared: true,
      ),
      ExpenseCategory(
        catId: 'default-cat-004',
        name: '用品费用',
        isShared: true,
      ),
      ExpenseCategory(
        catId: 'default-cat-005',
        name: '训练费用',
        isShared: true,
      ),
      ExpenseCategory(
        catId: 'default-cat-006',
        name: '其他费用',
        isShared: true,
      ),
    ];
  }
  
  // 新增方法：同时加载费用和类别，避免竞争条件
  Future<void> loadData({bool forceRefresh = false}) async {
    if (_isLoading) return; // 防止重复加载
    
    _setLoadingWithoutNotify(true);
    _clearErrorWithoutNotify();
    
    List<Expense> newExpenses = [];
    List<ExpenseCategory> newCategories = [];
    String? errorMsg;
    
    try {
      if (_isInDemoMode()) {
        // 演示模式：只使用本地缓存
        newExpenses = await LocalStorageService.getCachedExpenses();
        newCategories = await LocalStorageService.getCachedCategories();
      } else {
        // 联网模式：优先从服务器加载
        try {
          // 并行执行所有数据加载操作
          await Future.wait([
            // 加载费用
            () async {
              try {
                final expenses = await _expenseService.getAllExpenses();
                newExpenses = expenses;
                await LocalStorageService.cacheExpenses(expenses);
              } catch (e) {
                print('从服务器加载费用失败: $e');
                // 如果服务器加载失败，使用缓存数据
                final cachedExpenses = await LocalStorageService.getCachedExpenses();
                newExpenses = cachedExpenses;
                errorMsg ??= '无法连接服务器，使用本地数据';
              }
            }(),
            
            // 加载类别
            () async {
              try {
                final categories = await _expenseService.getCategories();
                newCategories = categories;
                await LocalStorageService.cacheCategories(categories);
              } catch (e) {
                print('从服务器加载类别失败: $e');
                // 如果服务器加载失败，使用缓存数据
                final cachedCategories = await LocalStorageService.getCachedCategories();
                newCategories = cachedCategories;
                errorMsg ??= '无法连接服务器，使用本地数据';
              }
            }(),
          ]);
        } catch (e) {
          print('服务器连接失败，使用本地缓存: $e');
          newExpenses = await LocalStorageService.getCachedExpenses();
          newCategories = await LocalStorageService.getCachedCategories();
          errorMsg = '网络连接失败，显示本地数据';
        }
      }
      
      // 一次性更新所有数据
      _expenses = newExpenses;
      _categories = newCategories;
      
      if (errorMsg != null) {
        print('警告: $errorMsg');
        // 不设置为错误，因为有本地数据可以使用
      }
      
    } catch (e) {
      print('加载数据失败: $e');
      _errorMessage = '加载数据失败: $e';
    } finally {
      _isLoading = false;
      notifyListeners(); // 只在最后调用一次通知
    }
  }

  // 检查是否在演示模式（离线模式）
  bool _isInDemoMode() {
    try {
      // 首先检查Supabase配置
      if (!SupabaseConfig.isConfigured) {
        return true; // 未配置Supabase，强制离线模式
      }
      
      // 检查当前用户是否是演示用户
      final currentUserId = AuthService.instance.currentUserId;
      return currentUserId == '00000000-0000-0000-0000-000000000001' ||
             currentUserId == '00000000-0000-0000-0000-000000000002';
    } catch (e) {
      return true; // 默认离线模式
    }
  }

  // 不触发通知的内部方法
  void _setLoadingWithoutNotify(bool loading) {
    _isLoading = loading;
  }

  void _clearErrorWithoutNotify() {
    _errorMessage = null;
  }

  Future<bool> addExpense(Map<String, Object> expenseData) async {
    if (_isLoading) return false;
    
    _setLoadingWithoutNotify(true);
    _clearErrorWithoutNotify();
    
    try {
      final userId = AuthService.instance.currentUserId;
      expenseData['created_by'] = userId;
      final expense = Expense.fromMap(expenseData);
      
      if (_isInDemoMode()) {
        // 演示模式：只保存到本地
        _expenses.add(expense);
        await LocalStorageService.cacheExpenses(_expenses);
        return true;
      } else {
        // 联网模式：先尝试保存到服务器
        try {
          final newExpense = await _expenseService.createExpense(expense);
          if (newExpense != null) {
            _expenses.add(newExpense);
            await LocalStorageService.cacheExpenses(_expenses);
            return true;
          }
          return false;
        } catch (e) {
          print('服务器添加失败，保存到本地: $e');
          // 服务器保存失败，保存到本地作为备用
          _expenses.add(expense);
          await LocalStorageService.cacheExpenses(_expenses);
          return true;
        }
      }
    } catch (e) {
      _errorMessage = '添加费用记录失败: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateExpense(Expense expense) async {
    if (_isLoading) return false;
    
    _setLoadingWithoutNotify(true);
    _clearErrorWithoutNotify();
    
    try {
      final updatedExpense = await _expenseService.updateExpense(expense);
      if (updatedExpense != null) {
        final index = _expenses.indexWhere((e) => e.expId == expense.expId);
        if (index != -1) {
          _expenses[index] = updatedExpense;
          await LocalStorageService.cacheExpenses(_expenses);
          return true;
        }
      }
      return false;
    } catch (e) {
      _errorMessage = '更新费用记录失败: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteExpense(String expenseId) async {
    if (_isLoading) return false;
    
    _setLoadingWithoutNotify(true);
    _clearErrorWithoutNotify();
    
    try {
      bool success = false;
      String? errorMessage;
      
      print('开始删除费用，ID: $expenseId');
      print('当前演示模式状态: ${_isInDemoMode()}');
      
      if (_isInDemoMode()) {
        // 演示模式：只删除本地数据
        print('执行演示模式删除...');
        final initialCount = _expenses.length;
        print('删除前本地费用数量: $initialCount');
        
        _expenses.removeWhere((expense) => expense.expId == expenseId);
        success = _expenses.length < initialCount; // 确认真的删除了
        
        print('删除后本地费用数量: ${_expenses.length}');
        print('删除成功: $success');
        
        if (success) {
          await LocalStorageService.cacheExpenses(_expenses);
          print('演示模式：本地删除成功，已更新缓存');
        } else {
          errorMessage = '未找到要删除的记录ID: $expenseId';
          print('错误：$errorMessage');
        }
      } else {
        // 联网模式：必须先成功删除服务器数据
        print('执行联网模式删除...');
        try {
          print('调用服务器删除API...');
          success = await _expenseService.deleteExpense(expenseId);
          print('服务器删除结果: $success');
          
          if (success) {
            // 服务器删除成功，删除本地数据
            final initialCount = _expenses.length;
            print('删除前本地费用数量: $initialCount');
            
            _expenses.removeWhere((expense) => expense.expId == expenseId);
            await LocalStorageService.cacheExpenses(_expenses);
            
            print('删除后本地费用数量: ${_expenses.length}');
            print('联网模式：服务器和本地删除都成功');
          } else {
            errorMessage = '服务器删除返回失败';
            print('错误：$errorMessage');
            success = false;
          }
        } catch (e) {
          print('服务器删除异常: $e');
          errorMessage = '网络错误：$e';
          success = false;
          // 不删除本地数据，因为服务器删除失败
        }
      }
      
      if (!success && errorMessage != null) {
        _errorMessage = errorMessage;
        print('最终删除失败，错误信息: $errorMessage');
      } else {
        print('最终删除结果: $success');
      }
      
      return success;
    } catch (e) {
      final message = '删除费用记录失败: $e';
      _errorMessage = message;
      print('删除过程异常: $message');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addCategory(String name, bool isShared) async {
    if (_isLoading) return false;
    
    _setLoadingWithoutNotify(true);
    _clearErrorWithoutNotify();
    
    try {
      final newCategory = await _expenseService.createCategory(name, isShared);
      if (newCategory != null) {
        _categories.add(newCategory);
        await LocalStorageService.cacheCategories(_categories);
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = '添加费用类别失败: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<Expense> getExpensesForDog(String dogId) {
    return _expenses.where((expense) {
      return expense.dogLinks.any((link) => link.dogId == dogId);
    }).toList();
  }

  double getTotalExpensesForDog(String dogId) {
    return getExpensesForDog(dogId).fold(0.0, (sum, expense) {
      return sum + expense.getAmountForDog(dogId);
    });
  }

  Map<String, double> getMonthlyExpensesForDog(String dogId, int year) {
    final Map<String, double> monthlyData = {};
    
    for (int month = 1; month <= 12; month++) {
      final monthKey = '$year-${month.toString().padLeft(2, '0')}';
      final startOfMonth = DateTime(year, month, 1);
      final endOfMonth = DateTime(year, month + 1, 0);
      
      final monthlyExpenses = _expenses.where((expense) {
        return expense.date.isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
               expense.date.isBefore(endOfMonth.add(const Duration(days: 1))) &&
               expense.dogLinks.any((link) => link.dogId == dogId);
      });
      
      double total = 0.0;
      for (final expense in monthlyExpenses) {
        total += expense.getAmountForDog(dogId);
      }
      
      monthlyData[monthKey] = total;
    }
    
    return monthlyData;
  }

  void setDateFilter(DateTime? start, DateTime? end) {
    _startDate = start;
    _endDate = end;
    notifyListeners();
  }

  void setCategoryFilter(String? categoryId) {
    _categoryFilter = categoryId;
    notifyListeners();
  }

  void clearFilters() {
    _startDate = null;
    _endDate = null;
    _categoryFilter = null;
    _searchQuery = '';
    notifyListeners();
  }

  List<Expense> _getFilteredExpenses() {
    var filtered = _expenses;
    
    // Apply date filter
    if (_startDate != null) {
      filtered = filtered.where((expense) => 
          expense.date.isAfter(_startDate!.subtract(const Duration(days: 1)))).toList();
    }
    
    if (_endDate != null) {
      filtered = filtered.where((expense) => 
          expense.date.isBefore(_endDate!.add(const Duration(days: 1)))).toList();
    }
    
    // Apply category filter
    if (_categoryFilter != null) {
      filtered = filtered.where((expense) => expense.catId == _categoryFilter).toList();
    }
    
    // Apply search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((expense) {
        return expense.note?.toLowerCase().contains(query) == true ||
               expense.category?.name.toLowerCase().contains(query) == true;
      }).toList();
    }
    
    // Sort by date (newest first)
    filtered.sort((a, b) => b.date.compareTo(a.date));
    
    return filtered;
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    // 不自动调用notifyListeners，让调用者控制
  }

  void _setError(String error) {
    _errorMessage = error;
    // 不自动调用notifyListeners，让调用者控制
  }

  void _clearError() {
    _errorMessage = null;
    // 不自动调用notifyListeners，让调用者控制
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  double getTotalExpenses() {
    return totalExpenses;
  }
  
  double getMonthlyExpenses() {
    return monthlyExpenses;
  }
}