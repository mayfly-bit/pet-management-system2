enum UserRole { owner, viewer }

class AppUser {
  final String id;
  final String email;
  final UserRole role;
  final DateTime createdAt;
  final String? displayName;
  final String? avatarUrl;

  AppUser({
    required this.id,
    required this.email,
    required this.role,
    required this.createdAt,
    this.displayName,
    this.avatarUrl,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      email: json['email'] as String,
      role: UserRole.values.byName(json['role'] ?? 'viewer'),
      createdAt: DateTime.parse(json['created_at']),
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'role': role.name,
      'created_at': createdAt.toIso8601String(),
      'display_name': displayName,
      'avatar_url': avatarUrl,
    };
  }

  AppUser copyWith({
    String? id,
    String? email,
    UserRole? role,
    DateTime? createdAt,
    String? displayName,
    String? avatarUrl,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  bool get isOwner => role == UserRole.owner;
  bool get isViewer => role == UserRole.viewer;
  
  String get roleText {
    switch (role) {
      case UserRole.owner:
        return '管理员';
      case UserRole.viewer:
        return '查看者';
    }
  }

  String get initials {
    if (displayName != null && displayName!.isNotEmpty) {
      return displayName!.substring(0, 1).toUpperCase();
    }
    return email.substring(0, 1).toUpperCase();
  }
}