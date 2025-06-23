import 'package:uuid/uuid.dart';

class ExpenseCategory {
  final String catId;
  final String name;
  final bool isShared;

  ExpenseCategory({
    required this.catId,
    required this.name,
    required this.isShared,
  });

  // Add categoryId getter for compatibility
  String get categoryId => catId;

  factory ExpenseCategory.fromJson(Map<String, dynamic> json) {
    try {
      // 尝试获取ID字段，优先使用 cat_id，然后是 category_id
      String id = '';
      if (json['cat_id'] != null && json['cat_id'].toString().isNotEmpty) {
        id = json['cat_id'].toString();
      } else if (json['category_id'] != null && json['category_id'].toString().isNotEmpty) {
        id = json['category_id'].toString();
      } else {
        id = 'unknown-${DateTime.now().millisecondsSinceEpoch}';
      }
      
      return ExpenseCategory(
        catId: id,
        name: (json['name']?.toString() ?? '未知类别'),
        isShared: (json['is_shared'] == true || json['is_shared'] == 'true'),
      );
    } catch (e) {
      // 如果解析失败，返回一个默认的类别
      return ExpenseCategory(
        catId: 'error-${DateTime.now().millisecondsSinceEpoch}',
        name: '解析失败',
        isShared: false,
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'cat_id': catId, // 使用数据库中实际的字段名cat_id
      'name': name,
      'is_shared': isShared,
    };
  }
}

class Expense {
  final String expId;
  final String catId;
  final double amount;
  final DateTime date;
  final String? note;
  final String createdBy;
  final DateTime createdAt;
  final ExpenseCategory? category;
  final List<ExpenseDogLink> dogLinks;

  Expense({
    required this.expId,
    required this.catId,
    required this.amount,
    required this.date,
    this.note,
    required this.createdBy,
    required this.createdAt,
    this.category,
    this.dogLinks = const [],
  });

  factory Expense.create({
    required String catId,
    required double amount,
    required DateTime date,
    String? note,
    required String createdBy,
    required List<String> dogIds,
  }) {
    const uuid = Uuid();
    final expId = uuid.v4();
    
    // Create equal share ratio for all dogs
    final shareRatio = dogIds.isNotEmpty ? 1.0 / dogIds.length : 1.0;
    final dogLinks = dogIds.map((dogId) => ExpenseDogLink(
      expId: expId,
      dogId: dogId,
      shareRatio: shareRatio,
    )).toList();
    
    return Expense(
      expId: expId,
      catId: catId,
      amount: amount,
      date: date,
      note: note,
      createdBy: createdBy,
      createdAt: DateTime.now(),
      dogLinks: dogLinks,
    );
  }

  factory Expense.fromJson(Map<String, dynamic> json) {
    try {
      // 安全解析ID字段
      String expId = '';
      if (json['exp_id'] != null && json['exp_id'].toString().isNotEmpty) {
        expId = json['exp_id'].toString();
      } else if (json['expense_id'] != null && json['expense_id'].toString().isNotEmpty) {
        expId = json['expense_id'].toString();
      } else {
        expId = 'unknown-${DateTime.now().millisecondsSinceEpoch}';
      }
      
      // 安全解析类别ID
      String catId = '';
      if (json['cat_id'] != null && json['cat_id'].toString().isNotEmpty) {
        catId = json['cat_id'].toString();
      } else if (json['category_id'] != null && json['category_id'].toString().isNotEmpty) {
        catId = json['category_id'].toString();
      } else {
        catId = 'unknown-category';
      }
      
      // 安全解析金额
      double amount = 0.0;
      if (json['amount'] != null) {
        if (json['amount'] is num) {
          amount = (json['amount'] as num).toDouble();
        } else {
          amount = double.tryParse(json['amount'].toString()) ?? 0.0;
        }
      }
      
      // 安全解析日期
      DateTime date = DateTime.now();
      if (json['date'] != null && json['date'].toString().isNotEmpty) {
        try {
          date = DateTime.parse(json['date'].toString());
        } catch (e) {
          date = DateTime.now();
        }
      }
      
      // 安全解析创建时间
      DateTime createdAt = DateTime.now();
      if (json['created_at'] != null && json['created_at'].toString().isNotEmpty) {
        try {
          createdAt = DateTime.parse(json['created_at'].toString());
        } catch (e) {
          createdAt = DateTime.now();
        }
      }
      
      return Expense(
        expId: expId,
        catId: catId,
        amount: amount,
        date: date,
        note: json['note']?.toString(),
        createdBy: json['created_by']?.toString() ?? '00000000-0000-0000-0000-000000000001',
        createdAt: createdAt,
        category: json['category'] != null 
            ? ExpenseCategory.fromJson(json['category'])
            : null,
        dogLinks: (json['dog_links'] as List<dynamic>?)
            ?.map((link) => ExpenseDogLink.fromJson(link))
            .toList() ?? [],
      );
    } catch (e) {
      // 如果解析完全失败，返回一个默认对象
      return Expense(
        expId: 'error-${DateTime.now().millisecondsSinceEpoch}',
        catId: 'unknown',
        amount: 0.0,
        date: DateTime.now(),
        note: '解析失败: $e',
        createdBy: '00000000-0000-0000-0000-000000000001',
        createdAt: DateTime.now(),
      );
    }
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    const uuid = Uuid();
    final expId = uuid.v4();
    
    // 安全解析类别ID
    String catId = '';
    if (map['category_id'] != null && map['category_id'].toString().isNotEmpty) {
      catId = map['category_id'].toString();
    } else if (map['cat_id'] != null && map['cat_id'].toString().isNotEmpty) {
      catId = map['cat_id'].toString();
    } else {
      catId = 'unknown-category';
    }
    
    // 安全解析金额
    double amount = 0.0;
    if (map['amount'] != null) {
      if (map['amount'] is num) {
        amount = (map['amount'] as num).toDouble();
      } else {
        amount = double.tryParse(map['amount'].toString()) ?? 0.0;
      }
    }
    
    // 安全解析日期
    DateTime date = DateTime.now();
    if (map['date'] != null && map['date'].toString().isNotEmpty) {
      try {
        date = DateTime.parse(map['date'].toString());
      } catch (e) {
        date = DateTime.now();
      }
    }
    
    // 获取created_by字段，优先使用map中的值，否则使用默认值
    String createdBy = map['created_by']?.toString() ?? '00000000-0000-0000-0000-000000000001';
    
    // 创建dog links
    List<ExpenseDogLink> dogLinks = [];
    if (map['dog_links'] != null && map['dog_links'] is List) {
      dogLinks = (map['dog_links'] as List).map((linkData) {
        return ExpenseDogLink(
          expId: expId,
          dogId: linkData['dog_id']?.toString() ?? '',
          shareRatio: (linkData['share_ratio'] as num?)?.toDouble() ?? 0.0,
        );
      }).toList();
    }
    
    return Expense(
      expId: expId,
      catId: catId,
      amount: amount,
      date: date,
      note: map['note']?.toString(),
      createdBy: createdBy,
      createdAt: DateTime.now(),
      dogLinks: dogLinks,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'exp_id': expId,
      'cat_id': catId, // 使用数据库中实际的字段名cat_id
      'amount': amount,
      'date': date.toIso8601String(),
      'note': note,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }

  double getAmountForDog(String dogId) {
    final link = dogLinks.firstWhere(
      (link) => link.dogId == dogId,
      orElse: () => ExpenseDogLink(expId: expId, dogId: dogId, shareRatio: 0),
    );
    return amount * link.shareRatio;
  }

  List<String> get associatedDogIds {
    return dogLinks.map((link) => link.dogId).toList();
  }

  // Add copyWith method
  Expense copyWith({
    String? expId,
    String? catId,
    double? amount,
    DateTime? date,
    String? note,
    String? createdBy,
    DateTime? createdAt,
    ExpenseCategory? category,
    List<ExpenseDogLink>? dogLinks,
  }) {
    return Expense(
      expId: expId ?? this.expId,
      catId: catId ?? this.catId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      note: note ?? this.note,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      category: category ?? this.category,
      dogLinks: dogLinks ?? this.dogLinks,
    );
  }

  // Add getDogSpecificAmount method
  double getDogSpecificAmount(String dogId) {
    return getAmountForDog(dogId);
  }
}

class ExpenseDogLink {
  final String expId;
  final String dogId;
  final double shareRatio;

  ExpenseDogLink({
    required this.expId,
    required this.dogId,
    required this.shareRatio,
  });

  factory ExpenseDogLink.fromJson(Map<String, dynamic> json) {
    return ExpenseDogLink(
      expId: (json['exp_id'] ?? json['expense_id'] ?? '').toString(),
      dogId: json['dog_id']?.toString() ?? '',
      shareRatio: (json['share_ratio'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'exp_id': expId, // 使用数据库中实际的字段名exp_id
      'dog_id': dogId,
      'share_ratio': shareRatio,
    };
  }
}

// Predefined expense categories
class DefaultExpenseCategories {
  static List<Map<String, dynamic>> getCategoriesForUser(String userId) {
    return [
      {'cat_id': 'default-cat-001', 'name': '食物费用', 'is_shared': true, 'created_by': userId},
      {'cat_id': 'default-cat-002', 'name': '医疗费用', 'is_shared': true, 'created_by': userId},
      {'cat_id': 'default-cat-003', 'name': '美容费用', 'is_shared': true, 'created_by': userId},
      {'cat_id': 'default-cat-004', 'name': '用品费用', 'is_shared': true, 'created_by': userId},
      {'cat_id': 'default-cat-005', 'name': '训练费用', 'is_shared': true, 'created_by': userId},
      {'cat_id': 'default-cat-006', 'name': '其他费用', 'is_shared': true, 'created_by': userId},
    ];
  }
  
  // 保留向后兼容性
  static const List<Map<String, dynamic>> categories = [
    {'name': '医疗费用', 'is_shared': false},
    {'name': '食物用品', 'is_shared': true},
    {'name': '护理美容', 'is_shared': false},
    {'name': '训练费用', 'is_shared': false},
    {'name': '疫苗接种', 'is_shared': false},
    {'name': '玩具用品', 'is_shared': true},
    {'name': '住宿费用', 'is_shared': true},
    {'name': '运输费用', 'is_shared': true},
    {'name': '其他费用', 'is_shared': false},
  ];
}