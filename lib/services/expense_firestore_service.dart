import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/enhanced_expense_model.dart';

/// Handles saving enhanced expenses (single and multi-bill) to Firestore,
/// including Firebase Storage image uploads.
///
/// Validates: Requirements 17.1, 17.2, 17.4, 17.5, 17.6
class ExpenseFirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ─── Single Expense Save ──────────────────────────────────────────────────

  /// Saves a single enhanced expense to Firestore and updates the group balance.
  ///
  /// Returns the Firestore document ID of the saved expense.
  Future<String> saveExpense({
    required String groupId,
    required EnhancedExpenseModel expense,
    required String addedByName,
    required String groupName,
    required String addedByUid,
    List<File> imageFiles = const [],
  }) async {
    try {
      // 1. Upload images first, get URLs
      final imageUrls = await _uploadImages(
        groupId: groupId,
        expenseId: 'tmp_${DateTime.now().millisecondsSinceEpoch}',
        files: imageFiles,
      );

      // 2. Prepare the expense map with image URLs
      final expenseWithImages = imageUrls.isEmpty
          ? expense
          : expense.copyWith(imageUrls: [...expense.imageUrls, ...imageUrls]);

      // 3. Batch write: expense + group update + activity
      final batch = _db.batch();

      final expenseRef = _db
          .collection('groups')
          .doc(groupId)
          .collection('expenses')
          .doc();

      batch.set(expenseRef, expenseWithImages.toMap());

      // Update group balance and timestamp
      final groupRef = _db.collection('groups').doc(groupId);
      batch.update(groupRef, {
        'updatedAt': FieldValue.serverTimestamp(),
        'balance': FieldValue.increment(expense.amount),
      });

      // Log activity
      final activityRef = _db.collection('activities').doc();
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
      return expenseRef.id;
    } catch (e, st) {
      debugPrint('ExpenseFirestoreService.saveExpense error: $e\n$st');
      rethrow;
    }
  }

  // ─── Multi-Bill Save ──────────────────────────────────────────────────────

  /// Saves multiple bills as separate expense documents linked by parentExpenseId.
  /// All saves are wrapped in a Firestore transaction for atomicity.
  ///
  /// Validates: Requirement 17.2
  Future<List<String>> saveMultiBillExpenses({
    required String groupId,
    required List<EnhancedExpenseModel> bills,
    required String addedByName,
    required String groupName,
    required String addedByUid,
  }) async {
    try {
      // Generate a parent ID to link all bills
      final parentRef = _db
          .collection('groups')
          .doc(groupId)
          .collection('expenses')
          .doc();
      final parentId = parentRef.id;

      final batch = _db.batch();
      final savedIds = <String>[];
      double totalAmount = 0.0;

      for (int i = 0; i < bills.length; i++) {
        final bill = bills[i].copyWith(
          billNumber: i + 1,
          parentExpenseId: parentId,
        );
        totalAmount += bill.amount;

        final ref = i == 0
            ? parentRef
            : _db
                .collection('groups')
                .doc(groupId)
                .collection('expenses')
                .doc();

        batch.set(ref, bill.toMap());
        savedIds.add(ref.id);
      }

      // Update group
      final groupRef = _db.collection('groups').doc(groupId);
      batch.update(groupRef, {
        'updatedAt': FieldValue.serverTimestamp(),
        'balance': FieldValue.increment(totalAmount),
      });

      // Activity log for the whole session
      final activityRef = _db.collection('activities').doc();
      batch.set(activityRef, {
        'userId': addedByUid,
        'type': 'expense_added',
        'title': '$addedByName added ${bills.length} bills',
        'description': groupName,
        'groupName': groupName,
        'groupId': groupId,
        'amount': totalAmount,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      return savedIds;
    } catch (e, st) {
      debugPrint('ExpenseFirestoreService.saveMultiBillExpenses error: $e\n$st');
      rethrow;
    }
  }

  // ─── Image Upload ─────────────────────────────────────────────────────────

  /// Uploads image files to Firebase Storage and returns download URLs.
  ///
  /// Storage path: groups/{groupId}/expenses/{expenseId}/image_{index}.jpg
  Future<List<String>> _uploadImages({
    required String groupId,
    required String expenseId,
    required List<File> files,
  }) async {
    if (files.isEmpty) return [];

    final urls = <String>[];
    for (int i = 0; i < files.length; i++) {
      try {
        final ref = _storage
            .ref()
            .child('groups/$groupId/expenses/$expenseId/image_$i.jpg');
        await ref.putFile(files[i]);
        final url = await ref.getDownloadURL();
        urls.add(url);
      } catch (e) {
        debugPrint('Image upload failed for index $i: $e');
        // Don't block expense save on image upload failure
      }
    }
    return urls;
  }
}
