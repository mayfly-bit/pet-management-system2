import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/expense.dart';
import '../config/supabase_config.dart';

class ExpenseService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Expense>> getAllExpenses() async {
    try {
      // 先简单查询费用记录，不使用JOIN
      final response = await _client
          .from(SupabaseConfig.expensesTable)
          .select('*')
          .order('date', ascending: false);
      
      return (response as List).map((expenseData) {
        final expense = Expense.fromJson(expenseData);
        return expense;
      }).toList();
    } catch (e) {
      throw Exception('获取费用记录失败: $e');
    }
  }

  Future<Expense?> getExpenseById(String expenseId) async {
    try {
      final response = await _client
          .from(SupabaseConfig.expensesTable)
          .select('*')
          .eq('exp_id', expenseId)
          .single();
      
      final expense = Expense.fromJson(response);
      return expense;
    } catch (e) {
      throw Exception('获取费用记录失败: $e');
    }
  }

  Future<Expense?> createExpense(Expense expense) async {
    try {
      // Use Edge Function for complex expense creation with dog links
      final response = await _client.functions.invoke(
        SupabaseConfig.addExpenseFunction,
        body: {
          'expense': expense.toJson(),
          'dog_links': expense.dogLinks.map((link) => link.toJson()).toList(),
        },
      );
      
      if (response.data != null && response.data['success'] == true) {
        return await getExpenseById(expense.expId);
      }
      
      throw Exception('创建费用记录失败');
    } catch (e) {
      // Fallback to manual creation if Edge Function is not available
      return await _createExpenseManually(expense);
    }
  }

  Future<Expense?> _createExpenseManually(Expense expense) async {
    try {
      // 确保当前用户已登录
      final currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('用户未登录，无法创建费用记录');
      }
      
      // 确保expense对象有正确的created_by字段
      final expenseData = expense.toJson();
      expenseData['created_by'] = currentUser.id;
      
      // 1. Insert expense with explicit created_by
      await _client
          .from(SupabaseConfig.expensesTable)
          .insert(expenseData);
      
      // 2. Insert dog links with verification
      if (expense.dogLinks.isNotEmpty) {
        final linkData = expense.dogLinks.map((link) {
          final linkJson = link.toJson();
          // 确保使用正确的字段名
          linkJson['exp_id'] = expense.expId;
          return linkJson;
        }).toList();
        
        await _client
            .from(SupabaseConfig.expenseDogLinkTable)
            .insert(linkData);
      }
      
      // 3. Return the created expense
      return await getExpenseById(expense.expId);
    } catch (e) {
      throw Exception('创建费用记录失败: $e');
    }
  }

  Future<Expense?> updateExpense(Expense expense) async {
    try {
      // Update expense record
      await _client
          .from(SupabaseConfig.expensesTable)
          .update(expense.toJson())
          .eq('exp_id', expense.expId);
      
      // Delete existing dog links
      await _client
          .from(SupabaseConfig.expenseDogLinkTable)
          .delete()
          .eq('exp_id', expense.expId);
      
      // Insert new dog links
      if (expense.dogLinks.isNotEmpty) {
        await _client
            .from(SupabaseConfig.expenseDogLinkTable)
            .insert(expense.dogLinks.map((link) => link.toJson()).toList());
      }
      
      return await getExpenseById(expense.expId);
    } catch (e) {
      throw Exception('更新费用记录失败: $e');
    }
  }

  Future<bool> deleteExpense(String expenseId) async {
    try {
      // Delete dog links first (foreign key constraint)
      await _client
          .from(SupabaseConfig.expenseDogLinkTable)
          .delete()
          .eq('exp_id', expenseId);
      
      // Delete expense
      await _client
          .from(SupabaseConfig.expensesTable)
          .delete()
          .eq('exp_id', expenseId);
      
      return true;
    } catch (e) {
      throw Exception('删除费用记录失败: $e');
    }
  }

  Future<List<ExpenseCategory>> getCategories() async {
    try {
      final response = await _client
          .from(SupabaseConfig.expenseCategoriesTable)
          .select('*')
          .order('name');
      
      return (response as List)
          .map((category) => ExpenseCategory.fromJson(category))
          .toList();
    } catch (e) {
      throw Exception('获取费用类别失败: $e');
    }
  }

  Future<ExpenseCategory?> createCategory(String name, bool isShared) async {
    try {
      final response = await _client
          .from(SupabaseConfig.expenseCategoriesTable)
          .insert({
            'name': name,
            'is_shared': isShared,
            'created_by': _client.auth.currentUser?.id ?? '00000000-0000-0000-0000-000000000000',
          })
          .select()
          .single();
      
      return ExpenseCategory.fromJson(response);
    } catch (e) {
      throw Exception('创建费用类别失败: $e');
    }
  }

  Future<bool> deleteCategory(String categoryId) async {
    try {
      await _client
          .from(SupabaseConfig.expenseCategoriesTable)
          .delete()
          .eq('cat_id', categoryId);
      
      return true;
    } catch (e) {
      throw Exception('删除费用类别失败: $e');
    }
  }

  Future<List<Expense>> getExpensesForDog(String dogId) async {
    try {
      // 简化查询，先获取所有费用记录
      final response = await _client
          .from(SupabaseConfig.expensesTable)
          .select('*')
          .order('date', ascending: false);
      
      return (response as List).map((expenseData) {
        final expense = Expense.fromJson(expenseData);
        return expense;
      }).toList();
    } catch (e) {
      throw Exception('获取狗狗费用记录失败: $e');
    }
  }

  Future<Map<String, dynamic>> getMonthlyExpenseSummary(int year, int month) async {
    try {
      final response = await _client.functions.invoke(
        SupabaseConfig.getMonthlyReportFunction,
        body: {
          'year': year,
          'month': month,
        },
      );
      
      return response.data ?? {};
    } catch (e) {
      throw Exception('获取月度费用汇总失败: $e');
    }
  }

  Future<Map<String, dynamic>> getProfitReport() async {
    try {
      final response = await _client.functions.invoke(
        SupabaseConfig.getProfitReportFunction,
      );
      
      return response.data ?? {};
    } catch (e) {
      throw Exception('获取利润报表失败: $e');
    }
  }

  Future<List<Expense>> searchExpenses({
    DateTime? startDate,
    DateTime? endDate,
    String? categoryId,
    String? dogId,
  }) async {
    try {
      var queryBuilder = _client
          .from(SupabaseConfig.expensesTable)
          .select('*');
      
      if (startDate != null) {
        queryBuilder = queryBuilder.gte('date', startDate.toIso8601String());
      }
      
      if (endDate != null) {
        queryBuilder = queryBuilder.lte('date', endDate.toIso8601String());
      }
      
      // 类别过滤
      if (categoryId != null) {
        queryBuilder = queryBuilder.eq('cat_id', categoryId);
      }
      
      final response = await queryBuilder.order('date', ascending: false);
      
      return (response as List).map((expenseData) {
        final expense = Expense.fromJson(expenseData);
        return expense;
      }).toList();
    } catch (e) {
      throw Exception('搜索费用记录失败: $e');
    }
  }

  Future<void> initializeDefaultCategories() async {
    try {
      // Check if categories already exist
      final existingCategories = await getCategories();
      if (existingCategories.isNotEmpty) {
        return; // Categories already initialized
      }
      
      // Use current user or system user
      final userId = _client.auth.currentUser?.id ?? '00000000-0000-0000-0000-000000000000';
      
      // Insert default categories with explicit IDs
      final defaultCategories = [
        {'cat_id': 'default-cat-001', 'name': '食物费用', 'is_shared': true, 'created_by': userId},
        {'cat_id': 'default-cat-002', 'name': '医疗费用', 'is_shared': true, 'created_by': userId},
        {'cat_id': 'default-cat-003', 'name': '美容费用', 'is_shared': true, 'created_by': userId},
        {'cat_id': 'default-cat-004', 'name': '用品费用', 'is_shared': true, 'created_by': userId},
        {'cat_id': 'default-cat-005', 'name': '训练费用', 'is_shared': true, 'created_by': userId},
        {'cat_id': 'default-cat-006', 'name': '其他费用', 'is_shared': true, 'created_by': userId},
      ];
      
      await _client
          .from(SupabaseConfig.expenseCategoriesTable)
          .upsert(defaultCategories);
    } catch (e) {
      throw Exception('初始化默认费用类别失败: $e');
    }
  }
}