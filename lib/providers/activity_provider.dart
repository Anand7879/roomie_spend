import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/activity_model.dart';
import 'auth_provider.dart';

/// StreamProvider that listens to the 10 most recent activities performed by the currently logged-in user.
final recentActivitiesProvider = StreamProvider.autoDispose<List<ActivityModel>>((ref) {
  final authState = ref.watch(authStateNotifierProvider);
  if (authState is! AuthAuthenticated) {
    return Stream.value([]);
  }

  final uid = authState.user.uid;
  
  return FirebaseFirestore.instance
      .collection('activities')
      .where('userId', isEqualTo: uid)
      .orderBy('timestamp', descending: true)
      .limit(10)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs
            .map((doc) => ActivityModel.fromMap(doc.data(), doc.id))
            .toList();
      });
});

/// StreamProvider that listens to all activities performed by the currently logged-in user (for "View All").
final allActivitiesProvider = StreamProvider.autoDispose<List<ActivityModel>>((ref) {
  final authState = ref.watch(authStateNotifierProvider);
  if (authState is! AuthAuthenticated) {
    return Stream.value([]);
  }

  final uid = authState.user.uid;

  return FirebaseFirestore.instance
      .collection('activities')
      .where('userId', isEqualTo: uid)
      .orderBy('timestamp', descending: true)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs
            .map((doc) => ActivityModel.fromMap(doc.data(), doc.id))
            .toList();
      });
});

/// A service notifier provider to perform Firestore activity operations
final activityServiceProvider = Provider((ref) => ActivityService(ref));

class ActivityService {
  final Ref _ref;
  ActivityService(this._ref);

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  /// Helper to record an activity in Firestore
  Future<void> logActivity({
    required ActivityType type,
    required String title,
    required String description,
    double? amount,
    required String groupName,
    String? groupId,
  }) async {
    final authState = _ref.read(authStateNotifierProvider);
    if (authState is! AuthAuthenticated) return;

    final uid = authState.user.uid;

    final activity = ActivityModel(
      id: '',
      userId: uid,
      type: type,
      title: title,
      description: description,
      amount: amount,
      groupName: groupName,
      groupId: groupId ?? '',
      timestamp: DateTime.now(),
    );

    await _firestore.collection('activities').add(activity.toMap());
  }

  /// Clears all activities for the current user
  Future<void> clearUserActivities() async {
    final authState = _ref.read(authStateNotifierProvider);
    if (authState is! AuthAuthenticated) return;

    final uid = authState.user.uid;

    final snapshot = await _firestore
        .collection('activities')
        .where('userId', isEqualTo: uid)
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }
}
