import 'package:uuid/uuid.dart';

enum DogStatus { available, sold }

enum DogSex { male, female }

class Dog {
  final String dogId;
  final String name;
  final DateTime? dateOfBirth;
  final String? breed;
  final double? weight;
  final DogSex? sex;
  final String? description;
  final double? purchasePrice;
  final double? salePrice;
  final DogStatus status;
  final String createdBy;
  final DateTime createdAt;
  final List<String> imageUrls;
  final double? currentProfit;

  Dog({
    required this.dogId,
    required this.name,
    this.dateOfBirth,
    this.breed,
    this.weight,
    this.sex,
    this.description,
    this.purchasePrice,
    this.salePrice,
    this.status = DogStatus.available,
    required this.createdBy,
    required this.createdAt,
    this.imageUrls = const [],
    this.currentProfit,
  });

  factory Dog.create({
    required String name,
    DateTime? dateOfBirth,
    String? breed,
    double? weight,
    DogSex? sex,
    String? description,
    double? purchasePrice,
    required String createdBy,
    String? customPrefix,
  }) {
    const uuid = Uuid();
    final id = customPrefix != null 
        ? '$customPrefix${uuid.v4().substring(0, 8)}'
        : uuid.v4();
    
    return Dog(
      dogId: id,
      name: name,
      dateOfBirth: dateOfBirth,
      breed: breed,
      weight: weight,
      sex: sex,
      description: description,
      purchasePrice: purchasePrice,
      createdBy: createdBy,
      createdAt: DateTime.now(),
    );
  }

  factory Dog.fromJson(Map<String, dynamic> json) {
    try {
      return Dog(
        dogId: json['dog_id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        dateOfBirth: json['dob'] != null 
            ? (json['dob'] is String ? DateTime.parse(json['dob']) : null)
            : (json['date_of_birth'] != null 
                ? DateTime.parse(json['date_of_birth'].toString()) 
                : null),
        breed: json['breed']?.toString(),
        weight: json['weight'] != null ? double.tryParse(json['weight'].toString()) : null,
        sex: json['sex'] != null ? _parseSex(json['sex'].toString()) : null,
        description: json['description']?.toString(),
        purchasePrice: json['purchase_price'] != null 
            ? double.tryParse(json['purchase_price'].toString()) : null,
        salePrice: json['sale_price'] != null 
            ? double.tryParse(json['sale_price'].toString()) : null,
        status: _parseStatus(json['status']?.toString()),
        createdBy: json['created_by']?.toString() ?? '00000000-0000-0000-0000-000000000001',
        createdAt: json['created_at'] != null 
            ? DateTime.parse(json['created_at'].toString()) 
            : DateTime.now(),
        imageUrls: _parseImageUrls(json['image_urls']),
        currentProfit: json['current_profit'] != null 
            ? double.tryParse(json['current_profit'].toString()) : null,
      );
    } catch (e) {
      print('Error parsing Dog from JSON: $e');
      // Return a default Dog object if parsing fails
      return Dog(
        dogId: json['dog_id']?.toString() ?? 'unknown-${DateTime.now().millisecondsSinceEpoch}',
        name: json['name']?.toString() ?? '未知狗狗',
        createdBy: '00000000-0000-0000-0000-000000000001',
        createdAt: DateTime.now(),
      );
    }
  }
  
  static DogSex? _parseSex(String? sexString) {
    if (sexString == null) return null;
    switch (sexString.toLowerCase()) {
      case 'male':
        return DogSex.male;
      case 'female':
        return DogSex.female;
      default:
        return null;
    }
  }
  
  static DogStatus _parseStatus(String? statusString) {
    if (statusString == null) return DogStatus.available;
    switch (statusString.toLowerCase()) {
      case 'sold':
        return DogStatus.sold;
      case 'available':
        return DogStatus.available;
      default:
        return DogStatus.available;
    }
  }
  
  static List<String> _parseImageUrls(dynamic imageUrls) {
    if (imageUrls == null) return [];
    if (imageUrls is List) {
      return imageUrls.map((e) => e.toString()).toList();
    }
    return [];
  }

  factory Dog.fromMap(Map<String, dynamic> map) => Dog.fromJson(map);

  Map<String, dynamic> toJson() {
    return {
      'dog_id': dogId,
      'name': name,
      'date_of_birth': dateOfBirth?.toIso8601String(),  // 修复：使用正确的数据库字段名
      'breed': breed,
      'weight': weight,
      'sex': sex?.name,
      'description': description,
      'purchase_price': purchasePrice,
      'sale_price': salePrice,
      'status': status.name,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Dog copyWith({
    String? dogId,
    String? name,
    DateTime? dateOfBirth,
    String? breed,
    double? weight,
    DogSex? sex,
    String? description,
    double? purchasePrice,
    double? salePrice,
    DogStatus? status,
    String? createdBy,
    DateTime? createdAt,
    List<String>? imageUrls,
    double? currentProfit,
  }) {
    return Dog(
      dogId: dogId ?? this.dogId,
      name: name ?? this.name,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      breed: breed ?? this.breed,
      weight: weight ?? this.weight,
      sex: sex ?? this.sex,
      description: description ?? this.description,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      salePrice: salePrice ?? this.salePrice,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      imageUrls: imageUrls ?? this.imageUrls,
      currentProfit: currentProfit ?? this.currentProfit,
    );
  }

  int get ageInDays {
    if (dateOfBirth == null) return 0;
    return DateTime.now().difference(dateOfBirth!).inDays;
  }

  String get ageString {
    if (dateOfBirth == null) return '未知';
    final days = ageInDays;
    if (days < 30) {
      return '$days天';
    } else if (days < 365) {
      return '${(days / 30).floor()}个月';
    } else {
      return '${(days / 365).floor()}岁';
    }
  }

  // Add ageText getter for compatibility
  String get ageText => ageString;

  bool get isPuppy => ageInDays < 365;
  
  String get statusText {
    switch (status) {
      case DogStatus.available:
        return '在售';
      case DogStatus.sold:
        return '已售';
    }
  }

  String get sexText {
    switch (sex) {
      case DogSex.male:
        return '公';
      case DogSex.female:
        return '母';
      case null:
        return '未知';
    }
  }
}