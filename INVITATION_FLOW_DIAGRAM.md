# Invitation System Flow Diagrams

## 1. Complete System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     INVITATION SYSTEM                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐      ┌──────────────┐      ┌──────────────┐ │
│  │   UI Layer   │──────│ Provider     │──────│  Service     │ │
│  │   (Screens)  │      │  (Riverpod)  │      │   Layer      │ │
│  └──────────────┘      └──────────────┘      └──────────────┘ │
│         │                      │                      │         │
│         │                      │                      │         │
│         ▼                      ▼                      ▼         │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │               Firestore Collections                       │  │
│  ├──────────────────────────────────────────────────────────┤  │
│  │  • groupInvites       • groups/members                   │  │
│  │  • groups             • activities                       │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. QR Code Flow

### A. Generate QR Code Flow
```
User Opens Group
       │
       ├──> Tap "Show QR Code"
       │
       ├──> InviteFriendsScreen
       │
       ├──> Tap "Show QR Code"
       │
       ▼
ShowQRScreen loads
       │
       ├──> Check for active invite code in Firestore
       │    ├─ Found? Use existing
       │    └─ Not found? Generate new
       │
       ├──> InviteService.createGroupInvite()
       │    ├─ Generate secure random code (RMSP-XXXX)
       │    ├─ Set expiresAt = now + 7 days
       │    └─ Save to groupInvites collection
       │
       ├──> Encode QR: {"groupId": "...", "inviteCode": "RMSP-XXXX"}
       │
       └──> Display QR Code + Invite Code + Share Button
```

### B. Scan QR Code Flow
```
User Opens App
       │
       ├──> Tap "Scan QR" (Home or Groups tab)
       │
       ▼
ScanQRScreen
       │
       ├──> Request camera permission
       │    ├─ Granted? Continue
       │    └─ Denied? Show permission dialog
       │
       ├──> Start mobile_scanner
       │
       ├──> User points camera at QR code
       │
       ├──> Barcode detected
       │
       ├──> Extract inviteCode from QR data
       │
       ├──> InviteProvider.joinGroupViaInvite(code)
       │    │
       │    ├──> InviteService.verifyInviteCode()
       │    │    └─ Query groupInvites where inviteCode = code
       │    │
       │    ├──> Validate:
       │    │    ├─ Exists?
       │    │    ├─ Not expired?
       │    │    ├─ Not used?
       │    │    └─ Group not archived?
       │    │
       │    ├──> Firestore Batch Write:
       │    │    ├─ Update groups.members (add userId)
       │    │    ├─ Update groups.memberCount (+1)
       │    │    ├─ Create groups/{id}/members/{userId}
       │    │    ├─ Update groupInvites (set used=true)
       │    │    └─ Create activity log
       │    │
       │    └──> Commit batch
       │
       ├──> Show success animation
       │
       └──> Navigate to GroupDetailsScreen
```

---

## 3. Share Link Flow

```
User in Group
       │
       ├──> Tap "Share Invite Link"
       │
       ▼
InviteFriendsScreen
       │
       ├──> Load/Generate invite code
       │
       ├──> InviteService.generateShareText()
       │    └─ Format message with code and deep link
       │
       ├──> share_plus package opens share sheet
       │
       ├──> User selects WhatsApp/SMS/Email
       │
       └──> Message sent with invite code

Recipient receives message
       │
       ├──> Opens RoomieSpend app
       │
       ├──> Navigates to "Enter Invite Code"
       │
       ├──> Pastes/Types code
       │
       └──> Same validation flow as QR scan
```

---

## 4. Contacts Invite Flow

```
User in Group
       │
       ├──> Tap "Add from Contacts"
       │
       ▼
ContactsInviteScreen
       │
       ├──> Request contacts permission
       │    ├─ Granted? Continue
       │    └─ Denied? Show settings redirect
       │
       ├──> Load contacts using flutter_contacts
       │    └─ Filter: contacts with phone numbers
       │
       ├──> Display searchable list
       │
       ├──> User searches and selects contacts
       │
       ├──> Tap "Send Invite to X contact(s)"
       │
       ├──> For each contact:
       │    ├─ [Future] Check if phone exists in users collection
       │    ├─ If exists: Send in-app notification
       │    └─ If not: Share via SMS (share_plus)
       │
       └──> Show success message
```

---

## 5. Enter Code Manually Flow

```
User Opens App
       │
       ├──> Tap "Enter Code" (Home screen)
       │
       ▼
JoinByCodeScreen
       │
       ├──> User types code
       │    └─ Auto-format: RMSP-XXXX (dash added automatically)
       │
       ├──> Validate format (regex)
       │    └─ Pattern: ^RMSP-[A-Z0-9]{4}$
       │
       ├──> Tap "Join Group"
       │
       └──> Same flow as QR scan validation
```

---

## 6. Firestore Data Flow

### Write Operations (Join Group)

```
┌─────────────────────────────────────────────────────────────┐
│                    Firestore Batch Write                     │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. Update groups/{groupId}                                 │
│     ├─ members: arrayUnion([userId])                        │
│     ├─ memberCount: increment(1)                            │
│     └─ updatedAt: serverTimestamp()                         │
│                                                              │
│  2. Create groups/{groupId}/members/{userId}                │
│     ├─ userId, userName, userAvatar, userPhone             │
│     ├─ role: 'member'                                       │
│     ├─ joinedAt: serverTimestamp()                          │
│     └─ invitedBy: createdBy                                 │
│                                                              │
│  3. Update groupInvites/{inviteId}                          │
│     ├─ used: true                                           │
│     ├─ usedBy: userId                                       │
│     └─ joinedAt: serverTimestamp()                          │
│                                                              │
│  4. Create activities/{activityId}                          │
│     ├─ type: 'member_joined'                                │
│     ├─ title: '{userName} joined the group'                │
│     ├─ groupName, groupId                                   │
│     └─ timestamp: serverTimestamp()                         │
│                                                              │
│  ✅ ALL OR NOTHING (Atomic Transaction)                     │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Read Operations (Show QR)

```
1. Query groupInvites
   ├─ where('groupId', ==, groupId)
   ├─ where('used', ==, false)
   └─ Check expiresAt > now

2. If valid invite found:
   └─ Return existing inviteCode

3. If no valid invite:
   ├─ Generate new invite code
   ├─ Create groupInvites document
   └─ Return new inviteCode
```

---

## 7. State Management Flow (Riverpod)

```
┌─────────────────────────────────────────────────────────────┐
│                    InviteProvider States                     │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  InviteIdle (Initial)                                       │
│       │                                                      │
│       ├──> generateInviteCode() called                      │
│       │                                                      │
│       ▼                                                      │
│  InviteLoading                                              │
│       │                                                      │
│       ├──> Success                                          │
│       │      │                                               │
│       │      ▼                                               │
│       │   InviteCodeGenerated(code)                         │
│       │                                                      │
│       ├──> joinGroupViaInvite() called                      │
│       │      │                                               │
│       │      ├──> Success                                    │
│       │      │      │                                        │
│       │      │      ▼                                        │
│       │      │   InviteSuccess(groupId, groupName, ...)    │
│       │      │                                               │
│       │      └──> Failure                                    │
│       │             │                                        │
│       │             ▼                                        │
│       │          InviteFailure(message)                     │
│       │                                                      │
│       └──> Error                                             │
│              │                                               │
│              ▼                                               │
│          InviteFailure(message)                             │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 8. Security Validation Flow

```
┌─────────────────────────────────────────────────────────────┐
│                  Invite Validation Checks                    │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. Invite Code Exists?                                     │
│     ├─ YES → Continue                                       │
│     └─ NO  → Error: "Invalid invite code"                  │
│                                                              │
│  2. Invite Expired? (now > expiresAt)                       │
│     ├─ YES → Error: "Invite code expired"                  │
│     └─ NO  → Continue                                       │
│                                                              │
│  3. Already Used? (used == true)                            │
│     ├─ YES → Error: "Invite already used"                  │
│     └─ NO  → Continue                                       │
│                                                              │
│  4. Group Exists?                                           │
│     ├─ YES → Continue                                       │
│     └─ NO  → Error: "Group not found"                      │
│                                                              │
│  5. Group Archived? (isArchived == true)                    │
│     ├─ YES → Error: "Cannot join archived group"           │
│     └─ NO  → Continue                                       │
│                                                              │
│  6. Already a Member? (userId in members[])                 │
│     ├─ YES → Error: "Already a member"                     │
│     └─ NO  → ✅ ALLOW JOIN                                  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 9. Permission Flow (Android/iOS)

```
┌─────────────────────────────────────────────────────────────┐
│                   Camera Permission Flow                     │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  User taps "Scan QR"                                        │
│       │                                                      │
│       ├──> Check Permission Status                          │
│       │                                                      │
│       ├──> GRANTED                                          │
│       │      └─> Open scanner                               │
│       │                                                      │
│       ├──> NOT DETERMINED                                   │
│       │      ├─> Show permission dialog                     │
│       │      ├─> User allows? → Open scanner               │
│       │      └─> User denies? → Show message               │
│       │                                                      │
│       └──> DENIED / PERMANENTLY DENIED                       │
│              └─> Show "Go to Settings" button               │
│                                                              │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                  Contacts Permission Flow                    │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  User taps "Add from Contacts"                              │
│       │                                                      │
│       └──> Same flow as camera                              │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 10. User Journey Map

```
┌─────────────────────────────────────────────────────────────┐
│                    User Journey: Inviter                     │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  START: User creates a group                                │
│    │                                                         │
│    ├──> GOAL: Invite roommates                              │
│    │                                                         │
│    ├──> METHOD 1: In-person (QR Code)                       │
│    │    └─> Show QR → Friend scans → Instant join          │
│    │                                                         │
│    ├──> METHOD 2: Remote (Share Link)                       │
│    │    └─> Share via WhatsApp → Friend enters code        │
│    │                                                         │
│    ├──> METHOD 3: Multiple friends (Contacts)               │
│    │    └─> Select contacts → Send bulk invites            │
│    │                                                         │
│    └──> RESULT: Friends added, expenses can be split       │
│                                                              │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    User Journey: Invitee                     │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  START: Receives invite                                     │
│    │                                                         │
│    ├──> Opens app (or installs first)                       │
│    │                                                         │
│    ├──> METHOD 1: Scan QR (in person)                       │
│    │    └─> Tap "Scan QR" → Point camera → Auto join       │
│    │                                                         │
│    ├──> METHOD 2: Has code (remote)                         │
│    │    └─> Tap "Enter Code" → Type code → Join            │
│    │                                                         │
│    └──> RESULT: In group, can view/add expenses            │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Legend

```
Symbol Guide:
├──>  Next step
└──>  Final step or alternative path
│     Vertical connection
▼     Action flow continues
✅    Success state
❌    Error state
```

---

**These diagrams visualize the complete invitation system architecture and flows! 🎨**
