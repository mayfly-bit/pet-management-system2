import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../models/dog.dart';
import '../../providers/dog_provider.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_button.dart';

class SaleRecordScreen extends StatefulWidget {
  const SaleRecordScreen({super.key});

  @override
  State<SaleRecordScreen> createState() => _SaleRecordScreenState();
}

class _SaleRecordScreenState extends State<SaleRecordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _salePriceController = TextEditingController();
  final _buyerNameController = TextEditingController();
  final _notesController = TextEditingController();
  
  Dog? _selectedDog;
  DateTime _saleDate = DateTime.now();
  bool _isLoading = false;

  @override
  void dispose() {
    _salePriceController.dispose();
    _buyerNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAvailableDogs();
    });
  }

  Future<void> _loadAvailableDogs() async {
    final dogProvider = Provider.of<DogProvider>(context, listen: false);
    await dogProvider.loadDogs();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _saleDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _saleDate) {
      setState(() {
        _saleDate = picked;
      });
    }
  }

  Future<void> _recordSale() async {
    if (!_formKey.currentState!.validate() || _selectedDog == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请填写完整信息并选择狗狗'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final dogProvider = Provider.of<DogProvider>(context, listen: false);
      final salePrice = double.parse(_salePriceController.text);
      
      // 更新狗狗状态为已售出，并设置销售价格
      final success = await dogProvider.updateDog(_selectedDog!.dogId, {
        'name': _selectedDog!.name,
        'breed': _selectedDog!.breed,
        'date_of_birth': _selectedDog!.dateOfBirth?.toIso8601String(),
        'sex': _selectedDog!.sex?.name,
        'weight': _selectedDog!.weight,
        'description': _selectedDog!.description,
        'purchase_price': _selectedDog!.purchasePrice,
        'sale_price': salePrice,
        'status': 'sold',
        'created_by': _selectedDog!.createdBy,
        'created_at': _selectedDog!.createdAt.toIso8601String(),
        'sale_date': _saleDate.toIso8601String(),
        'buyer_name': _buyerNameController.text.trim().isEmpty ? null : _buyerNameController.text.trim(),
        'sale_notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('成功记录 ${_selectedDog!.name} 的销售信息'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('记录销售失败，请重试'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('记录销售失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  double _calculateProfit() {
    if (_selectedDog == null || _salePriceController.text.isEmpty) {
      return 0.0;
    }
    
    final salePrice = double.tryParse(_salePriceController.text) ?? 0.0;
    final purchasePrice = _selectedDog!.purchasePrice ?? 0.0;
    
    return salePrice - purchasePrice;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('记录销售'),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _recordSale,
              child: const Text('保存'),
            ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: Consumer<DogProvider>(
          builder: (context, dogProvider, child) {
            final availableDogs = dogProvider.dogs
                .where((dog) => dog.status == DogStatus.available)
                .toList();

            if (dogProvider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (availableDogs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.pets_outlined,
                      size: 80,
                      color: theme.colorScheme.onSurface.withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '暂无在售狗狗',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '请先添加狗狗或检查狗狗状态',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 选择狗狗卡片
                    _buildDogSelectionCard(availableDogs),
                    
                    const SizedBox(height: 16),
                    
                    // 销售信息卡片
                    _buildSaleInfoCard(),
                    
                    const SizedBox(height: 16),
                    
                    // 利润计算卡片
                    _buildProfitCard(),
                    
                    const SizedBox(height: 32),
                    
                    // 保存按钮
                    SizedBox(
                      width: double.infinity,
                      child: PrimaryButton(
                        onPressed: _isLoading ? null : _recordSale,
                        isLoading: _isLoading,
                        text: '记录销售',
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDogSelectionCard(List<Dog> availableDogs) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '选择狗狗',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            
            ...availableDogs.map((dog) => _buildDogOption(dog)),
          ],
        ),
      ),
    );
  }

  Widget _buildDogOption(Dog dog) {
    final theme = Theme.of(context);
    final isSelected = _selectedDog?.dogId == dog.dogId;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedDog = dog;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected 
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected 
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline.withOpacity(0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // 头像
              CircleAvatar(
                radius: 24,
                backgroundColor: theme.colorScheme.primary,
                child: dog.imageUrls.isNotEmpty
                    ? ClipOval(
                        child: Image.network(
                          dog.imageUrls.first,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.pets,
                              color: theme.colorScheme.onPrimary,
                            );
                          },
                        ),
                      )
                    : Icon(
                        Icons.pets,
                        color: theme.colorScheme.onPrimary,
                      ),
              ),
              
              const SizedBox(width: 12),
              
              // 狗狗信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dog.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? theme.colorScheme.onPrimaryContainer : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${dog.breed ?? '未知品种'} • ${dog.sex?.displayName ?? '未知性别'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isSelected 
                            ? theme.colorScheme.onPrimaryContainer.withOpacity(0.8)
                            : theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    if (dog.purchasePrice != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '购入价: ¥${dog.purchasePrice!.toStringAsFixed(2)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isSelected 
                              ? theme.colorScheme.onPrimaryContainer.withOpacity(0.8)
                              : theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // 选中指示器
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: theme.colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSaleInfoCard() {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '销售信息',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            
            NumberTextField(
              controller: _salePriceController,
              label: '销售价格',
              hintText: '请输入销售价格',
              decimalPlaces: 2,
              prefix: '¥ ',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入销售价格';
                }
                final price = double.tryParse(value);
                if (price == null || price <= 0) {
                  return '请输入有效的销售价格';
                }
                return null;
              },
              onChanged: (value) {
                setState(() {}); // 触发利润重新计算
              },
            ),
            
            const SizedBox(height: 16),
            
            // 销售日期
            InkWell(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: '销售日期',
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  _saleDate.toString().split(' ')[0],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            CustomTextField(
              controller: _buyerNameController,
              label: '买家姓名',
              hintText: '请输入买家姓名（可选）',
              prefixIcon: Icons.person_outline,
            ),
            
            const SizedBox(height: 16),
            
            CustomTextField(
              controller: _notesController,
              label: '备注',
              hintText: '请输入销售备注（可选）',
              maxLines: 3,
              prefixIcon: Icons.note_outlined,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfitCard() {
    final theme = Theme.of(context);
    final profit = _calculateProfit();
    final isProfit = profit > 0;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '利润预览',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            
            if (_selectedDog != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '购入价格:',
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(
                    '¥${(_selectedDog!.purchasePrice ?? 0.0).toStringAsFixed(2)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '销售价格:',
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(
                    '¥${(double.tryParse(_salePriceController.text) ?? 0.0).toStringAsFixed(2)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              
              const Divider(height: 24),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '预计利润:',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${isProfit ? '+' : ''}¥${profit.toStringAsFixed(2)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isProfit ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ] else
              Text(
                '请先选择狗狗',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// 扩展DogSex枚举以支持显示名称
extension DogSexExtension on DogSex {
  String get displayName {
    switch (this) {
      case DogSex.male:
        return '公';
      case DogSex.female:
        return '母';
    }
  }
} 