import 'package:flutter/foundation.dart';
import '../models/expense.dart';
import '../services/expense_service.dart';
import '../services/local_storage_service.dart';
import '../services/auth_service.dart';

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
      final categories = await _expenseService.getCategories();
      _categories = categories;
      
      // Cache the data
      await LocalStorageService.cacheCategories(categories);
      
    } catch (e) {
      _errorMessage = '加载费用类别失败: $e';
      print('加载类别失败: $e');
    } finally {
      _isLoading = false;
      notifyListeners(); // 只在最后调用一次
    }
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
      // 并行执行所有数据加载操作
      await Future.wait([
        // 加载费用
        () async {
          try {
            if (!forceRefresh) {
              final cachedExpenses = await LocalStorageService.getCachedExpenses();
              if (cachedExpenses.isNotEmpty) {
                newExpenses = cachedExpenses;
              }
            }
            
            final expenses = await _expenseService.getAllExpenses();
            newExpenses = expenses;
            await LocalStorageService.cacheExpenses(expenses);
          } catch (e) {
            print('加载费用失败: $e');
            errorMsg ??= '加载费用失败: $e';
          }
        }(),
        
        // 加载类别
        () async {
          try {
            if (!forceRefresh) {
              final cachedCategories = await LocalStorageService.getCachedCategories();
              if (cachedCategories.isNotEmpty) {
                newCategories = cachedCategories;
              }
            }
            
            final categories = await _expenseService.getCategories();
            newCategories = categories;
            await LocalStorageService.cacheCategories(categories);
          } catch (e) {
            print('加载类别失败: $e');
            errorMsg ??= '加载类别失败: $e';
          }
        }(),
      ]);
      
      // 一次性更新所有数据
      _expenses = newExpenses;
      _categories = newCategories;
      
      if (errorMsg != null) {
        _errorMessage = errorMsg;
      }
      
    } catch (e) {
      _errorMessage = '加载数据失败: $e';
    } finally {
      _isLoading = false;
      notifyListeners(); // 只在最后调用一次通知
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
      final newExpense = await _expenseService.createExpense(expense);
      if (newExpense != null) {
        _expenses.add(newExpense);
        await LocalStorageService.cacheExpenses(_expenses);
        return true;
      }
      return false;
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
      final success = await _expenseService.deleteExpense(expenseId);
      if (success) {
        _expenses.removeWhere((expense) => expense.expId == expenseId);
        await LocalStorageService.cacheExpenses(_expenses);
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = '删除费用记录失败: $e';
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