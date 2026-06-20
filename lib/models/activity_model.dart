import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents the type of activity performed by a user in the application.
enum ActivityType {
  expenseAdded,
  expenseUpdated,
  expenseDeleted,
  groupCreated,
  memberJoined,
  settlementCompleted,
  reminderSent,
  billImported,
  receiptScanned,
  joinRequestCreated,
  joinRequestApproved,
  joinRequestDenied;

  /// Returns the corresponding display string for the type
  String get displayName {
    switch (this) {
      case ActivityType.expenseAdded:
        return 'Expense Added';
      case ActivityType.expenseUpdated:
        return 'Expense Updated';
      case ActivityType.expenseDeleted:
        return 'Expense Deleted';
      case ActivityType.groupCreated:
        return 'Group Created';
      case ActivityType.memberJoined:
        return 'Member Joined';
      case ActivityType.settlementCompleted:
        return 'Settlement Completed';
      case ActivityType.reminderSent:
        return 'Reminder Sent';
      case ActivityType.billImported:
        return 'Bill Imported';
      case ActivityType.receiptScanned:
        return 'Receipt Scanned';
      case ActivityType.joinRequestCreated:
        return 'Join Request';
      case ActivityType.joinRequestApproved:
        return 'Join Approved';
      case ActivityType.joinRequestDenied:
        return 'Join Denied';
    }
  }

  /// Parses a string representation to the corresponding enum value
  static ActivityType fromString(String value) {
    switch (value.toLowerCase().replaceAll(' ', '_')) {
      case 'expense_added':
      case 'expenseadded':
        return ActivityType.expenseAdded;
      case 'expense_updated':
      case 'expenseupdated':
        return ActivityType.expenseUpdated;
      case 'expense_deleted':
      case 'expensedeleted':
        return ActivityType.expenseDeleted;
      case 'group_created':
      case 'groupcreated':
        return ActivityType.groupCreated;
      case 'member_joined':
      case 'memberjoined':
        return ActivityType.memberJoined;
      case 'settlement_completed':
      case 'settlementcompleted':
        return ActivityType.settlementCompleted;
      case 'reminder_sent':
      case 'remindersent':
        return ActivityType.reminderSent;
      case 'bill_imported':
      case 'billimported':
        return ActivityType.billImported;
      case 'receipt_scanned':
      case 'receiptscanned':
        return ActivityType.receiptScanned;
      case 'join_request_created':
      case 'joinrequestcreated':
        return ActivityType.joinRequestCreated;
      case 'join_request_approved':
      case 'joinrequestapproved':
        return ActivityType.joinRequestApproved;
      case 'join_request_denied':
      case 'joinrequestdenied':
        return ActivityType.joinRequestDenied;
      default:
        return ActivityType.expenseAdded; // Default fallback
    }
  }

  /// Returns string value stored in Firestore
  String toDbString() {
    switch (this) {
      case ActivityType.expenseAdded:
        return 'expense_added';
      case ActivityType.expenseUpdated:
        return 'expense_updated';
      case ActivityType.expenseDeleted:
        return 'expense_deleted';
      case ActivityType.groupCreated:
        return 'group_created';
      case ActivityType.memberJoined:
        return 'member_joined';
      case ActivityType.settlementCompleted:
        return 'settlement_completed';
      case ActivityType.reminderSent:
        return 'reminder_sent';
      case ActivityType.billImported:
        return 'bill_imported';
      case ActivityType.receiptScanned:
        return 'receipt_scanned';
      case ActivityType.joinRequestCreated:
        return 'join_request_created';
      case ActivityType.joinRequestApproved:
        return 'join_request_approved';
      case ActivityType.joinRequestDenied:
        return 'join_request_denied';
    }
  }
}

/// Data model representing a roommate spend activity logs stored in Firestore.
class ActivityModel {
  final String id;
  final String userId;
  final ActivityType type;
  final String title;
  final String description;
  final double? amount;
  final String groupName;
  final String groupId;
  final DateTime timestamp;

  ActivityModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.description,
    this.amount,
    required this.groupName,
    required this.groupId,
    required this.timestamp,
  });

  /// Maps Firestore document map back into ActivityModel object
  factory ActivityModel.fromMap(Map<String, dynamic> map, String docId) {
    return ActivityModel(
      id: docId,
      userId: map['userId'] ?? '',
      type: ActivityType.fromString(map['type'] ?? ''),
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      amount: map['amount'] != null ? (map['amount'] as num).toDouble() : null,
      groupName: map['groupName'] ?? '',
      groupId: map['groupId'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Maps ActivityModel to database write map
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type.toDbString(),
      'title': title,
      'description': description,
      'amount': amount,
      'groupName': groupName,
      'groupId': groupId,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
