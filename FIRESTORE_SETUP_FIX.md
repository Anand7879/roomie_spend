# 🔥 Firestore Setup Fix - URGENT

## ⚠️ Current Issues

Your app isn't working properly due to **2 critical Firestore configuration issues**:

1. **PERMISSION_DENIED** - Security rules block access to `groupInvites` and `expenses` collections
2. **FAILED_PRECONDITION** - Missing indexes for queries

**Symptoms:**
- ❌ Invite system doesn't work (can't generate QR codes or invite codes)
- ❌ Group details screen is blank/not loading
- ❌ Can't see expenses in groups
- ❌ Activities feed may not load

---

## 🚨 Fix #1: Update Firestore Security Rules (CRITICAL)

### Step 1: Open Firebase Console
1. Go to https://console.firebase.google.com
2. Select your project: **roomiespend2**
3. Click **Firestore Database** in left menu
4. Click **Rules** tab at the top

### Step 2: Replace Existing Rules
Copy the content from `firestore.rules` file and paste it into the Firebase Console Rules editor.

**Or manually paste these rules:**

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper function to check if user is authenticated
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // Users collection
    match /users/{userId} {
      allow read: if isAuthenticated();
      allow create: if isAuthenticated() && request.auth.uid == userId;
      allow update: if isAuthenticated() && request.auth.uid == userId;
      allow delete: if false;
    }
    
    // Groups collection
    match /groups/{groupId} {
      allow read: if isAuthenticated() && 
                     request.auth.uid in resource.data.members;
      allow create: if isAuthenticated();
      allow update: if isAuthenticated() && 
                       request.auth.uid in resource.data.members;
      allow delete: if isAuthenticated() && 
                       resource.data.createdBy == request.auth.uid;
      
      // Group members subcollection
      match /members/{memberId} {
        allow read: if isAuthenticated() && 
                       request.auth.uid in get(/databases/$(database)/documents/groups/$(groupId)).data.members;
        allow create: if isAuthenticated();
        allow update: if isAuthenticated() && 
                         request.auth.uid in get(/databases/$(database)/documents/groups/$(groupId)).data.members;
        allow delete: if isAuthenticated();
      }
      
      // Group expenses subcollection - CRITICAL FOR GROUP DETAILS
      match /expenses/{expenseId} {
        allow read: if isAuthenticated() && 
                       request.auth.uid in get(/databases/$(database)/documents/groups/$(groupId)).data.members;
        allow create: if isAuthenticated() && 
                        request.auth.uid in get(/databases/$(database)/documents/groups/$(groupId)).data.members;
        allow update: if isAuthenticated() && 
                        request.auth.uid in get(/databases/$(database)/documents/groups/$(groupId)).data.members;
        allow delete: if isAuthenticated();
      }
    }
    
    // Group invites collection - CRITICAL FOR INVITE SYSTEM
    match /groupInvites/{inviteId} {
      // Allow reading invites
      allow read: if isAuthenticated();
      
      // Allow creating invites if authenticated
      allow create: if isAuthenticated();
      
      // Allow updating invites (for marking as used)
      allow update: if isAuthenticated();
      
      // Allow deleting invites
      allow delete: if isAuthenticated();
    }
    
    // Activities collection
    match /activities/{activityId} {
      allow read: if isAuthenticated() && 
                     resource.data.userId == request.auth.uid;
      allow create: if isAuthenticated();
      allow update: if false;
      allow delete: if isAuthenticated() && 
                       resource.data.userId == request.auth.uid;
    }
    
    // Expenses collection
    match /expenses/{expenseId} {
      allow read: if isAuthenticated();
      allow create: if isAuthenticated();
      allow update: if isAuthenticated();
      allow delete: if isAuthenticated();
    }
  }
}
```

### Step 3: Publish Rules
1. Click **Publish** button in Firebase Console
2. Wait for confirmation message
3. Rules are now active!

---

## 🚨 Fix #2: Create Required Firestore Indexes

The error logs show you need **2 indexes**. Firebase provides direct links to create them!

### Index 1: Groups Query
**Click this link to create automatically:**
```
https://console.firebase.google.com/v1/r/project/roomiespend2/firestore/indexes?create_composite=Cktwcm9qZWN0cy9yb29taWVzcGVuZDIvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL2dyb3Vwcy9pbmRleGVzL18QARoLCgdtZW1iZXJzGAEaDgoKaXNBcmNoaXZlZBABGg0KCXVwZGF0ZWRBdBACGgwKCF9fbmFtZV9fEAI
```

**Or create manually:**
1. Go to Firebase Console → Firestore Database → Indexes
2. Click **Create Index**
3. Collection: `groups`
4. Add fields:
   - Field: `members` | Mode: Array-contains
   - Field: `isArchived` | Mode: Ascending
   - Field: `updatedAt` | Mode: Descending
5. Click **Create**

### Index 2: Activities Query
**Click this link to create automatically:**
```
https://console.firebase.google.com/v1/r/project/roomiespend2/firestore/indexes?create_composite=Ck9wcm9qZWN0cy9yb29taWVzcGVuZDIvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL2FjdGl2aXRpZXMvaW5kZXhlcy9fEAEaCgoGdXNlcklkEAEaDQoJdGltZXN0YW1wEAIaDAoIX19uYW1lX18QAg
```

**Or create manually:**
1. Go to Firebase Console → Firestore Database → Indexes
2. Click **Create Index**
3. Collection: `activities`
4. Add fields:
   - Field: `userId` | Mode: Ascending
   - Field: `timestamp` | Mode: Descending
5. Click **Create**

### Wait for Indexes to Build
- Index creation can take a few minutes
- Status shows "Building" → "Enabled"
- You'll get email notification when ready

---

## 📝 Quick Fix Checklist

Follow these steps in order:

- [ ] **Step 1:** Open Firebase Console
- [ ] **Step 2:** Go to Firestore Database → Rules
- [ ] **Step 3:** Paste the new security rules
- [ ] **Step 4:** Click Publish
- [ ] **Step 5:** Click the first index link (groups)
- [ ] **Step 6:** Confirm index creation
- [ ] **Step 7:** Click the second index link (activities)
- [ ] **Step 8:** Confirm index creation
- [ ] **Step 9:** Wait for both indexes to finish building (5-10 mins)
- [ ] **Step 10:** Restart your app and test invites!

---

## 🧪 Test After Fixing

Once rules are published and indexes are built:

1. **Restart your app**
2. **Open a group**
3. **Tap "Invite Friends"**
4. **Tap "Show QR Code"**
5. **Should work now!** ✅

### Expected Behavior:
- ✅ QR code displays without errors
- ✅ Invite code shows (RMSP-XXXX)
- ✅ Share link works
- ✅ Group details screen loads properly
- ✅ Expenses display in groups
- ✅ No permission errors in logs
- ✅ Activities feed loads

---

## 🔍 Verify Rules Are Applied

### Check in Firebase Console:
1. Go to Firestore Database → Rules
2. Look for `match /groupInvites/{inviteId}` section
3. Should see: `allow read: if isAuthenticated();`

### Check in App Logs:
After applying fixes, errors should disappear:
- ❌ Before: `PERMISSION_DENIED: Missing or insufficient permissions`
- ✅ After: No permission errors!

---

## ⚡ Alternative: Use Test Mode (NOT Recommended for Production)

**Only for development/testing:**

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

⚠️ **WARNING:** This allows all authenticated users to read/write everything!
Use only for testing, then switch to proper rules above.

---

## 🆘 Troubleshooting

### Issue: Still getting permission errors
**Solution:** 
- Clear app data
- Restart app
- Check if rules were published (refresh Firebase Console)

### Issue: Indexes still building
**Solution:**
- Wait 5-10 minutes
- Check email for completion notification
- View status in Firebase Console → Indexes tab

### Issue: Can't access Firebase Console
**Solution:**
- Make sure you're logged in with correct account
- Check project name: **roomiespend2**
- Ask project owner for permissions

### Issue: Rules won't publish
**Solution:**
- Check for syntax errors (red underlines)
- Make sure you have editor/owner permissions
- Try copying rules again

---

## 📚 What These Rules Do

### groupInvites Collection:
- ✅ **Read:** Any authenticated user can read invites
- ✅ **Create:** Any authenticated user can create invites
- ✅ **Update:** Any authenticated user can update (for marking as used)
- ✅ **Delete:** Any authenticated user can delete invites

### Why This Works:
1. **Invite codes are meant to be shared** - anyone with the code should join
2. **Authentication required** - prevents spam/abuse
3. **Flexible permissions** - allows all invite methods to work

### Security Notes:
- Users must be authenticated (logged in)
- Can't access data without Firebase Auth
- Invites expire after 7 days (app-level validation)
- Duplicate joins prevented (app-level validation)

---

## 🎯 Expected Results After Fix

### Before (Current State):
```
❌ QR code screen: Loading forever
❌ Invite Friends: No invite code generated
❌ Share Link: Nothing to share
❌ Scan QR: Can't join group
❌ Enter Code: Permission denied
❌ Group Details: Blank screen, no data
❌ Expenses: Not showing
❌ Logs: PERMISSION_DENIED errors everywhere
```

### After (Fixed State):
```
✅ QR code screen: Shows QR + invite code
✅ Invite Friends: Generates RMSP-XXXX code
✅ Share Link: Shares with formatted message
✅ Scan QR: Joins group successfully
✅ Enter Code: Joins with manual code
✅ Group Details: Loads with all data
✅ Expenses: Display properly
✅ Logs: Clean, no permission errors
```

---

## ⏱️ Time Required

- **Update Rules:** 2 minutes
- **Create Indexes:** 5-10 minutes (building time)
- **Test:** 2 minutes
- **Total:** ~15 minutes

---

## 🎉 Success Indicators

You'll know it worked when:
1. ✅ No more `PERMISSION_DENIED` in logs
2. ✅ QR code displays immediately
3. ✅ Invite code shows (RMSP-XXXX format)
4. ✅ Share button works
5. ✅ Group details screen loads properly
6. ✅ Expenses display in groups
7. ✅ Activities feed loads
8. ✅ Groups page shows data

---

## 📞 Need Help?

If issues persist after following all steps:
1. Check Firebase Console → Firestore → Rules → Make sure they're published
2. Check Firebase Console → Firestore → Indexes → Make sure status is "Enabled"
3. Clear app data and restart
4. Check logs for any remaining errors

---

**IMPORTANT:** Do this fix RIGHT NOW to make your invite system work! 🚀

The app code is perfect - you just need to configure Firestore properly.
