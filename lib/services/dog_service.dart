import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../models/dog.dart';
import '../config/supabase_config.dart';
import 'local_storage_service.dart';

class DogService {
  final SupabaseClient _client = Supabase.instance.client;

  /// 检查是否在演示模式
  bool _isInDemoMode() {
    try {
      return SupabaseConfig.url.isEmpty || 
             SupabaseConfig.url.contains('demo.supabase.co');
    } catch (e) {
      return true; // 如果无法访问，假设是演示模式
    }
  }

  Future<List<Dog>> getAllDogs() async {
    try {
      if (_isInDemoMode()) {
        // 演示模式：从本地存储获取数据
        return await LocalStorageService.getCachedDogs();
      }

      // 简化查询，先不查询图片关联数据
      final response = await _client
          .from(SupabaseConfig.dogsTable)
          .select('*')
          .order('created_at', ascending: false);
      
      return (response as List).map((dogData) {
        return Dog.fromJson(dogData);
      }).toList();
    } catch (e) {
      throw Exception('获取狗狗列表失败: $e');
    }
  }

  Future<Dog?> getDogById(String dogId) async {
    try {
      if (_isInDemoMode()) {
        // 演示模式：从本地存储查找
        final dogs = await LocalStorageService.getCachedDogs();
        try {
          return dogs.firstWhere((dog) => dog.dogId == dogId);
        } catch (e) {
          return null; // 未找到
        }
      }

      // 简化查询，先不查询图片关联数据
      final response = await _client
          .from(SupabaseConfig.dogsTable)
          .select('*')
          .eq('dog_id', dogId)
          .single();
      
      return Dog.fromJson(response);
    } catch (e) {
      throw Exception('获取狗狗信息失败: $e');
    }
  }

  Future<Dog?> createDog(Dog dog) async {
    try {
      if (_isInDemoMode()) {
        // 演示模式：保存到本地存储
        final dogs = await LocalStorageService.getCachedDogs();
        
        // 生成新的ID
        final newDog = dog.copyWith(
          dogId: 'demo-dog-${DateTime.now().millisecondsSinceEpoch}',
          createdAt: DateTime.now(),
        );
        
        dogs.add(newDog);
        await LocalStorageService.cacheDogs(dogs);
        return newDog;
      }

      final response = await _client
          .from(SupabaseConfig.dogsTable)
          .insert(dog.toJson())
          .select()
          .single();
      
      return Dog.fromJson(response);
    } catch (e) {
      throw Exception('创建狗狗记录失败: $e');
    }
  }

  Future<Dog?> updateDog(Dog dog) async {
    try {
      if (_isInDemoMode()) {
        // 演示模式：更新本地存储
        final dogs = await LocalStorageService.getCachedDogs();
        final index = dogs.indexWhere((d) => d.dogId == dog.dogId);
        
        if (index == -1) {
          throw Exception('未找到要更新的狗狗记录');
        }
        
        dogs[index] = dog;
        await LocalStorageService.cacheDogs(dogs);
        return dog;
      }

      final response = await _client
          .from(SupabaseConfig.dogsTable)
          .update(dog.toJson())
          .eq('dog_id', dog.dogId)
          .select()
          .single();
      
      return Dog.fromJson(response);
    } catch (e) {
      throw Exception('更新狗狗信息失败: $e');
    }
  }

  Future<bool> deleteDog(String dogId) async {
    try {
      if (_isInDemoMode()) {
        // 演示模式：从本地存储删除
        final dogs = await LocalStorageService.getCachedDogs();
        dogs.removeWhere((dog) => dog.dogId == dogId);
        await LocalStorageService.cacheDogs(dogs);
        return true;
      }

      // First delete all associated images
      await _deleteAllDogImages(dogId);
      
      // Then delete the dog record
      await _client
          .from(SupabaseConfig.dogsTable)
          .delete()
          .eq('dog_id', dogId);
      
      return true;
    } catch (e) {
      throw Exception('删除狗狗记录失败: $e');
    }
  }

  Future<List<String>> uploadDogImages(String dogId, List<String> imagePaths) async {
    try {
      if (_isInDemoMode()) {
        // 演示模式：模拟图片上传
        final List<String> uploadedUrls = [];
        for (int i = 0; i < imagePaths.length; i++) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final mockUrl = 'demo://image/${dogId}_${timestamp}_$i.jpg';
          uploadedUrls.add(mockUrl);
        }
        return uploadedUrls;
      }

      final List<String> uploadedUrls = [];
      
      for (int i = 0; i < imagePaths.length; i++) {
        final imagePath = imagePaths[i];
        final file = File(imagePath);
        
        if (!await file.exists()) {
          continue;
        }
        
        // Compress image
        final compressedFile = await _compressImage(file);
        
        // Generate unique filename
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = '${dogId}_${timestamp}_$i.jpg';
        
        // Upload to Supabase Storage
        final uploadPath = await _client.storage
            .from(SupabaseConfig.dogImagesBucket)
            .upload(fileName, compressedFile);
        
        // Get public URL
        final publicUrl = _client.storage
            .from(SupabaseConfig.dogImagesBucket)
            .getPublicUrl(fileName);
        
        // Save image record to database
        await _client.from(SupabaseConfig.dogImagesTable).insert({
          'dog_id': dogId,
          'image_url': publicUrl,
          'uploaded_at': DateTime.now().toIso8601String(),
        });
        
        uploadedUrls.add(publicUrl);
        
        // Clean up compressed file
        await compressedFile.delete();
      }
      
      return uploadedUrls;
    } catch (e) {
      throw Exception('上传图片失败: $e');
    }
  }

  Future<bool> deleteDogImage(String dogId, String imageUrl) async {
    try {
      if (_isInDemoMode()) {
        // 演示模式：模拟删除成功
        return true;
      }

      // Extract filename from URL
      final uri = Uri.parse(imageUrl);
      final fileName = uri.pathSegments.last;
      
      // Delete from storage
      await _client.storage
          .from(SupabaseConfig.dogImagesBucket)
          .remove([fileName]);
      
      // Delete from database
      await _client
          .from(SupabaseConfig.dogImagesTable)
          .delete()
          .eq('dog_id', dogId)
          .eq('image_url', imageUrl);
      
      return true;
    } catch (e) {
      throw Exception('删除图片失败: $e');
    }
  }

  Future<void> _deleteAllDogImages(String dogId) async {
    try {
      // Get all image records for this dog
      final imageRecords = await _client
          .from(SupabaseConfig.dogImagesTable)
          .select('image_url')
          .eq('dog_id', dogId);
      
      // Delete from storage
      final fileNames = (imageRecords as List).map((record) {
        final uri = Uri.parse(record['image_url'] as String);
        return uri.pathSegments.last;
      }).toList();
      
      if (fileNames.isNotEmpty) {
        await _client.storage
            .from(SupabaseConfig.dogImagesBucket)
            .remove(fileNames);
      }
      
      // Delete from database
      await _client
          .from(SupabaseConfig.dogImagesTable)
          .delete()
          .eq('dog_id', dogId);
    } catch (e) {
      // Log error but don't throw, as this is cleanup
      print('清理图片失败: $e');
    }
  }

  Future<File> _compressImage(File file) async {
    try {
      // Read the image
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        throw Exception('无法解码图片');
      }
      
      // Resize if too large (max 1920x1920)
      img.Image resized = image;
      if (image.width > 1920 || image.height > 1920) {
        resized = img.copyResize(
          image,
          width: image.width > image.height ? 1920 : null,
          height: image.height > image.width ? 1920 : null,
        );
      }
      
      // Compress as JPEG with 85% quality
      final compressedBytes = img.encodeJpg(resized, quality: 85);
      
      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(compressedBytes);
      
      return tempFile;
    } catch (e) {
      throw Exception('压缩图片失败: $e');
    }
  }

  Future<List<Dog>> searchDogs({
    String? query,
    DogStatus? status,
    String? breed,
    bool? isPuppy,
  }) async {
    try {
      if (_isInDemoMode()) {
        // 演示模式：从本地存储搜索
        var dogs = await LocalStorageService.getCachedDogs();
        
        // 应用过滤条件
        if (status != null) {
          dogs = dogs.where((dog) => dog.status == status).toList();
        }
        
        if (breed != null && breed.isNotEmpty) {
          dogs = dogs.where((dog) => 
            dog.breed?.toLowerCase().contains(breed.toLowerCase()) == true
          ).toList();
        }
        
        if (query != null && query.isNotEmpty) {
          dogs = dogs.where((dog) => 
            dog.name.toLowerCase().contains(query.toLowerCase()) ||
            dog.dogId.toLowerCase().contains(query.toLowerCase()) ||
            (dog.breed?.toLowerCase().contains(query.toLowerCase()) == true)
          ).toList();
        }
        
        if (isPuppy != null) {
          dogs = dogs.where((dog) => dog.isPuppy == isPuppy).toList();
        }
        
        return dogs;
      }

      var queryBuilder = _client
          .from(SupabaseConfig.dogsTable)
          .select('*');
      
      if (status != null) {
        queryBuilder = queryBuilder.eq('status', status.name);
      }
      
      if (breed != null && breed.isNotEmpty) {
        queryBuilder = queryBuilder.ilike('breed', '%$breed%');
      }
      
      if (query != null && query.isNotEmpty) {
        queryBuilder = queryBuilder.or(
          'name.ilike.%$query%,dog_id.ilike.%$query%,breed.ilike.%$query%'
        );
      }
      
      final response = await queryBuilder.order('created_at', ascending: false);
      
      var dogs = (response as List).map((dogData) {
        return Dog.fromJson(dogData);
      }).toList();
      
      // Filter by age if needed (client-side filtering)
      if (isPuppy != null) {
        dogs = dogs.where((dog) => dog.isPuppy == isPuppy).toList();
      }
      
      return dogs;
    } catch (e) {
      throw Exception('搜索狗狗失败: $e');
    }
  }

  Future<Map<String, dynamic>> getDogProfitSummary(String dogId) async {
    try {
      if (_isInDemoMode()) {
        // 演示模式：返回模拟数据
        final dog = await getDogById(dogId);
        if (dog == null) {
          throw Exception('未找到狗狗记录');
        }
        
        return {
          'dog_id': dogId,
          'total_expenses': 500.0, // 模拟总费用
          'net_profit': (dog.salePrice ?? 0) - (dog.purchasePrice ?? 0) - 500.0,
          'profit_margin': dog.salePrice != null 
            ? ((dog.salePrice! - (dog.purchasePrice ?? 0) - 500.0) / dog.salePrice! * 100)
            : 0.0,
        };
      }

      final response = await _client
          .from(SupabaseConfig.dogProfitView)
          .select()
          .eq('dog_id', dogId)
          .single();
      
      return response;
    } catch (e) {
      throw Exception('获取狗狗利润汇总失败: $e');
    }
  }
}