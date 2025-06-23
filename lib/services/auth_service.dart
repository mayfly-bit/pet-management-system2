import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user.dart';
import '../config/supabase_config.dart';

class AuthService {
  static final AuthService instance = AuthService._internal();
  
  AuthService._internal();
  
  factory AuthService() {
    return instance;
  }

  final SupabaseClient _client = Supabase.instance.client;

  Future<AuthResponse> signIn(String email, String password) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } catch (e) {
      throw Exception('登录失败: $e');
    }
  }

  Future<AuthResponse> signUp(String email, String password, {String? displayName}) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: displayName != null ? {'display_name': displayName} : null,
      );
      
      // Create user profile in our users table
      if (response.user != null) {
        await _createUserProfile(
          response.user!.id,
          email,
          displayName,
        );
      }
      
      return response;
    } catch (e) {
      throw Exception('注册失败: $e');
    }
  }

  Future<void> signInWithMagicLink(String email) async {
    try {
      await _client.auth.signInWithOtp(
        email: email,
        emailRedirectTo: 'io.supabase.petprofitmanager://login-callback/',
      );
    } catch (e) {
      throw Exception('发送魔法链接失败: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      throw Exception('登出失败: $e');
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'io.supabase.petprofitmanager://reset-password/',
      );
    } catch (e) {
      throw Exception('重置密码失败: $e');
    }
  }

  Future<void> updatePassword(String currentPassword, String newPassword) async {
    try {
      await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } catch (e) {
      throw Exception('修改密码失败: $e');
    }
  }

  Future<AppUser?> getUserProfile(String userId) async {
    try {
      final response = await _client
          .from(SupabaseConfig.usersTable)
          .select()
          .eq('id', userId)
          .single();
      
      return AppUser.fromJson(response);
    } catch (e) {
      throw Exception('获取用户资料失败: $e');
    }
  }

  Future<AppUser?> updateUserProfile(
    String userId, {
    String? displayName,
    String? avatarUrl,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (displayName != null) updateData['display_name'] = displayName;
      if (avatarUrl != null) updateData['avatar_url'] = avatarUrl;
      
      if (updateData.isEmpty) return null;
      
      final response = await _client
          .from(SupabaseConfig.usersTable)
          .update(updateData)
          .eq('id', userId)
          .select()
          .single();
      
      return AppUser.fromJson(response);
    } catch (e) {
      throw Exception('更新用户资料失败: $e');
    }
  }

  Future<void> _createUserProfile(
    String userId,
    String email,
    String? displayName,
  ) async {
    try {
      await _client.from(SupabaseConfig.usersTable).insert({
        'id': userId,
        'email': email,
        'display_name': displayName,
        'role': 'viewer', // Default role, owner should be set manually
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // If user already exists, ignore the error
      if (!e.toString().contains('duplicate key')) {
        throw Exception('创建用户资料失败: $e');
      }
    }
  }

  Future<bool> updateUserRole(String userId, UserRole role) async {
    try {
      await _client
          .from(SupabaseConfig.usersTable)
          .update({'role': role.name})
          .eq('id', userId);
      return true;
    } catch (e) {
      throw Exception('更新用户角色失败: $e');
    }
  }

  Future<List<AppUser>> getAllUsers() async {
    try {
      final response = await _client
          .from(SupabaseConfig.usersTable)
          .select()
          .order('created_at', ascending: false);
      
      return (response as List)
          .map((user) => AppUser.fromJson(user))
          .toList();
    } catch (e) {
      throw Exception('获取用户列表失败: $e');
    }
  }

  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;
  String get currentUserId => _client.auth.currentUser?.id ?? '00000000-0000-0000-0000-000000000001';
  
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
}