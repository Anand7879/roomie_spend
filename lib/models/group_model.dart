/// Data model representing a roommate expense sharing group.
class GroupModel {
  final String id;
  final String name;
  final String imageUrl;
  final int memberCount;
  final String lastActivity;
  final double balance; // positive means they owe you, negative means you owe them, zero is settled

  GroupModel({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.memberCount,
    required this.lastActivity,
    required this.balance,
  });

  /// Maps a Firestore document map back into GroupModel object (if needed in the future)
  factory GroupModel.fromMap(Map<String, dynamic> map, String docId) {
    return GroupModel(
      id: docId,
      name: map['name'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      memberCount: map['memberCount'] ?? 0,
      lastActivity: map['lastActivity'] ?? '',
      balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Maps GroupModel to database write map
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'imageUrl': imageUrl,
      'memberCount': memberCount,
      'lastActivity': lastActivity,
      'balance': balance,
    };
  }
}
