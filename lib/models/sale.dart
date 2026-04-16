import 'package:hive/hive.dart';
part 'sale.g.dart';

@HiveType(typeId: 0)
class Sale extends HiveObject {
  @HiveField(0)
  String id;
  @HiveField(1)
  Map<String, dynamic> data;
  @HiveField(2)
  bool isSynced;
  @HiveField(3)
  String? syncError;
  @HiveField(4)
  DateTime createdAt;

  Sale({
    required this.id,
    required this.data,
    this.isSynced = false,
    this.syncError,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toFirestore() => data;

  factory Sale.fromMap(Map<String, dynamic> map) => Sale(
    id: map['id'],
    data: Map<String, dynamic>.from(map['data']),
    isSynced: map['isSynced'] ?? false,
    syncError: map['syncError'],
    createdAt: DateTime.parse(map['createdAt']),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'data': data,
    'isSynced': isSynced,
    'syncError': syncError,
    'createdAt': createdAt.toIso8601String(),
  };
}
