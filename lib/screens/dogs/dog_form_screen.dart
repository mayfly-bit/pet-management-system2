import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/dog_provider.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../models/dog.dart';

class DogFormScreen extends StatefulWidget {
  final String? dogId;
  
  const DogFormScreen({
    super.key,
    this.dogId,
  });

  bool get isEditing => dogId != null;

  @override
  State<DogFormScreen> createState() => _DogFormScreenState();
}

class _DogFormScreenState extends State<DogFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _weightController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _salePriceController = TextEditingController();
  
  DateTime _dateOfBirth = DateTime.now().subtract(const Duration(days: 365));
  DogSex _sex = DogSex.male;
  DogStatus _status = DogStatus.available;
  final List<File> _selectedImages = [];
  List<String> _existingImageUrls = [];
  bool _isLoading = false;
  Dog? _originalDog;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _loadDogData();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _weightController.dispose();
    _descriptionController.dispose();
    _purchasePriceController.dispose();
    _salePriceController.dispose();
    super.dispose();
  }

  Future<void> _loadDogData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dog = await context.read<DogProvider>().getDogById(widget.dogId!);
      if (dog != null) {
        setState(() {
          _originalDog = dog;
          _nameController.text = dog.name;
          _breedController.text = dog.breed ?? '';
          _weightController.text = dog.weight?.toString() ?? '';
          _descriptionController.text = dog.description ?? '';
          _purchasePriceController.text = dog.purchasePrice?.toString() ?? '';
          _salePriceController.text = dog.salePrice?.toString() ?? '';
          _dateOfBirth = dog.dateOfBirth ?? DateTime.now();
          _sex = dog.sex ?? DogSex.male;
          _status = dog.status;
          _existingImageUrls = List.from(dog.imageUrls);
        });
      }
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

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images.map((xfile) => File(xfile.path)));
      });
    }
  }

  void _removeSelectedImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingImageUrls.removeAt(index);
    });
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    
    if (picked != null && picked != _dateOfBirth) {
      setState(() {
        _dateOfBirth = picked;
      });
    }
  }

  Future<void> _saveDog() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final dogProvider = context.read<DogProvider>();
      
      final dogData = {
        'name': _nameController.text.trim(),
        'breed': _breedController.text.trim().isEmpty ? null : _breedController.text.trim(),
        'date_of_birth': _dateOfBirth.toIso8601String(),
        'sex': _sex.name,
        'status': _status.name,
        'weight': _weightController.text.isNotEmpty 
            ? double.tryParse(_weightController.text) 
            : null,
        'description': _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        'purchase_price': _purchasePriceController.text.isNotEmpty 
            ? double.tryParse(_purchasePriceController.text) 
            : null,
        'sale_price': _salePriceController.text.isNotEmpty 
            ? double.tryParse(_salePriceController.text) 
            : null,
      };

      String dogId;
      if (widget.isEditing) {
        await dogProvider.updateDog(widget.dogId!, dogData);
        dogId = widget.dogId!;
      } else {
        dogId = await dogProvider.addDog(dogData);
      }

      // Handle image uploads
      if (_selectedImages.isNotEmpty) {
        for (final image in _selectedImages) {
          await dogProvider.uploadDogImage(dogId, image);
        }
      }

      // Handle image deletions (for editing)
      if (widget.isEditing && _originalDog != null) {
        final deletedImages = _originalDog!.imageUrls
            .where((url) => !_existingImageUrls.contains(url))
            .toList();
        
        for (final imageUrl in deletedImages) {
          await dogProvider.deleteDogImage(dogId, imageUrl);
        }
      }

      if (mounted) {
        context.go('/dogs/$dogId');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isEditing ? '狗狗信息已更新' : '狗狗已添加'),
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
        title: Text(widget.isEditing ? '编辑狗狗' : '添加狗狗'),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _saveDog,
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
                // Images section
                _buildImagesSection(),
                
                const SizedBox(height: 24),
                
                // Basic info section
                _buildBasicInfoSection(),
                
                const SizedBox(height: 24),
                
                // Financial info section
                _buildFinancialInfoSection(),
                
                const SizedBox(height: 24),
                
                // Description section
                _buildDescriptionSection(),
                
                const SizedBox(height: 32),
                
                // Save button
                SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    onPressed: _isLoading ? null : _saveDog,
                    isLoading: _isLoading,
                    text: widget.isEditing ? '更新狗狗' : '添加狗狗',
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

  Widget _buildImagesSection() {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '照片',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _pickImages,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('添加照片'),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            if (_existingImageUrls.isEmpty && _selectedImages.isEmpty)
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.5),
                    style: BorderStyle.solid,
                  ),
                ),
                child: InkWell(
                  onTap: _pickImages,
                  borderRadius: BorderRadius.circular(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate,
                        size: 48,
                        color: theme.colorScheme.onSurface,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '点击添加照片',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SizedBox(
                height: 120,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    // Existing images
                    ..._existingImageUrls.asMap().entries.map((entry) {
                      final index = entry.key;
                      final imageUrl = entry.value;
                      
                      return Container(
                        width: 120,
                        margin: const EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                imageUrl,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 120,
                                    height: 120,
                                    color: theme.colorScheme.surfaceContainerHighest,
                                    child: Icon(
                                      Icons.broken_image,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  );
                                },
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _removeExistingImage(index),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    
                    // Selected images
                    ..._selectedImages.asMap().entries.map((entry) {
                      final index = entry.key;
                      final image = entry.value;
                      
                      return Container(
                        width: 120,
                        margin: const EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                image,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _removeSelectedImage(index),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    
                    // Add more button
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.5),
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: InkWell(
                        onTap: _pickImages,
                        borderRadius: BorderRadius.circular(8),
                        child: Icon(
                          Icons.add,
                          size: 32,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
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
            
            CustomTextField(
              controller: _nameController,
                                    label: '名称',
              hintText: '请输入狗狗名称',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入狗狗名称';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            CustomTextField(
              controller: _breedController,
                                    label: '品种',
              hintText: '请输入狗狗品种',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入狗狗品种';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Date of birth
            InkWell(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                                        labelText: '出生日期',
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  _dateOfBirth.toString().split(' ')[0],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Sex selection
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '性别',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<DogSex>(
                        title: const Text('公'),
                        value: DogSex.male,
                        groupValue: _sex,
                        onChanged: (value) {
                          setState(() {
                            _sex = value!;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<DogSex>(
                        title: const Text('母'),
                        value: DogSex.female,
                        groupValue: _sex,
                        onChanged: (value) {
                          setState(() {
                            _sex = value!;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Status selection
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '状态',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<DogStatus>(
                        title: const Text('在售'),
                        value: DogStatus.available,
                        groupValue: _status,
                        onChanged: (value) {
                          setState(() {
                            _status = value!;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<DogStatus>(
                        title: const Text('已售'),
                        value: DogStatus.sold,
                        groupValue: _status,
                        onChanged: (value) {
                          setState(() {
                            _status = value!;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            NumberTextField(
              controller: _weightController,
              label: '体重 (kg)',
              hintText: '请输入体重',
              decimalPlaces: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialInfoSection() {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '财务信息',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            
            const SizedBox(height: 16),
            
            NumberTextField(
              controller: _purchasePriceController,
              label: '购入价格',
              hintText: '请输入购入价格',
              decimalPlaces: 2,
              prefix: '¥ ',
            ),
            
            const SizedBox(height: 16),
            
            NumberTextField(
              controller: _salePriceController,
              label: '销售价格',
              hintText: '请输入销售价格',
              decimalPlaces: 2,
              prefix: '¥ ',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionSection() {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '描述',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            
            const SizedBox(height: 16),
            
            CustomTextField(
              controller: _descriptionController,
                                    label: '描述',
              hintText: '请输入狗狗的特点、性格等描述信息',
              maxLines: 4,
            ),
          ],
        ),
      ),
    );
  }
}