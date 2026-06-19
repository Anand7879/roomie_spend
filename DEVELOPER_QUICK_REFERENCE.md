# Developer Quick Reference - Invitation System

## 🔥 Firestore Security Rules (Add These)

```javascript
// Firestore Security Rules for Invitation System
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Group Invites Collection
    match /groupInvites/{inviteId} {
      // Anyone can read invites to verify them
      allow read: if request.auth != null;
      
      // Only group members can create invites
      allow create: if request.auth != null 
        && exists(/databases/$(database)/documents/groups/$(request.resource.data.groupId))
        && request.auth.uid in get(/databases/$(database)/documents/groups/$(request.resource.data.groupId)).data.members;
      
      // Only creator can update (mark as used)
      allow update: if request.auth != null;
      
      // No deletes
      allow delete: if false;
    }
    
    // Group Members Subcollection
    match /groups/{groupId}/members/{memberId} {
      // Members can read all members
      allow read: if request.auth != null 
        && request.auth.uid in get(/databases/$(database)/documents/groups/$(groupId)).data.members;
      
      // Only through invite system or group owner
      allow write: if request.auth != null;
    }
    
    // Groups Collection (update existing rules)
    match /groups/{groupId} {
      // Add members array to group on join
      allow update: if request.auth != null 
        && (request.auth.uid in resource.data.members 
            || request.auth.uid in request.resource.data.members);
    }
  }
}
```

## 🔍 Firestore Indexes (Required)

Add to `firestore.indexes.json`:

```json
{
  "indexes": [
    {
      "collectionGroup": "groupInvites",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "groupId", "order": "ASCENDING" },
        { "fieldPath": "used", "order": "ASCENDING" },
        { "fieldPath": "expiresAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "groupInvites",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "inviteCode", "order": "ASCENDING" },
        { "fieldPath": "used", "order": "ASCENDING" }
      ]
    }
  ]
}
```

## 📱 Deep Linking Setup (Optional)

### Android (AndroidManifest.xml)
```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="https"
          android:host="roomiespend.app"
          android:pathPrefix="/invite" />
</intent-filter>
```

### iOS (Info.plist)
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>roomiespend</string>
        </array>
    </dict>
</array>
```

### Handle Deep Link (main.dart)
```dart
import 'package:uni_links/uni_links.dart';

// In main() or app initialization
void initDeepLinks() {
  // Handle initial link
  getInitialUri().then((uri) {
    if (uri != null) _handleDeepLink(uri);
  });
  
  // Handle subsequent links
  uriLinkStream.listen((uri) {
    if (uri != null) _handleDeepLink(uri);
  });
}

void _handleDeepLink(Uri uri) {
  if (uri.pathSegments.length == 2 && uri.pathSegments[0] == 'invite') {
    final inviteCode = uri.pathSegments[1];
    // Navigate to JoinByCodeScreen with pre-filled code
    // Or auto-join if user is authenticated
  }
}
```

## 🔔 Push Notifications Setup (Optional)

### 1. Add FCM to User Model
```dart
class RoommateUser {
  final String uid;
  final String fcmToken; // Add this
  // ... other fields
}
```

### 2. Save FCM Token on Login
```dart
import 'package:firebase_messaging/firebase_messaging.dart';

Future<void> saveFcmToken(String uid) async {
  final fcmToken = await FirebaseMessaging.instance.getToken();
  await FirebaseFirestore.instance.collection('users').doc(uid).update({
    'fcmToken': fcmToken,
  });
}
```

### 3. Send Notification on Member Join
```dart
// In invite_service.dart, after batch.commit()
await _sendJoinNotification(
  userId: invite.createdBy,
  userName: userName,
  groupName: group.groupName,
);

Future<void> _sendJoinNotification({
  required String userId,
  required String userName,
  required String groupName,
}) async {
  // Get user's FCM token
  final userDoc = await _db.collection('users').doc(userId).get();
  final fcmToken = userDoc.data()?['fcmToken'] as String?;
  
  if (fcmToken != null) {
    // Call Cloud Function to send notification
    // Or use Firebase Admin SDK from backend
  }
}
```

## 🧪 Testing Utilities

### Mock Invite Code for Testing
```dart
// In invite_service.dart (dev mode only)
String _generateInviteCode() {
  if (kDebugMode) {
    // Use fixed code for testing
    return 'RMSP-TEST';
  }
  // Production code
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final random = Random.secure();
  final code = List.generate(4, (_) => chars[random.nextInt(chars.length)]).join();
  return '$_invitePrefix-$code';
}
```

### Test Invite Flow
```dart
// Integration test
void main() {
  testWidgets('Complete invite flow', (tester) async {
    // 1. Create group
    await tester.tap(find.text('Create Group'));
    await tester.enterText(find.byType(TextField), 'Test Group');
    await tester.tap(find.text('Create'));
    
    // 2. Generate invite
    await tester.tap(find.text('Show QR Code'));
    expect(find.textContaining('RMSP-'), findsOneWidget);
    
    // 3. Join with code (simulate second user)
    await tester.tap(find.text('Enter Code'));
    await tester.enterText(find.byType(TextField), 'RMSP-TEST');
    await tester.tap(find.text('Join Group'));
    
    // 4. Verify member added
    expect(find.text('joined the group'), findsOneWidget);
  });
}
```

## 🐛 Common Issues & Fixes

### Issue: "No such module 'mobile_scanner'"
**Fix:**
```bash
cd ios
pod install
cd ..
flutter clean
flutter pub get
```

### Issue: Camera not working on Android
**Fix:**
1. Check `AndroidManifest.xml` has camera permissions
2. Request permission at runtime:
```dart
final status = await Permission.camera.request();
if (!status.isGranted) {
  // Show settings dialog
}
```

### Issue: QR Scanner crashes
**Fix:**
Ensure `mobile_scanner` is latest version and add to `build.gradle`:
```gradle
android {
    compileSdkVersion 33
    defaultConfig {
        minSdkVersion 21  // Required for mobile_scanner
    }
}
```

### Issue: Contacts permission denied on iOS
**Fix:**
1. Check `Info.plist` has `NSContactsUsageDescription`
2. Test on real device (doesn't work on simulator)

## 📊 Analytics Events (Optional)

```dart
// Log invite events for analytics
void logInviteEvent(String eventName, Map<String, dynamic> params) {
  FirebaseAnalytics.instance.logEvent(
    name: eventName,
    parameters: params,
  );
}

// Usage:
logInviteEvent('invite_generated', {
  'group_id': groupId,
  'method': 'qr_code',
});

logInviteEvent('invite_accepted', {
  'group_id': groupId,
  'method': 'scan_qr',
  'time_to_join_minutes': 5,
});
```

## 🔒 Backend Validation (Recommended)

Use Cloud Functions for server-side validation:

```javascript
// Cloud Function to validate invite
exports.validateInvite = functions.https.onCall(async (data, context) => {
  const { inviteCode } = data;
  const uid = context.auth.uid;
  
  // Server-side validation
  const invite = await admin.firestore()
    .collection('groupInvites')
    .where('inviteCode', '==', inviteCode)
    .limit(1)
    .get();
  
  if (invite.empty) {
    throw new functions.https.HttpsError('not-found', 'Invalid invite code');
  }
  
  const inviteData = invite.docs[0].data();
  
  // Check expiration
  if (inviteData.expiresAt.toDate() < new Date()) {
    throw new functions.https.HttpsError('failed-precondition', 'Invite expired');
  }
  
  // Add user to group
  await admin.firestore()
    .collection('groups')
    .doc(inviteData.groupId)
    .update({
      members: admin.firestore.FieldValue.arrayUnion(uid),
      memberCount: admin.firestore.FieldValue.increment(1),
    });
  
  return { success: true, groupId: inviteData.groupId };
});
```

## 📦 Build Commands

### Android
```bash
flutter build apk --release
# Or
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
# Then open in Xcode to archive
```

### Run with deep linking test
```bash
# Android
adb shell am start -W -a android.intent.action.VIEW \
  -d "https://roomiespend.app/invite/RMSP-TEST" \
  com.example.roomie_spend

# iOS (in terminal)
xcrun simctl openurl booted "https://roomiespend.app/invite/RMSP-TEST"
```

## 🎨 Customization Points

### Change Invite Code Format
```dart
// In invite_service.dart
static const String _invitePrefix = 'RMSP';  // Change this
static const int _codeLength = 4;             // Change this
```

### Change Expiration Days
```dart
// In invite_service.dart
static const int _inviteDays = 7;  // Change this
```

### Customize Share Message
```dart
// In invite_service.dart - generateShareText()
String generateShareText(String inviteCode, String groupName) {
  return '''
Your custom message here
Code: $inviteCode
  ''';
}
```

## 💡 Pro Tips

1. **Always use batch writes** for multi-document operations
2. **Check `isValid` before joins** to prevent expired invite usage
3. **Use `autoDispose`** on StreamProviders to prevent memory leaks
4. **Test permissions** on real devices, not simulators
5. **Add analytics** to track which invite method is most popular
6. **Implement rate limiting** to prevent invite spam
7. **Add member limit** to prevent group overflow
8. **Log all invite actions** for audit trail

---

**Happy Coding! 🚀**
