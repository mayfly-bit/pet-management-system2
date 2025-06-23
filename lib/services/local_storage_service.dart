import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/dog.dart';
import '../models/expense.dart';
import '../models/user.dart';

class LocalStorageService {
  static SharedPreferences? _prefs;
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // Keys for different data types
  static const String _dogsKey = 'cached_dogs';
  static const String _expensesKey = 'cached_expenses';
  static const String _categoriesKey = 'cached_categories';
  static const String _userKey = 'cached_user';
  static const String _lastSyncKey = 'last_sync_time';
  static const String _authTokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userCredentialsKey = 'user_credentials';

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static SharedPreferences get prefs {
    if (_prefs == null) {
      throw Exception('LocalStorageService not initialized. Call init() first.');
    }
    return _prefs!;
  }

  // Dogs caching
  static Future<void> cacheDogs(List<Dog> dogs) async {
    try {
      final dogsJson = dogs.map((dog) => dog.toJson()).toList();
      await prefs.setString(_dogsKey, jsonEncode(dogsJson));
      await _updateLastSyncTime();
    } catch (e) {
      print('Error caching dogs: $e');
    }
  }

  static Future<List<Dog>> getCachedDogs() async {
    try {
      final dogsString = prefs.getString(_dogsKey);
      if (dogsString == null) return [];
      
      final dogsJson = jsonDecode(dogsString) as List<dynamic>;
      return dogsJson.map((dogJson) => Dog.fromJson(dogJson)).toList();
    } catch (e) {
      print('Error getting cached dogs: $e');
      return [];
    }
  }

  // Expenses caching
  static Future<void> cacheExpenses(List<Expense> expenses) async {
    try {
      final expensesJson = expenses.map((expense) => expense.toJson()).toList();
      await prefs.setString(_expensesKey, jsonEncode(expensesJson));
      await _updateLastSyncTime();
    } catch (e) {
      print('Error caching expenses: $e');
    }
  }

  static Future<List<Expense>> getCachedExpenses() async {
    try {
      final expensesString = prefs.getString(_expensesKey);
      if (expensesString == null) return [];
      
      final expensesJson = jsonDecode(expensesString) as List<dynamic>;
      return expensesJson.map((expenseJson) => Expense.fromJson(expenseJson)).toList();
    } catch (e) {
      print('Error getting cached expenses: $e');
      return [];
    }
  }

  // Categories caching
  static Future<void> cacheCategories(List<ExpenseCategory> categories) async {
    try {
      final categoriesJson = categories.map((category) => category.toJson()).toList();
      await prefs.setString(_categoriesKey, jsonEncode(categoriesJson));
      await _updateLastSyncTime();
    } catch (e) {
      print('Error caching categories: $e');
    }
  }

  static Future<List<ExpenseCategory>> getCachedCategories() async {
    try {
      final categoriesString = prefs.getString(_categoriesKey);
      if (categoriesString == null) return [];
      
      final categoriesJson = jsonDecode(categoriesString) as List<dynamic>;
      return categoriesJson.map((categoryJson) => ExpenseCategory.fromJson(categoryJson)).toList();
    } catch (e) {
      print('Error getting cached categories: $e');
      return [];
    }
  }

  // User caching
  static Future<void> cacheUser(AppUser user) async {
    try {
      await prefs.setString(_userKey, jsonEncode(user.toJson()));
    } catch (e) {
      print('Error caching user: $e');
    }
  }

  static Future<AppUser?> getCachedUser() async {
    try {
      final userString = prefs.getString(_userKey);
      if (userString == null) return null;
      
      final userJson = jsonDecode(userString) as Map<String, dynamic>;
      return AppUser.fromJson(userJson);
    } catch (e) {
      print('Error getting cached user: $e');
      return null;
    }
  }

  // Secure storage for sensitive data
  static Future<void> storeAuthToken(String token) async {
    try {
      await _secureStorage.write(key: _authTokenKey, value: token);
    } catch (e) {
      print('Error storing auth token: $e');
    }
  }

  static Future<String?> getAuthToken() async {
    try {
      return await _secureStorage.read(key: _authTokenKey);
    } catch (e) {
      print('Error getting auth token: $e');
      return null;
    }
  }

  static Future<void> storeRefreshToken(String token) async {
    try {
      await _secureStorage.write(key: _refreshTokenKey, value: token);
    } catch (e) {
      print('Error storing refresh token: $e');
    }
  }

  static Future<String?> getRefreshToken() async {
    try {
      return await _secureStorage.read(key: _refreshTokenKey);
    } catch (e) {
      print('Error getting refresh token: $e');
      return null;
    }
  }

  static Future<void> storeUserCredentials(String email, String password) async {
    try {
      final credentials = {
        'email': email,
        'password': password,
      };
      await _secureStorage.write(
        key: _userCredentialsKey, 
        value: jsonEncode(credentials),
      );
    } catch (e) {
      print('Error storing user credentials: $e');
    }
  }

  static Future<Map<String, String>?> getUserCredentials() async {
    try {
      final credentialsString = await _secureStorage.read(key: _userCredentialsKey);
      if (credentialsString == null) return null;
      
      final credentials = jsonDecode(credentialsString) as Map<String, dynamic>;
      return {
        'email': credentials['email'] as String,
        'password': credentials['password'] as String,
      };
    } catch (e) {
      print('Error getting user credentials: $e');
      return null;
    }
  }

  // Sync management
  static Future<void> _updateLastSyncTime() async {
    try {
      await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
    } catch (e) {
      print('Error updating last sync time: $e');
    }
  }

  static Future<DateTime?> getLastSyncTime() async {
    try {
      final syncTimeString = prefs.getString(_lastSyncKey);
      if (syncTimeString == null) return null;
      
      return DateTime.parse(syncTimeString);
    } catch (e) {
      print('Error getting last sync time: $e');
      return null;
    }
  }

  static Future<bool> needsSync({Duration threshold = const Duration(minutes: 30)}) async {
    final lastSync = await getLastSyncTime();
    if (lastSync == null) return true;
    
    return DateTime.now().difference(lastSync) > threshold;
  }

  // App settings
  static Future<void> setBool(String key, bool value) async {
    await prefs.setBool(key, value);
  }

  static bool getBool(String key, {bool defaultValue = false}) {
    return prefs.getBool(key) ?? defaultValue;
  }

  static Future<void> setString(String key, String value) async {
    await prefs.setString(key, value);
  }

  static String getString(String key, {String defaultValue = ''}) {
    return prefs.getString(key) ?? defaultValue;
  }

  static Future<void> setInt(String key, int value) async {
    await prefs.setInt(key, value);
  }

  static int getInt(String key, {int defaultValue = 0}) {
    return prefs.getInt(key) ?? defaultValue;
  }

  static Future<void> setDouble(String key, double value) async {
    await prefs.setDouble(key, value);
  }

  static double getDouble(String key, {double defaultValue = 0.0}) {
    return prefs.getDouble(key) ?? defaultValue;
  }

  // Clear methods
  static Future<void> clearCache() async {
    try {
      await prefs.remove(_dogsKey);
      await prefs.remove(_expensesKey);
      await prefs.remove(_categoriesKey);
      await prefs.remove(_userKey);
      await prefs.remove(_lastSyncKey);
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }

  static Future<void> clearCachedData() async {
    await clearCache();
  }

  static Future<void> clearSecureStorage() async {
    try {
      await _secureStorage.delete(key: _authTokenKey);
      await _secureStorage.delete(key: _refreshTokenKey);
      await _secureStorage.delete(key: _userCredentialsKey);
    } catch (e) {
      print('Error clearing secure storage: $e');
    }
  }

  static Future<void> clearAll() async {
    await clearCache();
    await clearSecureStorage();
    await prefs.clear();
  }

  // Backup and restore
  static Future<Map<String, dynamic>> exportData() async {
    try {
      final dogs = await getCachedDogs();
      final expenses = await getCachedExpenses();
      final categories = await getCachedCategories();
      final user = await getCachedUser();
      
      return {
        'dogs': dogs.map((dog) => dog.toJson()).toList(),
        'expenses': expenses.map((expense) => expense.toJson()).toList(),
        'categories': categories.map((category) => category.toJson()).toList(),
        'user': user?.toJson(),
        'exported_at': DateTime.now().toIso8601String(),
        'version': '1.0.0',
      };
    } catch (e) {
      throw Exception('导出数据失败: $e');
    }
  }

  static Future<void> importData(Map<String, dynamic> data) async {
    try {
      // Validate data structure
      if (!data.containsKey('version')) {
        throw Exception('无效的数据格式');
      }
      
      // Import dogs
      if (data.containsKey('dogs')) {
        final dogsData = data['dogs'] as List<dynamic>;
        final dogs = dogsData.map((dogJson) => Dog.fromJson(dogJson)).toList();
        await cacheDogs(dogs);
      }
      
      // Import expenses
      if (data.containsKey('expenses')) {
        final expensesData = data['expenses'] as List<dynamic>;
        final expenses = expensesData.map((expenseJson) => Expense.fromJson(expenseJson)).toList();
        await cacheExpenses(expenses);
      }
      
      // Import categories
      if (data.containsKey('categories')) {
        final categoriesData = data['categories'] as List<dynamic>;
        final categories = categoriesData.map((categoryJson) => ExpenseCategory.fromJson(categoryJson)).toList();
        await cacheCategories(categories);
      }
      
      // Import user
      if (data.containsKey('user') && data['user'] != null) {
        final user = AppUser.fromJson(data['user']);
        await cacheUser(user);
      }
      
    } catch (e) {
      throw Exception('导入数据失败: $e');
    }
  }
}