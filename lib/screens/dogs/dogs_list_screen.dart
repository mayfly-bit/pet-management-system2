import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/dog_provider.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/error_widget.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../models/dog.dart';

class DogsListScreen extends StatefulWidget {
  const DogsListScreen({super.key});

  @override
  State<DogsListScreen> createState() => _DogsListScreenState();
}

class _DogsListScreenState extends State<DogsListScreen> {
  final _searchController = TextEditingController();
  bool _isRefreshing = false;
  DogStatus? _selectedStatus;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // 延迟加载数据，避免在构建过程中触发状态更新
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDogs();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDogs() async {
    if (!mounted) return;
    
    setState(() {
      _isRefreshing = true;
    });

    try {
      await context.read<DogProvider>().loadDogs();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载狗狗列表失败: $e'),
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
    context.read<DogProvider>().setSearchQuery(query);
  }

  void _onStatusFilterChanged(DogStatus? status) {
    setState(() {
      _selectedStatus = status;
    });
    context.read<DogProvider>().setStatusFilter(status);
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _selectedStatus = null;
    });
    _searchController.clear();
    context.read<DogProvider>().clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('狗狗管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _loadDogs,
          ),
          IconButton(
            icon: const Icon(Icons.sell),
            onPressed: () => context.go('/dogs/sale'),
            tooltip: '记录销售',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.go('/dogs/add'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and filter section
          _buildSearchAndFilter(),
          
          // Dogs list
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadDogs,
              child: LoadingOverlay(
                isLoading: _isRefreshing,
                child: Consumer<DogProvider>(
                  builder: (context, dogProvider, child) {
                    if (dogProvider.isLoading && dogProvider.dogs.isEmpty) {
                      return const Center(
                        child: LoadingWidget(message: '加载狗狗列表中...'),
                      );
                    }

                    if (dogProvider.error != null) {
                      return Center(
                        child: CustomErrorWidget(
                          message: dogProvider.error!,
                          onRetry: _loadDogs,
                        ),
                      );
                    }

                    final filteredDogs = dogProvider.filteredDogs;

                    if (filteredDogs.isEmpty) {
                      return Center(
                        child: EmptyStateWidget(
                          title: _searchQuery.isNotEmpty || _selectedStatus != null
                              ? '没有找到匹配的狗狗'
                              : '还没有添加狗狗',
                          message: _searchQuery.isNotEmpty || _selectedStatus != null
                              ? '尝试调整搜索条件或筛选器'
                              : '点击右上角的 + 按钮添加第一只狗狗',
                          icon: _searchQuery.isNotEmpty || _selectedStatus != null
                              ? Icons.search_off
                              : Icons.pets,
                          onAction: _searchQuery.isNotEmpty || _selectedStatus != null
                              ? _clearFilters
                              : () => context.go('/dogs/add'),
                          actionText: _searchQuery.isNotEmpty || _selectedStatus != null
                              ? '清除筛选'
                              : '添加狗狗',
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredDogs.length,
                      itemBuilder: (context, index) {
                        final dog = filteredDogs[index];
                        return _buildDogCard(dog);
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
        onPressed: () => context.go('/dogs/add'),
        child: const Icon(Icons.add),
      ),
    );
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
            hintText: '搜索狗狗名称、品种...',
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
          
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('全部'),
                  selected: _selectedStatus == null,
                  onSelected: (selected) {
                    if (selected) {
                      _onStatusFilterChanged(null);
                    }
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('在售'),
                  selected: _selectedStatus == DogStatus.available,
                  onSelected: (selected) {
                    _onStatusFilterChanged(
                      selected ? DogStatus.available : null,
                    );
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('已售'),
                  selected: _selectedStatus == DogStatus.sold,
                  onSelected: (selected) {
                    _onStatusFilterChanged(
                      selected ? DogStatus.sold : null,
                    );
                  },
                ),
                const SizedBox(width: 8),
                if (_searchQuery.isNotEmpty || _selectedStatus != null)
                  ActionChip(
                    label: const Text('清除筛选'),
                    onPressed: _clearFilters,
                    avatar: const Icon(Icons.clear, size: 16),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDogCard(Dog dog) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => context.go('/dogs/${dog.dogId}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Dog image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 80,
                  height: 80,
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: dog.imageUrls.isNotEmpty
                      ? Image.network(
                          dog.imageUrls.first,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.pets,
                              size: 40,
                              color: theme.colorScheme.onSurface,
                            );
                          },
                        )
                      : Icon(
                          Icons.pets,
                          size: 40,
                          color: theme.colorScheme.onSurface,
                        ),
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Dog info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            dog.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        _buildStatusChip(dog.status),
                      ],
                    ),
                    
                    const SizedBox(height: 4),
                    
                    Text(
                      '${dog.breed} • ${dog.sexText}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    
                    const SizedBox(height: 4),
                    
                    Text(
                      '年龄: ${dog.ageText}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    Row(
                      children: [
                        if (dog.purchasePrice != null) ...
                          [
                            Text(
                              '购入: ¥${dog.purchasePrice!.toStringAsFixed(0)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(width: 16),
                          ],
                        if (dog.salePrice != null) ...
                          [
                            Text(
                              '售价: ¥${dog.salePrice!.toStringAsFixed(0)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.green,
                              ),
                            ),
                          ],
                        const Spacer(),
                        if (dog.currentProfit != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: dog.currentProfit! >= 0
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${dog.currentProfit! >= 0 ? '+' : ''}¥${dog.currentProfit!.toStringAsFixed(0)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: dog.currentProfit! >= 0
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
              
              // Arrow icon
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(DogStatus status) {
    final theme = Theme.of(context);
    
    Color backgroundColor;
    Color textColor;
    String text;
    
    switch (status) {
      case DogStatus.available:
        backgroundColor = Colors.green.withOpacity(0.1);
        textColor = Colors.green;
        text = '在售';
        break;
      case DogStatus.sold:
        backgroundColor = Colors.blue.withOpacity(0.1);
        textColor = Colors.blue;
        text = '已售';
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}