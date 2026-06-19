import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseModel {
  final String id;
  final String groupId;
  final String title;
  final double amount;
  final String paidBy;
  final List<String> splitAmong;
  final String category;
  final String notes;
  final DateTime date;
  final DateTime createdAt;

  ExpenseModel({
    required this.id,
    required this.groupId,
    required this.title,
    required this.amount,
    required this.paidBy,
    required this.splitAmong,
    this.category = 'General',
    this.notes = '',
    required this.date,
    required this.createdAt,
  });

  factory ExpenseModel.fromMap(Map<String, dynamic> map, String docId) {
    return ExpenseModel(
      id: docId,
      groupId: map['groupId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      paidBy: map['paidBy'] as String? ?? '',
      splitAmong: List<String>.from(map['splitAmong'] as List? ?? []),
      category: map['category'] as String? ?? 'General',
      notes: map['notes'] as String? ?? '',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt:
          (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'title': title,
      'amount': amount,
      'paidBy': paidBy,
      'splitAmong': splitAmong,
      'category': category,
      'notes': notes,
      'date': Timestamp.fromDate(date),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
