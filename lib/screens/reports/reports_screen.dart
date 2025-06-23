import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/dog_provider.dart';
import '../../providers/expense_provider.dart';
import '../../widgets/common/loading_widget.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await context.read<DogProvider>().loadDogs();
      await context.read<ExpenseProvider>().loadExpenses();
      await context.read<ExpenseProvider>().loadCategories();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载数据失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectMonth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
    );
    
    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('数据报表'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '概览'),
            Tab(text: '花费分析'),
            Tab(text: '利润分析'),
          ],
        ),
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(),
            _buildExpenseAnalysisTab(),
            _buildProfitAnalysisTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary cards
          _buildSummaryCards(),
          
          const SizedBox(height: 24),
          
          // Monthly trend chart
          _buildMonthlyTrendChart(),
          
          const SizedBox(height: 24),
          
          // Recent activities
          _buildRecentActivities(),
        ],
      ),
    );
  }

  Widget _buildExpenseAnalysisTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month selector
          _buildMonthSelector(),
          
          const SizedBox(height: 24),
          
          // Expense by category pie chart
          _buildExpenseByCategoryChart(),
          
          const SizedBox(height: 24),
          
          // Expense by dog chart
          _buildExpenseByDogChart(),
          
          const SizedBox(height: 24),
          
          // Category breakdown
          _buildCategoryBreakdown(),
        ],
      ),
    );
  }

  Widget _buildProfitAnalysisTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profit summary
          _buildProfitSummary(),
          
          const SizedBox(height: 24),
          
          // Profit by dog chart
          _buildProfitByDogChart(),
          
          const SizedBox(height: 24),
          
          // Dog profit details
          _buildDogProfitDetails(),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Consumer2<DogProvider, ExpenseProvider>(
      builder: (context, dogProvider, expenseProvider, child) {
        final totalDogs = dogProvider.totalDogs;
        final availableDogs = dogProvider.availableDogs;
        final soldDogs = dogProvider.soldDogs;
        final totalProfit = dogProvider.totalProfit;
        final totalInvestment = dogProvider.totalInvestment;
        final totalRevenue = dogProvider.totalRevenue;
        final currentMonthExpense = expenseProvider.getMonthlyExpenses();
        
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    '总狗狗数',
                    totalDogs.toString(),
                    Icons.pets,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryCard(
                    '在售',
                    availableDogs.toString(),
                    Icons.store,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    '已售',
                    soldDogs.toString(),
                    Icons.check_circle,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryCard(
                    '总利润',
                    '¥${totalProfit.toStringAsFixed(0)}',
                    Icons.trending_up,
                    totalProfit >= 0 ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    '总投资',
                    '¥${totalInvestment.toStringAsFixed(0)}',
                    Icons.account_balance_wallet,
                    Colors.purple,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryCard(
                    '本月花费',
                    '¥${currentMonthExpense.toStringAsFixed(0)}',
                    Icons.receipt_long,
                    Colors.red,
                  ),
                ),
              ],
            ),
          ],
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

  Widget _buildMonthlyTrendChart() {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '月度趋势',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: Consumer<ExpenseProvider>(
                builder: (context, expenseProvider, child) {
                  // Generate sample data for the last 6 months
                  final now = DateTime.now();
                  final months = List.generate(6, (index) {
                    return DateTime(now.year, now.month - index);
                  }).reversed.toList();
                  
                  final expenseData = months.asMap().entries.map((entry) {
                    final index = entry.key;
                    final month = entry.value;
                    final expenses = expenseProvider.getExpensesForMonth(month);
                    final totalAmount = expenses.fold(0.0, (sum, expense) => sum + expense.amount);
                    return FlSpot(index.toDouble(), totalAmount);
                  }).toList();
                  
                  return LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 1000,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: theme.colorScheme.outline.withOpacity(0.2),
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() < months.length) {
                                final month = months[value.toInt()];
                                return Text(
                                  '${month.month}月',
                                  style: theme.textTheme.bodySmall,
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '¥${(value / 1000).toStringAsFixed(0)}k',
                                style: theme.textTheme.bodySmall,
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: expenseData,
                          isCurved: true,
                          color: Colors.red,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 4,
                                color: Colors.red,
                                strokeWidth: 2,
                                strokeColor: Colors.white,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            color: Colors.red.withOpacity(0.1),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivities() {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '最近活动',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Consumer<ExpenseProvider>(
              builder: (context, expenseProvider, child) {
                final recentExpenses = expenseProvider.expenses
                    .take(5)
                    .toList();
                
                if (recentExpenses.isEmpty) {
                  return const Center(
                    child: Text('暂无最近活动'),
                  );
                }
                
                return Column(
                  children: recentExpenses.map((expense) {
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Icon(
                          Icons.receipt,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      title: Text(expense.category?.name ?? '未分类'),
                      subtitle: Text(expense.date.toString().split(' ')[0]),
                      trailing: Text(
                        '¥${expense.amount.toStringAsFixed(2)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                        ),
                      ),
                      contentPadding: EdgeInsets.zero,
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSelector() {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.calendar_month,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Text(
              '分析月份',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: _selectMonth,
              child: Text(
                '${_selectedMonth.year}年${_selectedMonth.month}月',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseByCategoryChart() {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '按类别花费分布',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: Consumer<ExpenseProvider>(
                builder: (context, expenseProvider, child) {
                  final categoryExpenses = expenseProvider.getExpensesByCategory();
                  
                  if (categoryExpenses.isEmpty) {
                    return const Center(
                      child: Text('暂无数据'),
                    );
                  }
                  
                  final colors = [
                    Colors.blue,
                    Colors.red,
                    Colors.green,
                    Colors.orange,
                    Colors.purple,
                    Colors.teal,
                  ];
                  
                  final sections = categoryExpenses.entries.map((entry) {
                    final index = categoryExpenses.keys.toList().indexOf(entry.key);
                    final color = colors[index % colors.length];
                    
                    return PieChartSectionData(
                      color: color,
                      value: entry.value,
                      title: '${(entry.value / categoryExpenses.values.fold(0.0, (a, b) => a + b) * 100).toStringAsFixed(1)}%',
                      radius: 60,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList();
                  
                  return Row(
                    children: [
                      Expanded(
                        child: PieChart(
                          PieChartData(
                            sections: sections,
                            centerSpaceRadius: 40,
                            sectionsSpace: 2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: categoryExpenses.entries.map((entry) {
                          final index = categoryExpenses.keys.toList().indexOf(entry.key);
                          final color = colors[index % colors.length];
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  entry.key,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseByDogChart() {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '按狗狗花费分布',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Consumer2<DogProvider, ExpenseProvider>(
              builder: (context, dogProvider, expenseProvider, child) {
                final dogs = dogProvider.dogs.take(5).toList();
                
                if (dogs.isEmpty) {
                  return const Center(
                    child: Text('暂无数据'),
                  );
                }
                
                return Column(
                  children: dogs.map((dog) {
                    final dogExpenses = expenseProvider.getDogExpenses(dog.dogId);
                    final maxExpense = dogs.map((d) => expenseProvider.getDogExpenses(d.dogId)).reduce((a, b) => a > b ? a : b);
                    final percentage = maxExpense > 0 ? dogExpenses / maxExpense : 0.0;
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  dog.name,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                              Text(
                                '¥${dogExpenses.toStringAsFixed(2)}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: percentage,
                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBreakdown() {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '类别明细',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Consumer<ExpenseProvider>(
              builder: (context, expenseProvider, child) {
                final categoryExpenses = expenseProvider.getExpensesByCategory();
                
                if (categoryExpenses.isEmpty) {
                  return const Center(
                    child: Text('暂无数据'),
                  );
                }
                
                return Column(
                  children: categoryExpenses.entries.map((entry) {
                    return ListTile(
                      leading: const Icon(Icons.category),
                      title: Text(entry.key),
                      trailing: Text(
                        '¥${entry.value.toStringAsFixed(2)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      contentPadding: EdgeInsets.zero,
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfitSummary() {
    return Consumer<DogProvider>(
      builder: (context, dogProvider, child) {
        final totalProfit = dogProvider.getTotalProfit();
        final totalInvestment = dogProvider.getTotalInvestment();
        final totalRevenue = dogProvider.getTotalRevenue();
        final profitMargin = totalRevenue > 0 ? (totalProfit / totalRevenue * 100) : 0.0;
        
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '利润概览',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildProfitMetric(
                        '总投资',
                        '¥${totalInvestment.toStringAsFixed(2)}',
                        Colors.blue,
                      ),
                    ),
                    Expanded(
                      child: _buildProfitMetric(
                        '总收入',
                        '¥${totalRevenue.toStringAsFixed(2)}',
                        Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildProfitMetric(
                        '总利润',
                        '¥${totalProfit.toStringAsFixed(2)}',
                        totalProfit >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                    Expanded(
                      child: _buildProfitMetric(
                        '利润率',
                        '${profitMargin.toStringAsFixed(1)}%',
                        profitMargin >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfitMetric(String title, String value, Color color) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfitByDogChart() {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '各狗狗利润对比',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: Consumer<DogProvider>(
                builder: (context, dogProvider, child) {
                  final dogs = dogProvider.dogs.where((dog) => dog.currentProfit != null).take(10).toList();
                  
                  if (dogs.isEmpty) {
                    return const Center(
                      child: Text('暂无数据'),
                    );
                  }
                  
                  final barGroups = dogs.asMap().entries.map((entry) {
                    final index = entry.key;
                    final dog = entry.value;
                    final profit = dog.currentProfit ?? 0.0;
                    
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: profit,
                          color: profit >= 0 ? Colors.green : Colors.red,
                          width: 16,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }).toList();
                  
                  return BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: dogs.map((d) => d.currentProfit ?? 0.0).reduce((a, b) => a > b ? a : b) * 1.2,
                      minY: dogs.map((d) => d.currentProfit ?? 0.0).reduce((a, b) => a < b ? a : b) * 1.2,
                      barGroups: barGroups,
                      gridData: const FlGridData(
                        show: true,
                        drawVerticalLine: false,
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() < dogs.length) {
                                return Text(
                                  dogs[value.toInt()].name,
                                  style: theme.textTheme.bodySmall,
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '¥${value.toStringAsFixed(0)}',
                                style: theme.textTheme.bodySmall,
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDogProfitDetails() {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '狗狗利润明细',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Consumer<DogProvider>(
              builder: (context, dogProvider, child) {
                final dogs = dogProvider.dogs.where((dog) => dog.currentProfit != null).toList();
                dogs.sort((a, b) => (b.currentProfit ?? 0.0).compareTo(a.currentProfit ?? 0.0));
                
                if (dogs.isEmpty) {
                  return const Center(
                    child: Text('暂无数据'),
                  );
                }
                
                return Column(
                  children: dogs.map((dog) {
                    final profit = dog.currentProfit ?? 0.0;
                    
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: profit >= 0 
                            ? Colors.green.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                        child: Icon(
                          Icons.pets,
                          color: profit >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                      title: Text(dog.name),
                      subtitle: Text('${dog.breed} • ${dog.statusText}'),
                      trailing: Text(
                        '${profit >= 0 ? '+' : ''}¥${profit.toStringAsFixed(2)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: profit >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                      contentPadding: EdgeInsets.zero,
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}