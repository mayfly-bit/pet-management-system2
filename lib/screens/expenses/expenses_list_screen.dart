import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/expense_provider.dart';
import '../../providers/dog_provider.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/error_widget.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../models/expense.dart';
import '../../models/dog.dart';

class ExpensesListScreen extends StatefulWidget {
  const ExpensesListScreen({super.key});

  @override
  State<ExpensesListScreen> createState() => _ExpensesListScreenState();
}

class _ExpensesListScreenState extends State<ExpensesListScreen> {
  final _searchController = TextEditingController();
  bool _isRefreshing = false;
  ExpenseCategory? _selectedCategory;
  DateTime? _startDate;
  DateTime? _endDate;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // 延迟加载数据，避免在构建过程中触发状态更新
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExpenses();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadExpenses() async {
    if (!mounted) return;
    
    setState(() {
      _isRefreshing = true;
    });

    try {
      await context.read<ExpenseProvider>().loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载花费列表失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    context.read<ExpenseProvider>().setSearchQuery(query);
  }

  void _onCategoryFilterChanged(ExpenseCategory? category) {
    setState(() {
      _selectedCategory = category;
    });
    context.read<ExpenseProvider>().setCategoryFilter(category?.categoryId);
  }

  void _onDateRangeChanged(DateTime? start, DateTime? end) {
    setState(() {
      _startDate = start;
      _endDate = end;
    });
    context.read<ExpenseProvider>().setDateFilter(start, end);
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _selectedCategory = null;
      _startDate = null;
      _endDate = null;
    });
    _searchController.clear();
    context.read<ExpenseProvider>().clearFilters();
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    
    if (picked != null) {
      _onDateRangeChanged(picked.start, picked.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('花费管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _loadExpenses,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.go('/expenses/add'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and filter section
          _buildSearchAndFilter(),
          
          // Summary section
          _buildSummarySection(),
          
          // Expenses list
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadExpenses,
              child: LoadingOverlay(
                isLoading: _isRefreshing,
                child: Consumer<ExpenseProvider>(
                  builder: (context, expenseProvider, child) {
                    if (expenseProvider.isLoading && expenseProvider.expenses.isEmpty) {
                      return const Center(
                        child: LoadingWidget(message: '加载花费列表中...'),
                      );
                    }

                    if (expenseProvider.error != null) {
                      return Center(
                        child: CustomErrorWidget(
                          message: expenseProvider.error!,
                          onRetry: _loadExpenses,
                        ),
                      );
                    }

                    final filteredExpenses = expenseProvider.filteredExpenses;

                    if (filteredExpenses.isEmpty) {
                      return Center(
                        child: EmptyStateWidget(
                          title: _hasActiveFilters()
                              ? '没有找到匹配的花费记录'
                              : '还没有花费记录',
                          message: _hasActiveFilters()
                              ? '尝试调整搜索条件或筛选器'
                              : '点击右上角的 + 按钮添加第一条花费记录',
                          icon: _hasActiveFilters()
                              ? Icons.search_off
                              : Icons.receipt_long,
                          onAction: _hasActiveFilters()
                              ? _clearFilters
                              : () => context.go('/expenses/add'),
                          actionText: _hasActiveFilters()
                              ? '清除筛选'
                              : '添加花费',
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredExpenses.length,
                      itemBuilder: (context, index) {
                        final expense = filteredExpenses[index];
                        return _buildExpenseCard(expense);
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/expenses/add'),
        child: const Icon(Icons.add),
      ),
    );
  }

  bool _hasActiveFilters() {
    return _searchQuery.isNotEmpty ||
           _selectedCategory != null ||
           _startDate != null ||
           _endDate != null;
  }

  Widget _buildSearchAndFilter() {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Column(
        children: [
          // Search field
          CustomTextField(
            controller: _searchController,
            hintText: '搜索花费备注...',
            prefixIcon: Icons.search,
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  )
                : null,
            onChanged: _onSearchChanged,
          ),
          
          const SizedBox(height: 12),
          
          // Filter buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showCategoryFilter(),
                  icon: const Icon(Icons.category, size: 16),
                  label: Text(
                    _selectedCategory?.name ?? '所有类别',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _selectDateRange,
                  icon: const Icon(Icons.date_range, size: 16),
                  label: Text(
                    _startDate != null && _endDate != null
                        ? '${_startDate!.month}/${_startDate!.day} - ${_endDate!.month}/${_endDate!.day}'
                        : '选择日期',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (_hasActiveFilters()) ...
                [
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.clear),
                    tooltip: '清除筛选',
                  ),
                ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    return Consumer<ExpenseProvider>(
      builder: (context, expenseProvider, child) {
        final totalExpenses = expenseProvider.getTotalExpenses();
        final monthlyExpenses = expenseProvider.getMonthlyExpenses();
        
        return Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  '总花费',
                  '¥${totalExpenses.toStringAsFixed(2)}',
                  Icons.receipt_long,
                  Colors.red,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  '本月花费',
                  '¥${monthlyExpenses.toStringAsFixed(2)}',
                  Icons.calendar_month,
                  Colors.orange,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseCard(Expense expense) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Category icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.receipt,
                    color: theme.colorScheme.onPrimaryContainer,
                    size: 20,
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Category and amount
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.category?.name ?? '未分类',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        expense.date.toString().split(' ')[0],
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Amount
                Text(
                  '¥${expense.amount.toStringAsFixed(2)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                
                // Delete button
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') {
                      _showDeleteConfirmDialog(expense);
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('删除'),
                        ],
                      ),
                    ),
                  ],
                  child: Icon(
                    Icons.more_vert,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
            
            if (expense.note?.isNotEmpty == true) ...
              [
                const SizedBox(height: 8),
                                  Text(
                    expense.note ?? '',
                    style: theme.textTheme.bodyMedium,
                  ),
              ],
            
            // Associated dogs
            if (expense.dogLinks.isNotEmpty) ...
              [
                const SizedBox(height: 12),
                Consumer<DogProvider>(
                  builder: (context, dogProvider, child) {
                    return Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: expense.dogLinks.map((link) {
                        final dogList = dogProvider.allDogs;
                        final dog = dogList.firstWhere(
                          (d) => d.dogId == link.dogId,
                          orElse: () => Dog(
                            dogId: link.dogId,
                            name: link.dogId,
                            createdBy: '',
                            createdAt: DateTime.now(),
                          ),
                        );
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.pets,
                                size: 12,
                                color: theme.colorScheme.onSecondaryContainer,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                dog.name,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSecondaryContainer,
                                ),
                              ),
                              if (link.shareRatio != 1.0) ...
                                [
                                  const SizedBox(width: 4),
                                  Text(
                                    '(${(link.shareRatio * 100).toInt()}%)',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSecondaryContainer,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
          ],
        ),
      ),
    );
  }

  void _showCategoryFilter() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Consumer<ExpenseProvider>(
          builder: (context, expenseProvider, child) {
            final categories = expenseProvider.categories;
            
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '选择类别',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  
                  // All categories option
                  ListTile(
                    leading: const Icon(Icons.all_inclusive),
                    title: const Text('所有类别'),
                    selected: _selectedCategory == null,
                    onTap: () {
                      _onCategoryFilterChanged(null);
                      Navigator.of(context).pop();
                    },
                  ),
                  
                  const Divider(),
                  
                  // Category options
                  ...categories.map((category) {
                    return ListTile(
                      leading: const Icon(Icons.category),
                      title: Text(category.name),
                      selected: _selectedCategory?.categoryId == category.categoryId,
                      onTap: () {
                        _onCategoryFilterChanged(category);
                        Navigator.of(context).pop();
                      },
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmDialog(Expense expense) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('您确定要删除这条费用记录吗？'),
              const SizedBox(height: 8),
              Text(
                '类别: ${expense.category?.name ?? '未分类'}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                '金额: ¥${expense.amount.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                '日期: ${expense.date.toString().split(' ')[0]}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (expense.note?.isNotEmpty == true)
                Text(
                  '备注: ${expense.note}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteExpense(expense);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteExpense(Expense expense) async {
    try {
      final success = await context.read<ExpenseProvider>().deleteExpense(expense.expId);
      
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('费用记录已删除'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('删除失败，请重试'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('删除失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}