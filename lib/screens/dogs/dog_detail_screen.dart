import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/dog_provider.dart';
import '../../providers/expense_provider.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/error_widget.dart';
import '../../models/dog.dart';
import '../../models/expense.dart';

class DogDetailScreen extends StatefulWidget {
  final String dogId;
  
  const DogDetailScreen({
    super.key,
    required this.dogId,
  });

  @override
  State<DogDetailScreen> createState() => _DogDetailScreenState();
}

class _DogDetailScreenState extends State<DogDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  Dog? _dog;
  List<Expense> _dogExpenses = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDogData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDogData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dogProvider = context.read<DogProvider>();
      final expenseProvider = context.read<ExpenseProvider>();
      
      // Load dog details
      final dog = await dogProvider.getDogById(widget.dogId);
      if (dog == null) {
        throw Exception('狗狗不存在');
      }
      
      // Load dog expenses
      final expenses = expenseProvider.getExpensesForDog(widget.dogId);
      
      setState(() {
        _dog = dog;
        _dogExpenses = expenses;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载狗狗信息失败: $e'),
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

  Future<void> _deleteDog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除 "${_dog?.name}" 吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await context.read<DogProvider>().deleteDog(widget.dogId);
        if (mounted) {
          context.go('/dogs');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('狗狗已删除'),
              backgroundColor: Colors.green,
            ),
          );
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: LoadingWidget(message: '加载狗狗信息中...'),
        ),
      );
    }

    if (_dog == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('狗狗详情'),
        ),
        body: const Center(
          child: CustomErrorWidget(
            message: '狗狗不存在',
          ),
        ),
      );
    }

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            _buildSliverAppBar(),
          ];
        },
        body: Column(
          children: [
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildInfoTab(),
                  _buildExpensesTab(),
                  _buildPhotosTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/dogs/${widget.dogId}/edit'),
        child: const Icon(Icons.edit),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    final theme = Theme.of(context);
    
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          _dog!.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        background: _dog!.imageUrls.isNotEmpty
            ? PageView.builder(
                itemCount: _dog!.imageUrls.length,
                itemBuilder: (context, index) {
                  return Image.network(
                    _dog!.imageUrls[index],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.pets,
                          size: 80,
                          color: theme.colorScheme.onSurface,
                        ),
                      );
                    },
                  );
                },
              )
            : Container(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.pets,
                  size: 80,
                  color: theme.colorScheme.onSurface,
                ),
              ),
      ),
      actions: [
        PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                context.go('/dogs/${widget.dogId}/edit');
                break;
              case 'delete':
                _deleteDog();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit),
                title: Text('编辑'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('删除', style: TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      tabs: const [
        Tab(text: '基本信息'),
        Tab(text: '花费记录'),
        Tab(text: '照片'),
      ],
    );
  }

  Widget _buildInfoTab() {
    final theme = Theme.of(context);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status and profit card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatusChip(_dog!.status),
                      ),
                      if (_dog!.currentProfit != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _dog!.currentProfit! >= 0
                                ? Colors.green.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '当前利润: ${_dog!.currentProfit! >= 0 ? '+' : ''}¥${_dog!.currentProfit!.toStringAsFixed(2)}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: _dog!.currentProfit! >= 0
                                  ? Colors.green
                                  : Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Basic info
          _buildInfoSection(
            '基本信息',
            [
              _buildInfoRow('品种', _dog!.breed ?? '未知'),
              _buildInfoRow('性别', _dog!.sexText),
              _buildInfoRow('出生日期', _dog!.dateOfBirth?.toString().split(' ')[0] ?? '未知'),
              _buildInfoRow('年龄', _dog!.ageText),
              if (_dog!.weight != null)
                _buildInfoRow('体重', '${_dog!.weight!.toStringAsFixed(1)} kg'),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Financial info
          _buildInfoSection(
            '财务信息',
            [
              if (_dog!.purchasePrice != null)
                _buildInfoRow('购入价格', '¥${_dog!.purchasePrice!.toStringAsFixed(2)}'),
              if (_dog!.salePrice != null)
                _buildInfoRow('销售价格', '¥${_dog!.salePrice!.toStringAsFixed(2)}'),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Description
          if (_dog!.description?.isNotEmpty == true)
            _buildInfoSection(
              '描述',
              [
                Text(
                  _dog!.description!,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          
          const SizedBox(height: 16),
          
          // Creation info
          _buildInfoSection(
            '创建信息',
            [
              _buildInfoRow('创建时间', _dog!.createdAt.toString().split('.')[0]),
              _buildInfoRow('创建者', _dog!.createdBy),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpensesTab() {
    final theme = Theme.of(context);
    
    if (_dogExpenses.isEmpty) {
      return const Center(
        child: EmptyStateWidget(
          title: '暂无花费记录',
          message: '还没有为这只狗狗记录任何花费',
          icon: Icons.receipt_long,
        ),
      );
    }
    
    // Calculate total expenses
    final totalExpenses = _dogExpenses.fold<double>(
      0,
      (sum, expense) => sum + expense.getDogSpecificAmount(widget.dogId),
    );
    
    return Column(
      children: [
        // Total expenses card
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                '总花费',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '¥${totalExpenses.toStringAsFixed(2)}',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        
        // Expenses list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _dogExpenses.length,
            itemBuilder: (context, index) {
              final expense = _dogExpenses[index];
              final amount = expense.getDogSpecificAmount(widget.dogId);
              
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.secondaryContainer,
                    child: Icon(
                      Icons.receipt,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                  title: Text(expense.category?.name ?? '未分类'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(expense.date.toString().split(' ')[0]),
                      if (expense.note?.isNotEmpty == true)
                        Text(
                          expense.note!,
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                  trailing: Text(
                    '¥${amount.toStringAsFixed(2)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  isThreeLine: expense.note?.isNotEmpty == true,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPhotosTab() {
    final theme = Theme.of(context);
    
    if (_dog!.imageUrls.isEmpty) {
      return const Center(
        child: EmptyStateWidget(
          title: '暂无照片',
          message: '还没有为这只狗狗上传照片',
          icon: Icons.photo,
        ),
      );
    }
    
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1,
      ),
      itemCount: _dog!.imageUrls.length,
      itemBuilder: (context, index) {
        final imageUrl = _dog!.imageUrls[index];
        
        return GestureDetector(
          onTap: () {
            // Show full screen image
            showDialog(
              context: context,
              builder: (context) => Dialog(
                backgroundColor: Colors.transparent,
                child: Stack(
                  children: [
                    Center(
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                      ),
                    ),
                    Positioned(
                      top: 40,
                      right: 20,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.broken_image,
                    size: 40,
                    color: theme.colorScheme.onSurface,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(DogStatus status) {
    final theme = Theme.of(context);
    
    Color backgroundColor;
    Color textColor;
    String text;
    IconData icon;
    
    switch (status) {
      case DogStatus.available:
        backgroundColor = Colors.green.withOpacity(0.1);
        textColor = Colors.green;
        text = '在售';
        icon = Icons.pets;
        break;
      case DogStatus.sold:
        backgroundColor = Colors.blue.withOpacity(0.1);
        textColor = Colors.blue;
        text = '已售';
        icon = Icons.check_circle;
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: textColor,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}