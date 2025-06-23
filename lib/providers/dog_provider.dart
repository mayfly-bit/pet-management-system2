import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/dog.dart';
import '../services/dog_service.dart';
import '../services/local_storage_service.dart';

class DogProvider extends ChangeNotifier {
  final DogService _dogService = DogService();
  
  List<Dog> _dogs = [];
  bool _isLoading = false;
  String? _errorMessage;
  DogStatus? _statusFilter;
  String _searchQuery = '';

  List<Dog> get dogs => _getFilteredDogs();
  List<Dog> get allDogs => _dogs;
  List<Dog> get filteredDogs => _getFilteredDogs();
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get error => _errorMessage;
  DogStatus? get statusFilter => _statusFilter;
  String get searchQuery => _searchQuery;

  // Statistics
  int get totalDogs => _dogs.length;
  int get availableDogs => _dogs.where((dog) => dog.status == DogStatus.available).length;
  int get soldDogs => _dogs.where((dog) => dog.status == DogStatus.sold).length;
  int get puppies => _dogs.where((dog) => dog.isPuppy).length;
  
  double get totalProfit => _dogs
      .where((dog) => dog.currentProfit != null)
      .fold(0.0, (sum, dog) => sum + dog.currentProfit!);
  
  double get totalInvestment => _dogs
      .where((dog) => dog.purchasePrice != null)
      .fold(0.0, (sum, dog) => sum + dog.purchasePrice!);
  
  double get totalRevenue => _dogs
      .where((dog) => dog.salePrice != null)
      .fold(0.0, (sum, dog) => sum + dog.salePrice!);

  // Statistics getter
  Map<String, dynamic> get statistics => {
    'totalDogs': totalDogs,
    'availableDogs': availableDogs,
    'soldDogs': soldDogs,
    'puppies': puppies,
    'totalProfit': totalProfit,
    'totalInvestment': totalInvestment,
    'totalRevenue': totalRevenue,
  };

  Future<void> loadDogs({bool forceRefresh = false}) async {
    _setLoading(true);
    _clearError();
    
    try {
      // Try to load from cache first if not forcing refresh
      if (!forceRefresh) {
        final cachedDogs = await LocalStorageService.getCachedDogs();
        if (cachedDogs.isNotEmpty) {
          _dogs = cachedDogs;
          notifyListeners();
        }
      }
      
      // Load from server
      final dogs = await _dogService.getAllDogs();
      _dogs = dogs;
      
      // Cache the data
      await LocalStorageService.cacheDogs(dogs);
      
    } catch (e) {
      _setError('加载狗狗列表失败: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<String> addDog(Map<String, dynamic> dogData) async {
    _setLoading(true);
    _clearError();
    
    try {
      // 获取当前用户ID
      String currentUserId;
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        currentUserId = user.id;  // 这是真实的UUID格式
      } else {
        // 如果未登录，使用有效的UUID格式的演示用户ID
        currentUserId = '00000000-0000-0000-0000-000000000001';
      }
      
      // 确保必需字段存在
      final completeData = {
        ...dogData,
        'dog_id': dogData['dog_id'] ?? 'dog-${DateTime.now().millisecondsSinceEpoch}',
        'created_by': dogData['created_by'] ?? currentUserId,
        'created_at': dogData['created_at'] ?? DateTime.now().toIso8601String(),
      };
      
      final dog = Dog.fromMap(completeData);
      final newDog = await _dogService.createDog(dog);
      if (newDog != null) {
        _dogs.add(newDog);
        await LocalStorageService.cacheDogs(_dogs);
        notifyListeners();
        return newDog.dogId;
      }
      throw Exception('创建狗狗失败');
    } catch (e) {
      _setError('添加狗狗失败: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateDog(String dogId, Map<String, dynamic> dogData) async {
    _setLoading(true);
    _clearError();
    
    try {
      // 获取现有狗狗信息以保留必需字段
      final existingDog = _dogs.firstWhere((d) => d.dogId == dogId);
      
      final completeData = {
        ...dogData,
        'dog_id': dogId,
        'created_by': dogData['created_by'] ?? existingDog.createdBy,
        'created_at': dogData['created_at'] ?? existingDog.createdAt.toIso8601String(),
      };
      
      final dog = Dog.fromMap(completeData);
      final updatedDog = await _dogService.updateDog(dog);
      if (updatedDog != null) {
        final index = _dogs.indexWhere((d) => d.dogId == dogId);
        if (index != -1) {
          _dogs[index] = updatedDog;
          await LocalStorageService.cacheDogs(_dogs);
          notifyListeners();
          return true;
        }
      }
      return false;
    } catch (e) {
      _setError('更新狗狗信息失败: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteDog(String dogId) async {
    _setLoading(true);
    _clearError();
    
    try {
      final success = await _dogService.deleteDog(dogId);
      if (success) {
        _dogs.removeWhere((dog) => dog.dogId == dogId);
        await LocalStorageService.cacheDogs(_dogs);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _setError('删除狗狗失败: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> uploadDogImage(String dogId, dynamic imageFile) async {
    _setLoading(true);
    _clearError();
    
    try {
      final imageUrls = await _dogService.uploadDogImages(dogId, [imageFile.path]);
      if (imageUrls.isNotEmpty) {
        final dogIndex = _dogs.indexWhere((dog) => dog.dogId == dogId);
        if (dogIndex != -1) {
          final updatedDog = _dogs[dogIndex].copyWith(
            imageUrls: [..._dogs[dogIndex].imageUrls, ...imageUrls],
          );
          _dogs[dogIndex] = updatedDog;
          await LocalStorageService.cacheDogs(_dogs);
          notifyListeners();
          return true;
        }
      }
      return false;
    } catch (e) {
      _setError('上传图片失败: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> uploadDogImages(String dogId, List<String> imagePaths) async {
    _setLoading(true);
    _clearError();
    
    try {
      final imageUrls = await _dogService.uploadDogImages(dogId, imagePaths);
      if (imageUrls.isNotEmpty) {
        final dogIndex = _dogs.indexWhere((dog) => dog.dogId == dogId);
        if (dogIndex != -1) {
          final updatedDog = _dogs[dogIndex].copyWith(
            imageUrls: [..._dogs[dogIndex].imageUrls, ...imageUrls],
          );
          _dogs[dogIndex] = updatedDog;
          await LocalStorageService.cacheDogs(_dogs);
          notifyListeners();
          return true;
        }
      }
      return false;
    } catch (e) {
      _setError('上传图片失败: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteDogImage(String dogId, String imageUrl) async {
    _setLoading(true);
    _clearError();
    
    try {
      final success = await _dogService.deleteDogImage(dogId, imageUrl);
      if (success) {
        final dogIndex = _dogs.indexWhere((dog) => dog.dogId == dogId);
        if (dogIndex != -1) {
          final updatedImageUrls = _dogs[dogIndex].imageUrls
              .where((url) => url != imageUrl)
              .toList();
          final updatedDog = _dogs[dogIndex].copyWith(imageUrls: updatedImageUrls);
          _dogs[dogIndex] = updatedDog;
          await LocalStorageService.cacheDogs(_dogs);
          notifyListeners();
          return true;
        }
      }
      return false;
    } catch (e) {
      _setError('删除图片失败: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<Dog?> getDogById(String dogId) async {
    try {
      return _dogs.firstWhere((dog) => dog.dogId == dogId);
    } catch (e) {
      return null;
    }
  }

  void setStatusFilter(DogStatus? status) {
    _statusFilter = status;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearFilters() {
    _statusFilter = null;
    _searchQuery = '';
    notifyListeners();
  }

  List<Dog> _getFilteredDogs() {
    var filtered = _dogs;
    
    // Apply status filter
    if (_statusFilter != null) {
      filtered = filtered.where((dog) => dog.status == _statusFilter).toList();
    }
    
    // Apply search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((dog) {
        return dog.name.toLowerCase().contains(query) ||
               (dog.breed?.toLowerCase().contains(query) ?? false) ||
               dog.dogId.toLowerCase().contains(query);
      }).toList();
    }
    
    // Sort by creation date (newest first)
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    return filtered;
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _clearError();
  }

  // Method versions of getters for compatibility
  List<Dog> getAvailableDogs() {
    return _dogs.where((dog) => dog.status == DogStatus.available).toList();
  }

  List<Dog> getSoldDogs() {
    return _dogs.where((dog) => dog.status == DogStatus.sold).toList();
  }

  double getTotalProfit() {
    return _dogs
        .where((dog) => dog.currentProfit != null)
        .fold(0.0, (sum, dog) => sum + dog.currentProfit!);
  }

  double getTotalInvestment() {
    return _dogs
        .where((dog) => dog.purchasePrice != null)
        .fold(0.0, (sum, dog) => sum + dog.purchasePrice!);
  }

  double getTotalRevenue() {
    return _dogs
        .where((dog) => dog.salePrice != null)
        .fold(0.0, (sum, dog) => sum + dog.salePrice!);
  }
}