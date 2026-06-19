import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model representing a roommate expense sharing group (Firestore-backed).
class GroupModel {
  final String id;
  final String groupName;
  final String groupType;
  final String groupIcon;
  final String createdBy;
  final List<String> members;
  final int memberCount;
  final double balance;
  final String currency;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  GroupModel({
    required this.id,
    required this.groupName,
    required this.groupType,
    required this.groupIcon,
    required this.createdBy,
    required this.members,
    required this.memberCount,
    required this.balance,
    this.currency = 'INR',
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  // Legacy compat — UI code that reads g.name still works
  String get name => groupName;
  String get imageUrl => groupIcon;
  String get lastActivity => 'Created ${_relativeTime(createdAt)}';

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  factory GroupModel.fromMap(Map<String, dynamic> map, String docId) {
    return GroupModel(
      id: docId,
      groupName: map['groupName'] as String? ?? '',
      groupType: map['groupType'] as String? ?? '',
      groupIcon: map['groupIcon'] as String? ?? '👥',
      createdBy: map['createdBy'] as String? ?? '',
      members: List<String>.from(map['members'] as List? ?? []),
      memberCount: (map['memberCount'] as num?)?.toInt() ?? 1,
      balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] as String? ?? 'INR',
      isArchived: map['isArchived'] as bool? ?? false,
      createdAt:
          (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:
          (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupName': groupName,
      'groupType': groupType,
      'groupIcon': groupIcon,
      'createdBy': createdBy,
      'members': members,
      'memberCount': memberCount,
      'balance': balance,
      'currency': currency,
      'isArchived': isArchived,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  GroupModel copyWith({
    String? groupName,
    String? groupType,
    String? groupIcon,
    List<String>? members,
    int? memberCount,
    double? balance,
    bool? isArchived,
  }) {
    return GroupModel(
      id: id,
      groupName: groupName ?? this.groupName,
      groupType: groupType ?? this.groupType,
      groupIcon: groupIcon ?? this.groupIcon,
      createdBy: createdBy,
      members: members ?? this.members,
      memberCount: memberCount ?? this.memberCount,
      balance: balance ?? this.balance,
      currency: currency,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

/// Defines available group types with their display properties.
class GroupTypeOption {
  final String type;
  final String icon;
  final String label;

  const GroupTypeOption({
    required this.type,
    required this.icon,
    required this.label,
  });

  static const List<GroupTypeOption> all = [
    GroupTypeOption(type: 'Home', icon: '🏠', label: 'Home'),
    GroupTypeOption(type: 'Trip', icon: '✈️', label: 'Trip'),
    GroupTypeOption(type: 'Couple', icon: '❤️', label: 'Couple'),
    GroupTypeOption(type: 'Personal', icon: '👤', label: 'Personal'),
    GroupTypeOption(type: 'Business', icon: '💼', label: 'Business'),
    GroupTypeOption(type: 'Office', icon: '💻', label: 'Office'),
    GroupTypeOption(type: 'Sports', icon: '🏆', label: 'Sports'),
    GroupTypeOption(type: 'Others', icon: '👥', label: 'Others'),
  ];
}
