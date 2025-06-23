import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/expense_provider.dart';
import '../../providers/dog_provider.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../models/expense.dart';
import '../../models/dog.dart';

class AddExpenseScreen extends StatefulWidget {
  final String? preselectedDogId;
  
  const AddExpenseScreen({super.key, this.preselectedDogId});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  
  ExpenseCategory? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  final List<String> _selectedDogIds = [];
  final Map<String, double> _dogShareRatios = {};
  bool _isLoading = false;
  bool _isEqualShare = true;

  @override
  void initState() {
    super.initState();
    // 延迟加载数据，避免在构建过程中触发状态更新
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    
    try {
      await Future.wait([
        context.read<ExpenseProvider>().loadCategories(),
        context.read<DogProvider>().loadDogs(),
      ]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载数据失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _onDogSelectionChanged(String dogId, bool selected) {
    setState(() {
      if (selected) {
        _selectedDogIds.add(dogId);
        _dogShareRatios[dogId] = 1.0;
      } else {
        _selectedDogIds.remove(dogId);
        _dogShareRatios.remove(dogId);
      }
      _updateShareRatios();
    });
  }

  void _updateShareRatios() {
    if (_isEqualShare && _selectedDogIds.isNotEmpty) {
      final equalRatio = 1.0 / _selectedDogIds.length;
      for (final dogId in _selectedDogIds) {
        _dogShareRatios[dogId] = equalRatio;
      }
    }
  }

  void _onShareModeChanged(bool isEqual) {
    setState(() {
      _isEqualShare = isEqual;
      if (isEqual) {
        _updateShareRatios();
      }
    });
  }

  void _onShareRatioChanged(String dogId, double ratio) {
    setState(() {
      _dogShareRatios[dogId] = ratio;
    });
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请选择花费类别'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedDogIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请至少选择一只狗狗'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate share ratios sum to 1.0
    final totalRatio = _dogShareRatios.values.fold(0.0, (sum, ratio) => sum + ratio);
    if ((totalRatio - 1.0).abs() > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('分摊比例总和必须等于100%'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final expenseData = {
        'category_id': _selectedCategory!.categoryId,
        'amount': double.parse(_amountController.text),
        'date': _selectedDate.toIso8601String(),
        'note': _noteController.text.trim(),
        'dog_links': _selectedDogIds.map((dogId) => {
          'dog_id': dogId,
          'share_ratio': _dogShareRatios[dogId]!,
        }).toList(),
      };

      await context.read<ExpenseProvider>().addExpense(expenseData);

      if (mounted) {
        context.go('/expenses');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('花费记录已添加'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('添加花费'),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _saveExpense,
              child: const Text('保存'),
            ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Basic info section
                _buildBasicInfoSection(),
                
                const SizedBox(height: 24),
                
                // Dog selection section
                _buildDogSelectionSection(),
                
                const SizedBox(height: 24),
                
                // Share ratio section
                if (_selectedDogIds.isNotEmpty)
                  _buildShareRatioSection(),
                
                const SizedBox(height: 32),
                
                // Save button
                SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    onPressed: _isLoading ? null : _saveExpense,
                    isLoading: _isLoading,
                    text: '添加花费',
                  ),
                ),
                
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '基本信息',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Category selection
            Consumer<ExpenseProvider>(
              builder: (context, expenseProvider, child) {
                final categories = expenseProvider.categories;
                
                return DropdownButtonFormField<ExpenseCategory>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: '花费类别',
                    hintText: '请选择花费类别',
                  ),
                  items: categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category.name),
                    );
                  }).toList(),
                  onChanged: (category) {
                    setState(() {
                      _selectedCategory = category;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return '请选择花费类别';
                    }
                    return null;
                  },
                );
              },
            ),
            
            const SizedBox(height: 16),
            
            NumberTextField(
              controller: _amountController,
              label: '金额',
              hintText: '请输入花费金额',
              decimalPlaces: 2,
              prefix: '¥ ',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入花费金额';
                }
                final amount = double.tryParse(value);
                if (amount == null || amount <= 0) {
                  return '请输入有效的金额';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Date selection
            InkWell(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: '日期',
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  _selectedDate.toString().split(' ')[0],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            CustomTextField(
              controller: _noteController,
              label: '备注',
              hintText: '请输入花费备注（可选）',
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDogSelectionSection() {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '关联狗狗',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              '选择此花费关联的狗狗',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            
            const SizedBox(height: 16),
            
            Consumer<DogProvider>(
              builder: (context, dogProvider, child) {
                final dogs = dogProvider.dogs;
                
                if (dogs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info,
                          color: theme.colorScheme.onSurface,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '还没有添加狗狗，请先添加狗狗',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                return Column(
                  children: dogs.map((dog) {
                    final isSelected = _selectedDogIds.contains(dog.dogId);
                    
                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (selected) {
                        _onDogSelectionChanged(dog.dogId, selected ?? false);
                      },
                      title: Text(dog.name),
                      subtitle: Text('${dog.breed} • ${dog.sexText}'),
                      secondary: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 40,
                          height: 40,
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: dog.imageUrls.isNotEmpty
                              ? Image.network(
                                  dog.imageUrls.first,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.pets,
                                      color: theme.colorScheme.onSurface,
                                    );
                                  },
                                )
                              : Icon(
                                  Icons.pets,
                                  color: theme.colorScheme.onSurface,
                                ),
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

  Widget _buildShareRatioSection() {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '分摊比例',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              '设置花费在各只狗狗之间的分摊比例',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Share mode selection
            Row(
              children: [
                Expanded(
                  child: RadioListTile<bool>(
                    title: const Text('平均分摊'),
                    value: true,
                    groupValue: _isEqualShare,
                    onChanged: (value) {
                      _onShareModeChanged(value!);
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Expanded(
                  child: RadioListTile<bool>(
                    title: const Text('自定义比例'),
                    value: false,
                    groupValue: _isEqualShare,
                    onChanged: (value) {
                      _onShareModeChanged(value!);
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Share ratio inputs
                                        Consumer<DogProvider>(
              builder: (context, dogProvider, child) {
                return Column(
                  children: _selectedDogIds.map((dogId) {
                    final dogList = dogProvider.allDogs;
                    final dog = dogList.firstWhere(
                      (d) => d.dogId == dogId,
                      orElse: () => Dog(
                        dogId: dogId,
                        name: dogId,
                        createdBy: '',
                        createdAt: DateTime.now(),
                      ),
                    );
                    final ratio = _dogShareRatios[dogId] ?? 0.0;
                    final amount = double.tryParse(_amountController.text) ?? 0.0;
                    final dogAmount = amount * ratio;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          // Dog info
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dog.name,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '¥${dogAmount.toStringAsFixed(2)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Ratio input
                          Expanded(
                            child: _isEqualShare
                                ? Text(
                                    '${(ratio * 100).toStringAsFixed(1)}%',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyMedium,
                                  )
                                : TextFormField(
                                    initialValue: (ratio * 100).toStringAsFixed(1),
                                    decoration: const InputDecoration(
                                      suffixText: '%',
                                      isDense: true,
                                    ),
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    onChanged: (value) {
                                      final percentage = double.tryParse(value) ?? 0.0;
                                      _onShareRatioChanged(dogId, percentage / 100);
                                    },
                                  ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            
            // Total validation
            if (!_isEqualShare) ...
              [
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getTotalRatioColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getTotalRatioIcon(),
                        size: 16,
                        color: _getTotalRatioColor(),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '总比例: ${(_dogShareRatios.values.fold(0.0, (sum, ratio) => sum + ratio) * 100).toStringAsFixed(1)}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _getTotalRatioColor(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
          ],
        ),
      ),
    );
  }

  Color _getTotalRatioColor() {
    final totalRatio = _dogShareRatios.values.fold(0.0, (sum, ratio) => sum + ratio);
    if ((totalRatio - 1.0).abs() <= 0.01) {
      return Colors.green;
    } else {
      return Colors.red;
    }
  }

  IconData _getTotalRatioIcon() {
    final totalRatio = _dogShareRatios.values.fold(0.0, (sum, ratio) => sum + ratio);
    if ((totalRatio - 1.0).abs() <= 0.01) {
      return Icons.check_circle;
    } else {
      return Icons.error;
    }
  }
}