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
      print('开始删除费用服务，expenseId: $expenseId');
      
      // 首先检查expenseId是否有效
      if (expenseId.startsWith('unknown-') || expenseId.startsWith('error-')) {
        print('检测到无效的expenseId: $expenseId，跳过删除操作');
        return false;
      }
      
      // Delete dog links first (foreign key constraint)
      // 根据错误提示，expense_dog_link表中可能使用不同的字段名
      print('尝试删除关联的狗狗记录...');
      
      // 先查询表结构，看看有哪些字段
      try {
        // 尝试查询这个expense的关联记录，了解实际的字段结构
        final linkRecords = await _client
            .from(SupabaseConfig.expenseDogLinkTable)
            .select()
            .limit(1);
        print('expense_dog_link表结构示例: $linkRecords');
      } catch (e) {
        print('无法查询表结构: $e');
      }
      
      // 尝试不同的字段名来删除关联记录
      bool linksDeleted = false;
      
      // 方法1：尝试使用 expense_id 字段
      try {
        await _client
            .from(SupabaseConfig.expenseDogLinkTable)
            .delete()
            .eq('expense_id', expenseId);
        print('使用expense_id字段删除关联记录成功');
        linksDeleted = true;
      } catch (e1) {
        print('使用expense_id字段失败: $e1');
        
        // 方法2：尝试使用 exp_id 字段
        try {
          await _client
              .from(SupabaseConfig.expenseDogLinkTable)
              .delete()
              .eq('exp_id', expenseId);
          print('使用exp_id字段删除关联记录成功');
          linksDeleted = true;
        } catch (e2) {
          print('使用exp_id字段也失败: $e2');
          
          // 方法3：可能没有关联记录，或者字段名不同
          print('警告：无法删除关联记录，可能没有关联数据或字段名不匹配');
          linksDeleted = true; // 继续删除主记录
        }
      }
      
      if (!linksDeleted) {
        print('删除关联记录失败，但继续尝试删除主记录');
      }
      
      // Delete expense (尝试不同的主键字段名)
      print('尝试删除主费用记录...');
      try {
        await _client
            .from(SupabaseConfig.expensesTable)
            .delete()
            .eq('exp_id', expenseId);
        print('使用exp_id字段删除主费用记录成功');
      } catch (e3) {
        print('使用exp_id字段删除主记录失败: $e3');
        // 尝试使用expense_id字段
        try {
          await _client
              .from(SupabaseConfig.expensesTable)
              .delete()
              .eq('expense_id', expenseId);
          print('使用expense_id字段删除主费用记录成功');
        } catch (e4) {
          print('使用expense_id字段删除主记录也失败: $e4');
          throw Exception('无法删除主费用记录: $e4');
        }
      }
      
      print('费用记录删除完成');
      return true;
    } catch (e) {
      print('删除费用记录最终失败: $e');
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