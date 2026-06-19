# ⚡ QUICK FIX - Invite System & Group Details Not Working

## 🔴 Problems
1. Invite system showing errors: **PERMISSION_DENIED** for `groupInvites`
2. Group details screen blank/not loading: **PERMISSION_DENIED** for `expenses`

## ✅ Solution (5 Easy Steps)

### Step 1: Open Firebase Console (1 min)
1. Go to: https://console.firebase.google.com
2. Click on project: **roomiespend2**

### Step 2: Update Security Rules (2 min)
1. Click **"Firestore Database"** in left menu
2. Click **"Rules"** tab at top
3. **DELETE** everything in the editor
4. **COPY** from `firestore.rules` file
5. **PASTE** into editor
6. Click **"Publish"** button

### Step 3: Create Index #1 - Groups (1 min)
**Click this link** (opens Firebase Console):
```
https://console.firebase.google.com/v1/r/project/roomiespend2/firestore/indexes?create_composite=Cktwcm9qZWN0cy9yb29taWVzcGVuZDIvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL2dyb3Vwcy9pbmRleGVzL18QARoLCgdtZW1iZXJzGAEaDgoKaXNBcmNoaXZlZBABGg0KCXVwZGF0ZWRBdBACGgwKCF9fbmFtZV9fEAI
```
Then click **"Create Index"**

### Step 4: Create Index #2 - Activities (1 min)
**Click this link** (opens Firebase Console):
```
https://console.firebase.google.com/v1/r/project/roomiespend2/firestore/indexes?create_composite=Ck9wcm9qZWN0cy9yb29taWVzcGVuZDIvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL2FjdGl2aXRpZXMvaW5kZXhlcy9fEAEaCgoGdXNlcklkEAEaDQoJdGltZXN0YW1wEAIaDAoIX19uYW1lX18QAg
```
Then click **"Create Index"**

### Step 5: Wait & Test (10 min)
1. Wait for indexes to build (5-10 minutes)
   - Check email for "Index creation complete"
   - Or check Firebase Console → Indexes tab
2. **Restart your app**
3. **Test invite system** - Should work now! ✅

---

## 🎯 Quick Verification

After Step 2 (Rules published), check:
- Go to Firebase Console → Firestore Database → Rules
- Look for: `match /groupInvites/{inviteId}`
- Should see: `allow read: if isAuthenticated();`

After Step 4 (Indexes created), check:
- Go to Firebase Console → Firestore Database → Indexes
- Should see 2 new indexes with status "Building" → "Enabled"

---

## ✅ Success!

Your invite system will work when:
- ✅ Rules are published
- ✅ Both indexes show "Enabled" status
- ✅ App is restarted

**What Gets Fixed:**
- ✅ Invite QR codes work
- ✅ Share invite links work
- ✅ Group details screen loads properly
- ✅ Expenses display in groups
- ✅ No permission errors

---

**Total Time: ~15 minutes (including index build time)**

See `FIRESTORE_SETUP_FIX.md` for detailed instructions.
