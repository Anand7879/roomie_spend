import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/group_model.dart';
import '../models/expense_model.dart';

/// Handles all Firestore group, member, expense, and activity operations.
class GroupFirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _groups =>
      _db.collection('groups');
  CollectionReference<Map<String, dynamic>> get _activities =>
      _db.collection('activities');

  // ─── Groups ──────────────────────────────────────────────────────────────

  /// Creates a new group and logs the creation activity atomically.
  Future<String> createGroup({
    required GroupModel group,
    required String creatorName,
  }) async {
    try {
      final docRef = await _groups.add(group.toMap());

      // Log creation activity
      await _activities.add({
        'userId': group.createdBy,
        'type': 'group_created',
        'title': '$creatorName created ${group.groupName}',
        'description': '${group.groupType} group initialized',
        'groupName': group.groupName,
        'groupId': docRef.id,
        'amount': null,
        'timestamp': FieldValue.serverTimestamp(),
      });

      return docRef.id;
    } catch (e, st) {
      debugPrint('GroupFirestoreService.createGroup error: $e\n$st');
      rethrow;
    }
  }

  /// Fetches a single group by ID.
  Future<GroupModel?> getGroup(String groupId) async {
    try {
      final doc = await _groups.doc(groupId).get();
      if (!doc.exists || doc.data() == null) return null;
      return GroupModel.fromMap(doc.data()!, doc.id);
    } catch (e, st) {
      debugPrint('GroupFirestoreService.getGroup error: $e\n$st');
      rethrow;
    }
  }

  /// Real-time stream of a single group.
  Stream<GroupModel?> watchGroup(String groupId) {
    return _groups.doc(groupId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return GroupModel.fromMap(doc.data()!, doc.id);
    });
  }

  /// Real-time stream of all groups the user is a member of.
  Stream<List<GroupModel>> watchUserGroups(String uid) {
    return _groups
        .where('members', arrayContains: uid)
        .where('isArchived', isEqualTo: false)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => GroupModel.fromMap(d.data(), d.id))
            .toList());
  }

  // ─── Expenses ────────────────────────────────────────────────────────────

  /// Real-time stream of expenses for a group ordered by date.
  Stream<List<ExpenseModel>> watchGroupExpenses(String groupId) {
    return _db
        .collection('groups')
        .doc(groupId)
        .collection('expenses')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ExpenseModel.fromMap(d.data(), d.id))
            .toList());
  }

  /// Adds an expense to a group sub-collection and updates group balance.
  Future<void> addExpense({
    required String groupId,
    required ExpenseModel expense,
    required String addedByName,
    required String groupName,
    required String addedByUid,
  }) async {
    final batch = _db.batch();

    final expenseRef = _db
        .collection('groups')
        .doc(groupId)
        .collection('expenses')
        .doc();
    batch.set(expenseRef, expense.toMap());

    // Update group updatedAt and balance
    final groupRef = _groups.doc(groupId);
    batch.update(groupRef, {
      'updatedAt': FieldValue.serverTimestamp(),
      'balance': FieldValue.increment(expense.amount),
    });

    final activityRef = _activities.doc();
    batch.set(activityRef, {
      'userId': addedByUid,
      'type': 'expense_added',
      'title': '$addedByName added ${expense.title}',
      'description': groupName,
      'groupName': groupName,
      'groupId': groupId,
      'amount': expense.amount,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // ─── Members ─────────────────────────────────────────────────────────────

  /// Adds a member UID to the group's members array.
  Future<void> addMember({
    required String groupId,
    required String memberUid,
    required String memberName,
    required String groupName,
    required String addedByUid,
  }) async {
    final batch = _db.batch();
    final groupRef = _groups.doc(groupId);
    batch.update(groupRef, {
      'members': FieldValue.arrayUnion([memberUid]),
      'memberCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final activityRef = _activities.doc();
    batch.set(activityRef, {
      'userId': addedByUid,
      'type': 'member_joined',
      'title': '$memberName joined $groupName',
      'description': 'New member added',
      'groupName': groupName,
      'groupId': groupId,
      'amount': null,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Generates a short alphanumeric invite code for a group.
  Future<String> generateInviteCode(String groupId) async {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final code = List.generate(
        6, (i) => chars[(groupId.codeUnitAt(i % groupId.length)) % chars.length]).join();

    await _groups.doc(groupId).update({'inviteCode': code});
    return code;
  }
}
