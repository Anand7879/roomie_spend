# Technical Design Document

## Overview

The Add Expense Redesign feature fundamentally changes the user flow for creating expenses in RoomieSpend. Instead of the current multi-step process that opens member selection first, the redesigned flow directly opens a comprehensive Add Expense page when the user taps the + button. This page consolidates all expense entry functionality including member selection, multi-bill support, category management, split configuration, payer selection, and image attachments into a single, intuitive interface.

### Goals

- **Streamlined UX**: Reduce friction by presenting all expense options on one screen
- **Feature Completeness**: Support advanced expense scenarios (multi-payer, item-wise splits, multiple bills)
- **Firebase Integration**: Persist expenses to Firestore with proper data structure
- **Architecture Consistency**: Maintain existing Riverpod patterns and clean architecture
- **Material 3 Compliance**: Follow Material Design 3 guidelines for modern Android UI

### Non-Goals (Phase 1)

- OCR bill scanning implementation (placeholder only)
- Partner logo payment integration (UI-only display)
- Custom category Firebase persistence (dialog only)
- Recurring expense functionality
- Offline-first data synchronization

## Architecture

### High-Level Component Structure

```
Add Expense Flow
│
├── Navigation Layer
│   └── FloatingActionButton (Group Details Screen)
│       └── Navigator.push → AddExpensePage
│
├── Presentation Layer (UI)
│   ├── AddExpensePage (Main Screen)
│   ├── MemberSelectionBottomSheet
│   ├── CategoryBottomSheet
│   ├── PaidByBottomSheet (Single/Multi Payer)
│   ├── SplitBottomSheet (Equal/Unequal/Item Wise)
│   └── ImagePickerDialog
│
├── State Management Layer (Riverpod)
│   ├── AddExpenseProvider (Main State)
│   ├── MemberSelectionProvider
│   ├── SplitConfigurationProvider
│   └── FormValidationProvider
│
├── Business Logic Layer
│   ├── SplitCalculator (Equal/Unequal/Item Wise logic)
│   ├── ExpenseValidator (Form validation rules)
│   └── BillTabManager (Multi-bill state)
│
└── Data Layer
    ├── ExpenseFirestoreService (Firebase operations)
    └── Enhanced ExpenseModel (Extended data structure)
```


### Navigation Flow

```
GroupDetailsScreen
    ↓ (FAB or "Add Expense" button tap)
AddExpensePage
    ├→ MemberSelectionBottomSheet (on "Add Friends" tap)
    ├→ CategoryBottomSheet (on category field tap)
    ├→ PaidByBottomSheet (on "Paid By" field tap)
    ├→ SplitBottomSheet (on "Unequally" or "Item Wise" tab tap)
    ├→ CustomCategoryDialog (on "Add Custom" in Category sheet)
    └→ ImagePicker / ScanBillPlaceholder (on image/scan card tap)
    ↓ (Save button tap)
Firebase Firestore (expense saved)
    ↓ (Success callback)
GroupDetailsScreen (Navigator.pop with refresh)
```

### State Management Architecture

The feature uses Riverpod's `NotifierProvider` pattern to maintain consistency with the existing codebase. State is organized into specialized notifiers:

1. **AddExpenseNotifier**: Main form state (description, amount, date, category)
2. **MemberSelectionNotifier**: Selected members for expense
3. **PayerConfigNotifier**: Single or multi-payer configuration
4. **SplitConfigNotifier**: Split type and member allocations
5. **BillTabNotifier**: Multi-bill tab management
6. **ValidationNotifier**: Real-time form validation state

This separation follows the Single Responsibility Principle and enables independent testing of each concern.

## Components and Interfaces

### 1. AddExpensePage (Main Screen)

**Responsibility**: Root UI component orchestrating all expense entry sub-components

**Key Properties**:
- `groupId: String` - Current group context
- `groupName: String` - Display in top badge
- `initialDate: DateTime` - Default to current date

**UI Structure**:

```dart
Scaffold(
  appBar: AppBar(
    leading: BackButton,
    title: "Add Expense",
    actions: [CurrentRoomBadge(groupName)],
  ),
  body: SingleChildScrollView(
    child: Column(
      children: [
        MemberAvatarRow(selectedMembers),
        BillTabsRow(tabs, activeTab),
        PartnerLogosRow(logos),
        Divider("OR"),
        ExpenseFormSection(
          categoryField,
          descriptionField,
          priceField,
          paidByField,
          splitConfigSection,
          imageAttachmentCards,
          datePickerCard,
        ),
      ],
    ),
  ),
  bottomNavigationBar: SaveButtonBar(isValid, onSave),
)
```

**Validation Logic**:
- Amount > 0
- At least one member selected for split
- Payer(s) selected
- Split amounts equal expense amount

### 2. MemberSelectionBottomSheet

**Responsibility**: Display available group members for selection/deselection

**Data Source**: `groupDetailProvider(groupId)` → `GroupModel.members`

**UI Pattern**: Bottom sheet with member list, checkboxes, and "Done" button

**State Mutations**:
- Add member: `memberSelectionNotifier.addMember(userId)`
- Remove member: `memberSelectionNotifier.removeMember(userId)`

**Validation**: Minimum 1 member required

### 3. CategoryBottomSheet

**Responsibility**: Display predefined categories with icons and custom category option


**Categories List**:
```dart
enum ExpenseCategory {
  food(icon: Icons.restaurant, label: "Food"),
  groceries(icon: Icons.shopping_cart, label: "Groceries"),
  travel(icon: Icons.directions_car, label: "Travel"),
  stay(icon: Icons.hotel, label: "Stay"),
  bills(icon: Icons.receipt, label: "Bills"),
  subscription(icon: Icons.subscriptions, label: "Subscription"),
  shopping(icon: Icons.shopping_bag, label: "Shopping"),
  gifts(icon: Icons.card_giftcard, label: "Gifts"),
  drinks(icon: Icons.local_bar, label: "Drinks"),
  fuel(icon: Icons.local_gas_station, label: "Fuel"),
  udhaar(icon: Icons.handshake, label: "Udhaar (Debt)"),
  health(icon: Icons.health_and_safety, label: "Health"),
  entertainment(icon: Icons.movie, label: "Entertainment"),
  misc(icon: Icons.more_horiz, label: "Misc."),
  custom(icon: Icons.add, label: "Add Custom"),
}
```

**Custom Category Flow** (Phase 1):
- Tap "Add Custom" → Open dialog with text field
- Enter name → Save locally to state (no Firebase persistence)
- Display custom category in category field

### 4. PaidByBottomSheet

**Responsibility**: Configure who paid for the expense (single or multiple payers)

**Tabs**: Single Payer | Multi Payer

**Single Payer Mode**:
- Display all selected members as radio options
- Select one member as sole payer
- Update `paidByField` with member name

**Multi Payer Mode**:

- Display all selected members with amount input fields
- Show "People Selected: X" and "Remaining Amount: ₹Y"
- Real-time calculation: `remaining = expenseAmount - sum(payerAmounts)`
- Validation: Enable "Done" only when `remaining == 0`
- Update `paidByField` to "Multiple Payers"

**Data Structure**:
```dart
sealed class PayerConfig {
  const PayerConfig();
}

class SinglePayer extends PayerConfig {
  final String userId;
  final String userName;
  final double amount; // Always equal to expense amount
  const SinglePayer(this.userId, this.userName, this.amount);
}

class MultiPayer extends PayerConfig {
  final Map<String, double> payerAmounts; // userId -> amount paid
  const MultiPayer(this.payerAmounts);
  
  double get total => payerAmounts.values.fold(0.0, (a, b) => a + b);
  bool isValid(double expenseAmount) => (total - expenseAmount).abs() < 0.01;
}
```

### 5. SplitBottomSheet

**Responsibility**: Configure how expense is split among members

**Tabs**: Equally | Unequally | Item Wise

**Equally Tab** (in main AddExpensePage):
- Display "Split Among" with member chips
- Tap member to toggle inclusion in split
- Auto-calculate equal shares: `share = amount / selectedCount`
- Handle rounding: adjust last member's share if needed

**Unequally Tab → Bottom Sheet with Sub-tabs**: By Amount | By Shares


**By Amount**:
- Input exact amount for each member
- Show remaining amount in real-time
- Validation: `sum(amounts) == expenseAmount`

**By Shares**:
- Input share count for each member (integers)
- Auto-calculate proportional amounts: `amount = (share / totalShares) * expenseAmount`
- Display calculated amounts next to share inputs

**Item Wise Tab → Bottom Sheet**:
- Show "Remaining ₹X / Y" at top
- Display item cards with: description, quantity, price, member chips
- "Split All Equally" button distributes remaining amount across all items
- "Add More Item" button creates new item entry
- Validation: `sum(itemPrices) == expenseAmount` and each item has at least one member

**Data Structure**:
```dart
sealed class SplitConfig {
  const SplitConfig();
}

class EqualSplit extends SplitConfig {
  final List<String> memberIds;
  const EqualSplit(this.memberIds);
  
  Map<String, double> calculateAmounts(double total) {
    final share = total / memberIds.length;
    final result = {for (var id in memberIds) id: share};
    // Handle rounding: adjust last member
    final sum = result.values.fold(0.0, (a, b) => a + b);
    if ((sum - total).abs() > 0.01) {
      result[memberIds.last] = result[memberIds.last]! + (total - sum);
    }
    return result;
  }
}

class UnequalSplitByAmount extends SplitConfig {
  final Map<String, double> amounts; // userId -> amount
  const UnequalSplitByAmount(this.amounts);
}

class UnequalSplitByShares extends SplitConfig {
  final Map<String, int> shares; // userId -> share count
  const UnequalSplitByShares(this.shares);
  
  Map<String, double> calculateAmounts(double total) {
    final totalShares = shares.values.fold(0, (a, b) => a + b);
    return shares.map((id, share) => 
      MapEntry(id, (share / totalShares) * total)
    );
  }
}

class ItemWiseSplit extends SplitConfig {
  final List<SplitItem> items;
  const ItemWiseSplit(this.items);
  
  Map<String, double> calculateAmounts() {
    final result = <String, double>{};
    for (final item in items) {
      final sharePerPerson = item.totalPrice / item.memberIds.length;
      for (final memberId in item.memberIds) {
        result[memberId] = (result[memberId] ?? 0) + sharePerPerson;
      }
    }
    return result;
  }
}

class SplitItem {
  final String description;
  final int quantity;
  final double pricePerUnit;
  final List<String> memberIds;
  
  double get totalPrice => quantity * pricePerUnit;
}
```


### 6. Bill Tab Management

**Responsibility**: Handle multiple bills within one expense entry

**Initial State**: Single "Bill 1" tab visible

**Add Bill Flow**:
- Tap "+ Add Bill" button
- Create new tab "Bill 2", "Bill 3", etc.
- Switch to new tab automatically
- Each tab maintains independent state for all form fields

**Tab Switching**:
- Save current tab state before switching
- Load target tab state
- Validate each tab independently before final save

**Data Structure**:
```dart
class BillTabState {
  final String tabId;
  final String description;
  final double amount;
  final String category;
  final PayerConfig payerConfig;
  final SplitConfig splitConfig;
  final List<String> selectedMembers;
  final List<String> imageUrls;
  final DateTime date;
  
  bool get isValid => 
    amount > 0 && 
    selectedMembers.isNotEmpty && 
    payerConfig.isValid() &&
    splitConfig.isValid(amount);
}

class MultiBillState {
  final List<BillTabState> tabs;
  final int activeTabIndex;
  
  bool get canSave => tabs.every((tab) => tab.isValid);
}
```

### 7. Image Attachment and Bill Scanning

**Add Image Flow**:
- Tap "Add Image" card
- Show bottom sheet with options: Camera | Gallery
- Use `image_picker` package to select images
- Support multiple image selection
- Display image thumbnails with remove button


**Scan Bill Flow** (Phase 1 - Placeholder):
- Tap "Scan Bill" card
- Navigate to placeholder screen with "Coming Soon" message
- No OCR implementation in Phase 1

**Image Upload to Firebase Storage**:
```dart
Future<List<String>> uploadExpenseImages(
  String groupId, 
  String expenseId, 
  List<XFile> images
) async {
  final storage = FirebaseStorage.instance;
  final urls = <String>[];
  
  for (var i = 0; i < images.length; i++) {
    final ref = storage.ref(
      'groups/$groupId/expenses/$expenseId/image_$i.jpg'
    );
    await ref.putFile(File(images[i].path));
    final url = await ref.getDownloadURL();
    urls.add(url);
  }
  
  return urls;
}
```

### 8. Partner Logos Display

**Logos**: PhonePe, Google Pay, Paytm, Uber, Swiggy, Zomato, Zepto, Blinkit

**Implementation**:
- Horizontal scrollable row
- Each logo as `Image.asset` or SVG
- Visual-only in Phase 1 (no tap handlers)
- Future phases: integrate payment/receipt import

**UI Spec**:
- Logo size: 56x56 dp
- Padding: 8 dp between logos
- Container: Rounded corners (12 dp), light background

## Data Models

### Enhanced ExpenseModel

The existing `ExpenseModel` needs extension to support the new features:

```dart
class EnhancedExpenseModel {
  final String id;
  final String groupId;
  final String description;
  final double amount;
  final String category;
  
  // Enhanced payer configuration
  final PayerType payerType; // single | multi
  final String? singlePayerId;
  final String? singlePayerName;
  final Map<String, double>? multiPayerAmounts;
  
  // Enhanced split configuration
  final SplitType splitType; // equal | unequalAmount | unequalShares | itemWise
  final List<String> splitAmongIds;
  final Map<String, double>? unequalAmounts;
  final Map<String, int>? unequalShares;
  final List<Map<String, dynamic>>? itemWiseSplits;
  
  // Multi-bill support
  final int? billNumber; // null for single bill, 1-n for multi
  final String? parentExpenseId; // Groups bills together
  
  // Image attachments
  final List<String> imageUrls;
  
  // Metadata
  final DateTime expenseDate;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Existing fields preserved
  final String notes;
  final String roomId;
}
```


### Firestore Schema

**Collection Path**: `groups/{groupId}/expenses/{expenseId}`

**Document Structure**:
```json
{
  "description": "Team lunch",
  "amount": 1200.50,
  "category": "food",
  
  "payerType": "multi",
  "singlePayerId": null,
  "singlePayerName": null,
  "multiPayerAmounts": {
    "userId1": 600.25,
    "userId2": 600.25
  },
  
  "splitType": "unequalAmount",
  "splitAmongIds": ["userId1", "userId2", "userId3"],
  "unequalAmounts": {
    "userId1": 400.0,
    "userId2": 400.0,
    "userId3": 400.50
  },
  "unequalShares": null,
  "itemWiseSplits": null,
  
  "billNumber": 1,
  "parentExpenseId": null,
  
  "imageUrls": [
    "https://storage.googleapis.com/.../image_0.jpg",
    "https://storage.googleapis.com/.../image_1.jpg"
  ],
  
  "expenseDate": "2025-01-15T18:30:00Z",
  "createdBy": "userId1",
  "createdAt": "2025-01-15T18:35:00Z",
  "updatedAt": "2025-01-15T18:35:00Z",
  
  "notes": "Office party",
  "roomId": "groupId"
}
```

### Migration Strategy

**Backward Compatibility**: Existing expenses use simple structure, new expenses use enhanced structure

**Read Logic**:
```dart
factory EnhancedExpenseModel.fromMap(Map<String, dynamic> map, String docId) {
  // Check if new fields exist
  final isEnhanced = map.containsKey('payerType');
  
  if (!isEnhanced) {
    // Legacy expense: map old fields to new structure
    return EnhancedExpenseModel(
      // ... map legacy 'paidBy' to singlePayerId
      // ... map legacy 'splitAmong' to equal split
    );
  }
  
  // New enhanced expense
  return EnhancedExpenseModel(/* parse all fields */);
}
```


## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property Reflection

After analyzing all acceptance criteria, I identified the following properties that are suitable for property-based testing. Several redundancies were eliminated:

**Combined Properties**:
- Multi-payer remaining calculation (10.4), validation (10.5, 10.6) → Combined into Property 1
- Unequal split remaining calculation (12.4), validation (12.5, 12.6) → Combined into Property 2  
- Item-wise remaining calculation (14.9), validation (14.10, 14.11) → Combined into Property 3
- Form validation (21.4, 21.5, 21.6) → Covered by validation properties above

**Eliminated Redundancies**:
- Price validation error display (8.4) and button disable (8.5) test the same condition → Covered by edge case tests
- Equal split decimal handling (11.5) and rounding adjustment (11.6) are part of the same calculation → Combined into Property 5

### Property 1: Multi-Payer Amount Validation

*For any* expense amount and any distribution of payer amounts across selected members, the remaining amount SHALL equal the expense amount minus the sum of all payer amounts, and the submit button SHALL be enabled if and only if the remaining amount equals zero.

**Validates: Requirements 10.4, 10.5, 10.6**

### Property 2: Unequal Split Amount Validation

*For any* expense amount and any distribution of split amounts across selected members, the remaining amount SHALL equal the expense amount minus the sum of all member split amounts, and the submit button SHALL be enabled if and only if the remaining amount equals zero.

**Validates: Requirements 12.4, 12.5, 12.6**


### Property 3: Item-Wise Split Amount Validation

*For any* expense amount and any collection of items with quantities, prices, and member assignments, the remaining amount SHALL equal the expense amount minus the sum of all item totals (quantity × price), and the Done button SHALL be enabled if and only if the remaining amount equals zero.

**Validates: Requirements 14.9, 14.10, 14.11**

### Property 4: Share-Based Proportional Calculation

*For any* expense amount and any distribution of shares across selected members, each member's calculated amount SHALL equal their share divided by the total shares multiplied by the expense amount: `memberAmount = (memberShare / totalShares) × expenseAmount`.

**Validates: Requirements 13.2**

### Property 5: Equal Split with Rounding Adjustment

*For any* expense amount and any number of selected members, when splitting equally, the sum of all member amounts SHALL exactly equal the expense amount, with rounding discrepancies adjusted by modifying the last member's share.

**Validates: Requirements 11.5, 11.6**

### Property 6: Equal Split Equivalence with Splitwise

*For any* expense amount and any set of selected members, the equal split calculation SHALL produce amounts that match the Splitwise equal split algorithm output.

**Validates: Requirements 11.7**

### Property 7: Decimal Price Input Acceptance

*For any* valid decimal number greater than zero, the price field SHALL accept the input and not display a validation error.

**Validates: Requirements 8.3**

### Property 8: Large Number Formatting

*For any* number greater than or equal to 1000, the price field SHALL format the display with proper thousand separators according to the INR locale convention.

**Validates: Requirements 8.6**


### Property 9: Item-Wise Equal Distribution

*For any* remaining amount and any number of items, when "Split All Equally" is triggered, each item SHALL receive an equal share of the remaining amount, with rounding adjustments ensuring the sum equals the remaining amount exactly.

**Validates: Requirements 14.12**

### Property 10: Firebase Save for Valid Expenses

*For any* expense that passes all validation rules (amount > 0, members selected, payer configured, split amounts equal expense amount), the system SHALL successfully save the expense to Firestore with the correct structure and all fields preserved.

**Validates: Requirements 17.4**

### Property 11: Firebase No-Save for Invalid Expenses

*For any* expense that fails any validation rule (amount ≤ 0, no members selected, no payer, split amounts ≠ expense amount), the system SHALL NOT initiate a Firestore save operation.

**Validates: Requirements 17.3**

### Property 12: Form Validation State Consistency

*For any* form state, the save button SHALL be enabled if and only if all validation rules pass (amount > 0, at least one member selected, payer configured, split amounts equal expense amount).

**Validates: Requirements 21.5, 21.6**

## Error Handling

### Validation Errors

**Client-Side Validation** (immediate feedback):
- **Invalid Amount**: Display "Amount must be greater than zero" when amount ≤ 0
- **No Members**: Display "Please select members to split with" when member list empty
- **No Payer**: Display "Please select who paid" when payer not configured
- **Split Mismatch**: Display "Split amounts must equal expense amount" when totals don't match

**Validation Timing**:
- Real-time validation as user types/selects
- Final validation on save button tap
- Disable save button when any validation fails


### Firebase Errors

**Network Errors**:
```dart
try {
  await expenseService.saveExpense(expense);
} on FirebaseException catch (e) {
  if (e.code == 'unavailable') {
    showSnackbar('Network error. Please check your connection.');
  } else if (e.code == 'permission-denied') {
    showSnackbar('Permission denied. Please contact support.');
  } else {
    showSnackbar('Failed to save expense: ${e.message}');
  }
}
```

**Offline Handling**:
- Show offline indicator when network unavailable
- Queue expense locally (future enhancement)
- Display clear error message to user
- Prevent navigation until save confirmed

**Duplicate Submission Prevention**:
- Disable save button immediately on tap
- Show loading indicator during save
- Use debouncing to prevent rapid taps
- Only re-enable button if save fails

### Data Integrity Errors

**Stale Data Handling**:
- Refresh group members before save
- Validate payer and split members still in group
- Handle member removal during expense creation

**Concurrent Modification**:
- Use Firestore transactions for balance updates
- Detect and handle concurrent expense additions
- Refresh group data after successful save

## Testing Strategy

### Unit Tests

**Component Tests** (Example-Based):
- UI element presence and layout verification
- Navigation flow between screens and bottom sheets
- Button state changes based on validation
- Category selection and custom category dialog
- Bill tab creation and switching
- Member avatar display and removal

**Business Logic Tests** (Example-Based):
- Specific validation scenarios (empty amount, no members, no payer)
- Edge cases (zero amount, negative amount, single member)
- Date picker past/future date restrictions
- Image picker and camera integration (mocked)


### Property-Based Tests

**PBT Library**: Use `flutter_test` with the `test` package's property-based testing support, or integrate `fast_check` Dart equivalent (e.g., `check` package).

**Test Configuration**: Minimum 100 iterations per property test.

**Property Test Suite**:

1. **Multi-Payer Calculation Property**
   ```dart
   // Feature: add-expense-redesign, Property 1
   test('Property 1: Multi-payer amount validation', () {
     check(
       that: <double, Map<String, double>>()[
         (amount, payerAmounts) {
           final remaining = amount - payerAmounts.values.sum;
           final isValid = (remaining.abs() < 0.01);
           return MultiPayerValidator.validate(amount, payerAmounts) == isValid;
         }
       ],
       minTestCases: 100,
     );
   });
   ```

2. **Unequal Split Calculation Property**
   ```dart
   // Feature: add-expense-redesign, Property 2
   test('Property 2: Unequal split amount validation', () {
     check(
       that: <double, Map<String, double>>()[
         (amount, splitAmounts) {
           final remaining = amount - splitAmounts.values.sum;
           final isValid = (remaining.abs() < 0.01);
           return UnequalSplitValidator.validate(amount, splitAmounts) == isValid;
         }
       ],
       minTestCases: 100,
     );
   });
   ```

3. **Item-Wise Split Property**
   ```dart
   // Feature: add-expense-redesign, Property 3
   test('Property 3: Item-wise split amount validation', () {
     check(
       that: <double, List<SplitItem>>()[
         (amount, items) {
           final itemsTotal = items.map((i) => i.totalPrice).sum;
           final remaining = amount - itemsTotal;
           final isValid = (remaining.abs() < 0.01);
           return ItemWiseSplitValidator.validate(amount, items) == isValid;
         }
       ],
       minTestCases: 100,
     );
   });
   ```

4. **Share-Based Calculation Property**
   ```dart
   // Feature: add-expense-redesign, Property 4
   test('Property 4: Share-based proportional calculation', () {
     check(
       that: <double, Map<String, int>>()[
         (amount, shares) {
           final totalShares = shares.values.sum;
           final calculated = ShareCalculator.calculate(amount, shares);
           return shares.keys.every((id) =>
             (calculated[id]! - (shares[id]! / totalShares) * amount).abs() < 0.01
           );
         }
       ],
       minTestCases: 100,
     );
   });
   ```

5. **Equal Split with Rounding Property**
   ```dart
   // Feature: add-expense-redesign, Property 5
   test('Property 5: Equal split with rounding adjustment', () {
     check(
       that: <double, List<String>>()[
         (amount, memberIds) {
           if (memberIds.isEmpty) return true;
           final splits = EqualSplitCalculator.calculate(amount, memberIds);
           final total = splits.values.sum;
           return (total - amount).abs() < 0.01;
         }
       ],
       minTestCases: 100,
     );
   });
   ```

6-12. **Additional Property Tests**: Similar structure for Properties 6-12

### Integration Tests

**Firebase Integration** (Mocked):
- Save expense with valid data → verify Firestore document created
- Save expense with invalid data → verify no Firestore call
- Network error scenario → verify error message displayed
- Offline scenario → verify graceful handling

**Navigation Integration**:
- Complete expense flow → verify navigation back to group details
- Group balance update → verify balance incremented correctly
- Activity log creation → verify activity entry created

**State Management Integration**:
- Provider state updates across screens
- Bottom sheet state isolation
- Multi-bill tab state persistence

### Widget Tests

**Screen-Level Tests**:
- AddExpensePage renders correctly
- Member selection bottom sheet interaction
- Category selection bottom sheet interaction
- Payer configuration bottom sheet (single/multi tabs)
- Split configuration bottom sheet (equal/unequal/item-wise tabs)

**Component-Level Tests**:
- MemberAvatarRow displays selected members
- BillTabsRow creates and switches tabs
- PartnerLogosRow displays all logos
- ExpenseFormSection validates inputs
- SaveButtonBar enables/disables correctly

### Test Coverage Goals

- **Unit Tests**: 80%+ coverage for business logic
- **Property Tests**: 100% coverage of correctness properties
- **Widget Tests**: 70%+ coverage for UI components
- **Integration Tests**: Critical paths (save, validation, navigation)


## Implementation Phases

### Phase 1: Core Navigation and Basic Form

**Deliverables**:
- Navigation from + button to AddExpensePage
- Basic form layout (description, amount, date, category)
- Member selection bottom sheet
- Single payer configuration
- Equal split calculation
- Firebase save for simple expenses
- Form validation

**Estimated Effort**: 2-3 days

### Phase 2: Advanced Split Options

**Deliverables**:
- Multi-payer configuration
- Unequal split by amount
- Unequal split by shares
- Split validation and real-time calculations
- Enhanced ExpenseModel for complex splits

**Estimated Effort**: 2-3 days

### Phase 3: Item-Wise Split and Multi-Bill

**Deliverables**:
- Item-wise split bottom sheet
- Item management (add, remove, assign members)
- Item split validation
- Bill tabs interface
- Multi-bill state management

**Estimated Effort**: 3-4 days

### Phase 4: Image and UI Polish

**Deliverables**:
- Image attachment (camera/gallery)
- Firebase Storage image upload
- Partner logos display
- Scan bill placeholder
- Material 3 design refinements
- Animations and transitions

**Estimated Effort**: 2-3 days

### Phase 5: Testing and Bug Fixes

**Deliverables**:
- Property-based test suite (100+ iterations per property)
- Widget tests for all components
- Integration tests for Firebase operations
- Bug fixes and edge case handling
- Performance optimization

**Estimated Effort**: 3-4 days

**Total Estimated Effort**: 12-17 days

## Technical Considerations

### Performance Optimization

**Real-Time Calculations**:
- Debounce input fields to reduce calculation frequency
- Memoize split calculations when inputs unchanged
- Use `const` constructors for immutable widgets

**Large Member Lists**:
- Use `ListView.builder` for member lists in bottom sheets
- Implement virtual scrolling for 50+ members
- Cache member data in provider

**Image Handling**:
- Compress images before upload (target: 1MB max per image)
- Use thumbnail generation for preview
- Lazy load images in expense list
- Implement image caching strategy


### State Management Best Practices

**Provider Scope**:
- Use `autoDispose` for screen-level providers
- Persist form state during bottom sheet navigation
- Clear state on successful save or screen exit

**State Immutability**:
- Use immutable data classes for all state models
- Use `copyWith` methods for state updates
- Avoid direct mutation of collections

**State Persistence**:
```dart
class AddExpenseNotifier extends AutoDisposeNotifier<AddExpenseState> {
  @override
  AddExpenseState build() {
    // Listen for app lifecycle changes
    ref.listen(appLifecycleProvider, (_, lifecycle) {
      if (lifecycle == AppLifecycle.paused) {
        _saveFormDraft();
      }
    });
    
    return _loadFormDraft() ?? AddExpenseState.initial();
  }
  
  void _saveFormDraft() {
    // Save to local storage for crash recovery
  }
  
  AddExpenseState? _loadFormDraft() {
    // Load from local storage if exists
  }
}
```

### Accessibility

**Screen Reader Support**:
- Add semantic labels to all interactive elements
- Provide context for bottom sheets (e.g., "Select members for expense")
- Announce validation errors with `Semantics` widget

**Input Accessibility**:
- Large touch targets (minimum 48x48 dp)
- High contrast text and icons
- Support for system font scaling

**Navigation Accessibility**:
- Logical tab order for keyboard navigation
- Focus management when opening/closing bottom sheets
- Escape key to dismiss bottom sheets

### Security Considerations

**Data Validation**:
- Server-side validation for all expense data
- Firestore security rules to enforce data integrity
- SQL injection prevention in Firestore queries (use parameterized queries)

**User Authorization**:
- Verify user is group member before save
- Check write permissions in Firestore rules
- Validate expense creator matches authenticated user

**Firestore Security Rules**:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /groups/{groupId}/expenses/{expenseId} {
      allow create: if request.auth != null 
        && request.auth.uid in get(/databases/$(database)/documents/groups/$(groupId)).data.members
        && request.resource.data.createdBy == request.auth.uid
        && request.resource.data.amount > 0
        && request.resource.data.splitAmongIds.size() > 0;
      
      allow read: if request.auth != null 
        && request.auth.uid in get(/databases/$(database)/documents/groups/$(groupId)).data.members;
      
      allow update, delete: if request.auth != null 
        && request.auth.uid == resource.data.createdBy;
    }
  }
}
```

### Monitoring and Analytics

**Key Metrics**:
- Expense creation success rate
- Average time to create expense
- Split type distribution (equal vs unequal vs item-wise)
- Multi-bill usage frequency
- Image attachment frequency
- Error rates (validation errors, Firebase errors)

**Analytics Events**:
```dart
analytics.logEvent(
  name: 'expense_created',
  parameters: {
    'group_id': groupId,
    'split_type': splitType.name,
    'payer_type': payerType.name,
    'member_count': memberCount,
    'has_images': imageCount > 0,
    'bill_count': billCount,
  },
);
```

**Error Tracking**:
- Log Firebase exceptions with context
- Track validation failures by type
- Monitor form abandonment rate

## Dependencies

### New Flutter Packages

```yaml
dependencies:
  # Existing dependencies (preserved)
  flutter_riverpod: ^2.5.1
  cloud_firestore: ^5.4.4
  firebase_storage: ^12.3.4
  
  # New dependencies for this feature
  image_picker: ^1.1.2        # Image selection from camera/gallery
  cached_network_image: ^3.4.1 # Efficient image loading and caching
  intl: ^0.19.0               # Number formatting with locale support
  
  # Optional for property-based testing
  # check: ^0.2.0             # Property-based testing (if available)

dev_dependencies:
  flutter_test:
    sdk: flutter
  mockito: ^5.4.4             # Mocking for unit tests
  integration_test:
    sdk: flutter
```

### External Services

- **Firebase Firestore**: Expense data persistence
- **Firebase Storage**: Image storage
- **Firebase Authentication**: User context for expense creation

## Risk Analysis

### Technical Risks

**Risk 1: Complex State Management**
- **Impact**: High - Multiple bottom sheets with interdependent state
- **Mitigation**: 
  - Use isolated notifiers for each concern
  - Implement comprehensive state tests
  - Document state flow diagrams

**Risk 2: Split Calculation Precision**
- **Impact**: Medium - Rounding errors could cause balance discrepancies
- **Mitigation**:
  - Use property-based tests with 100+ iterations
  - Implement Splitwise-equivalent algorithm
  - Add comprehensive rounding adjustment logic

**Risk 3: Firebase Offline Scenarios**
- **Impact**: Medium - Users may create expenses offline
- **Mitigation**:
  - Implement clear offline indicators
  - Queue mechanism for future enhancement
  - Comprehensive error messaging

**Risk 4: Image Upload Performance**
- **Impact**: Medium - Large images could block UI
- **Mitigation**:
  - Compress images before upload
  - Show progress indicator during upload
  - Upload in background, save expense data first

### UX Risks

**Risk 1: Complex UI Overwhelming Users**
- **Impact**: Medium - Too many options could confuse users
- **Mitigation**:
  - Use progressive disclosure (hide advanced options initially)
  - Provide helpful tooltips and examples
  - Default to simplest flow (equal split, single payer)

**Risk 2: Form Abandonment**
- **Impact**: Medium - Users may exit without saving
- **Mitigation**:
  - Save draft state for crash recovery
  - Show confirmation dialog on back button
  - Minimize required fields

## Future Enhancements

### Phase 2 Features (Post-MVP)

1. **Custom Category Persistence**: Save custom categories to Firestore user profile
2. **OCR Bill Scanning**: Implement ML Kit text recognition to extract expense details from bill photos
3. **Partner Logo Integration**: Connect with payment apps (PhonePe, GPay) for receipt import
4. **Recurring Expenses**: Create template expenses that repeat on schedule
5. **Expense Templates**: Save common expense configurations as templates
6. **Split History**: Show previous split configurations for quick reuse
7. **Currency Conversion**: Support multi-currency expenses with auto-conversion
8. **Offline Queue**: Persist expenses locally when offline, sync when online
9. **Bulk Expense Entry**: Create multiple expenses in one session
10. **Voice Input**: Add expenses using voice commands

### Technical Debt Considerations

- **Refactor ExpenseModel**: Current model is simple, new model is complex - consider migration strategy
- **Provider Consolidation**: May have too many granular providers - evaluate if consolidation makes sense
- **State Persistence Strategy**: Current draft save is basic - consider more robust solution
- **Test Coverage**: Aim for 80%+ but balance with development speed

## Conclusion

The Add Expense Redesign feature represents a significant UX improvement for RoomieSpend. By consolidating all expense entry functionality into a single, comprehensive screen, users can create complex expenses with multi-payer, advanced split configurations, and image attachments in a streamlined flow.

The design maintains architectural consistency with existing Riverpod patterns while introducing robust state management for complex interactions. Property-based testing ensures correctness of critical calculation logic, and comprehensive error handling provides a smooth user experience even in failure scenarios.

The phased implementation approach allows for incremental delivery of value while managing complexity. The design is extensible to support future enhancements like OCR scanning, partner integrations, and recurring expenses.

**Key Success Metrics**:
- 90%+ expense creation success rate
- Average time to create expense < 60 seconds
- User satisfaction rating > 4.5/5
- Zero balance calculation errors in production

