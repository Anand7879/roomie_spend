# Implementation Plan: Add Expense Redesign

## Overview

This implementation plan breaks down the Add Expense Redesign feature into discrete coding tasks following the 5-phase approach outlined in the design document. The feature redesigns the expense creation flow to open directly to a comprehensive Add Expense page instead of member selection first, supporting advanced functionality like multi-payer, unequal splits, item-wise splits, and multi-bill support.

## Tasks

- [ ] 1. Set up data models and core types
  - [-] 1.1 Create sealed class hierarchy for PayerConfig (SinglePayer, MultiPayer)
    - Define `PayerConfig` sealed class with `SinglePayer` and `MultiPayer` subclasses
    - Implement validation methods (`isValid()`) for each payer type
    - Add JSON serialization methods (`toMap()`, `fromMap()`)
    - _Requirements: 9.5, 9.6, 10.1, 10.6_

  - [-] 1.2 Create sealed class hierarchy for SplitConfig (EqualSplit, UnequalSplitByAmount, UnequalSplitByShares, ItemWiseSplit)
    - Define `SplitConfig` sealed class with four subclasses
    - Implement `calculateAmounts()` method for each split type
    - Add `SplitItem` class for item-wise splits with quantity, price, and member fields
    - Include validation and JSON serialization
    - _Requirements: 11.1, 11.3, 12.1, 13.1, 14.1_

  - [ ] 1.3 Create ExpenseCategory enum with icons and labels
    - Define `ExpenseCategory` enum with all categories from requirements
    - Map each category to Material icon and display label
    - Include custom category support
    - _Requirements: 6.4, 6.5_

  - [~] 1.4 Extend ExpenseModel to EnhancedExpenseModel
    - Add fields: `payerType`, `singlePayerId`, `singlePayerName`, `multiPayerAmounts`
    - Add fields: `splitType`, `splitAmongIds`, `unequalAmounts`, `unequalShares`, `itemWiseSplits`
    - Add fields: `billNumber`, `parentExpenseId`, `imageUrls`
    - Implement backward-compatible `fromMap()` factory for legacy expenses
    - Implement `toMap()` method for Firestore serialization
    - _Requirements: 17.2_

  - [ ]* 1.5 Write property test for equal split rounding adjustment
    - **Property 5: Equal Split with Rounding Adjustment**
    - **Validates: Requirements 11.5, 11.6**
    - Generate random expense amounts and member lists
    - Verify sum of split amounts exactly equals expense amount
    - Verify rounding discrepancy is adjusted in last member's share
    - Run minimum 100 iterations

- [ ] 2. Implement core state management providers
  - [~] 2.1 Create AddExpenseNotifier with Riverpod NotifierProvider
    - Manage form state: description, amount, date, category, notes
    - Implement methods: `updateDescription()`, `updateAmount()`, `updateCategory()`, `updateDate()`
    - Add debouncing for amount input field
    - _Requirements: 7.1, 7.3, 8.1, 8.2, 16.2_

  - [~] 2.2 Create MemberSelectionNotifier
    - Manage selected member IDs list
    - Implement `addMember()`, `removeMember()`, `clearMembers()` methods
    - Fetch member details from `groupDetailProvider`
    - _Requirements: 3.1, 3.2, 3.4, 3.5_

  - [~] 2.3 Create PayerConfigNotifier
    - Manage current `PayerConfig` (single or multi-payer)
    - Implement `setSinglePayer()`, `setMultiPayer()`, `updatePayerAmount()` methods
    - Calculate remaining amount for multi-payer mode
    - _Requirements: 9.2, 9.5, 10.1, 10.3, 10.4_

  - [~] 2.4 Create SplitConfigNotifier
    - Manage current `SplitConfig` (equal, unequal, item-wise)
    - Implement `setEqualSplit()`, `setUnequalByAmount()`, `setUnequalByShares()`, `setItemWise()` methods
    - Calculate member amounts for each split type
    - _Requirements: 11.2, 11.3, 12.7, 13.5, 14.9_

  - [~] 2.5 Create BillTabNotifier for multi-bill state management
    - Manage list of `BillTabState` objects
    - Implement `addBill()`, `switchTab()`, `removeBill()` methods
    - Persist and restore tab state when switching
    - _Requirements: 4.2, 4.3, 4.4, 4.5_

  - [~] 2.6 Create ValidationNotifier for form validation state
    - Aggregate validation from all form fields
    - Implement validation rules: amount > 0, members selected, payer configured, split amounts match
    - Expose `isValid` computed property
    - _Requirements: 21.1, 21.2, 21.3, 21.4, 21.5, 21.6_

  - [ ]* 2.7 Write property test for multi-payer amount validation
    - **Property 1: Multi-Payer Amount Validation**
    - **Validates: Requirements 10.4, 10.5, 10.6**
    - Generate random expense amounts and payer amount distributions
    - Verify remaining amount calculation is accurate
    - Verify submit button enabled only when remaining equals zero
    - Run minimum 100 iterations

  - [ ]* 2.8 Write property test for form validation state consistency
    - **Property 12: Form Validation State Consistency**
    - **Validates: Requirements 21.5, 21.6**
    - Generate random form states with various validation failures
    - Verify save button enabled if and only if all validation rules pass
    - Run minimum 100 iterations

- [ ] 3. Build AddExpensePage main screen and navigation
  - [~] 3.1 Create AddExpensePage widget with Scaffold layout
    - Implement `AppBar` with back button, "Add Expense" title, and current room badge
    - Set up `SingleChildScrollView` body structure
    - Add bottom `SaveButtonBar` that observes validation state
    - Wire navigation from GroupDetailsScreen FAB to AddExpensePage
    - _Requirements: 1.1, 2.1, 2.2, 2.3_

  - [~] 3.2 Create MemberAvatarRow widget
    - Display "Add Friends" avatar as first item
    - Display selected member avatars with names and remove buttons
    - Handle tap on "Add Friends" to open member selection
    - Handle tap on remove button to deselect member
    - _Requirements: 2.4, 3.1, 3.3, 3.4, 3.5_

  - [~] 3.3 Create BillTabsRow widget
    - Display active bill tab with visual distinction
    - Display "+ Add Bill" button
    - Handle tab switching
    - Handle new bill creation
    - _Requirements: 2.5, 4.1, 4.2, 4.3, 4.4, 4.5_

  - [~] 3.4 Create PartnerLogosRow widget
    - Display logos for PhonePe, Google Pay, Paytm, Uber, Swiggy, Zomato, Zepto, Blinkit
    - Implement horizontal scrollable row with proper sizing and padding
    - Include "OR" divider below logos
    - UI-only in this phase (no tap handlers)
    - _Requirements: 2.6, 2.7, 5.1, 5.2, 5.3, 5.4_

  - [~] 3.5 Create ExpenseFormSection widget
    - Add category field with dropdown appearance and tap handler
    - Add description text field with hint "Add a description"
    - Add price input field with ₹ symbol and numeric keyboard
    - Add "Paid By" field with tap handler
    - Add date picker card with default current date
    - _Requirements: 6.1, 6.2, 7.1, 7.2, 8.1, 8.2, 9.1, 16.1, 16.2_

  - [~] 3.6 Implement price field validation and formatting
    - Display validation error "Amount must be greater than zero" when amount ≤ 0
    - Disable save button when amount invalid
    - Format large numbers with INR thousand separators
    - Accept decimal values
    - _Requirements: 8.3, 8.4, 8.5, 8.6_

  - [ ]* 3.7 Write property test for decimal price input acceptance
    - **Property 7: Decimal Price Input Acceptance**
    - **Validates: Requirements 8.3**
    - Generate random valid decimal numbers > 0
    - Verify price field accepts input without validation error
    - Run minimum 100 iterations

  - [ ]* 3.8 Write property test for large number formatting
    - **Property 8: Large Number Formatting**
    - **Validates: Requirements 8.6**
    - Generate random numbers ≥ 1000
    - Verify display includes proper thousand separators per INR locale
    - Run minimum 100 iterations

- [~] 4. Checkpoint - Ensure basic form renders and validates
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 5. Implement member selection bottom sheet
  - [~] 5.1 Create MemberSelectionBottomSheet widget
    - Display all group members from `groupDetailProvider`
    - Show checkboxes for each member
    - Display "Done" button at bottom
    - Handle member selection/deselection
    - _Requirements: 3.2_

  - [~] 5.2 Integrate MemberSelectionBottomSheet with MemberSelectionNotifier
    - Update notifier when member selected/deselected
    - Close sheet on "Done" tap
    - Refresh MemberAvatarRow after selection changes
    - _Requirements: 3.4, 3.5, 3.6_

  - [ ]* 5.3 Write unit tests for MemberSelectionBottomSheet
    - Test member list displays all group members
    - Test checkbox state changes on tap
    - Test "Done" button closes sheet
    - Test minimum 1 member validation

- [ ] 6. Implement category selection bottom sheet
  - [~] 6.1 Create CategoryBottomSheet widget
    - Display all categories from `ExpenseCategory` enum
    - Show icon and label for each category
    - Include "Add Custom" option at end
    - Handle category selection and immediate sheet closure
    - _Requirements: 6.3, 6.4, 6.5, 6.6, 6.7_

  - [~] 6.2 Create CustomCategoryDialog widget
    - Display text field for custom category name
    - Save custom category to local state only (no Firebase in Phase 1)
    - Display custom category in category field after creation
    - _Requirements: 6.8, 6.9_

  - [ ]* 6.3 Write unit tests for CategoryBottomSheet
    - Test all categories display with correct icons
    - Test category selection updates form state
    - Test sheet closes immediately after selection
    - Test custom category dialog opens on "Add Custom" tap

- [ ] 7. Implement single payer selection
  - [~] 7.1 Create PaidByBottomSheet widget with tab structure
    - Display "Single Payer" and "Multi Payer" tabs
    - Implement tab switching UI
    - Set "Single Payer" as default tab
    - _Requirements: 9.2, 9.3, 10.1_

  - [~] 7.2 Implement SinglePayerTab widget
    - Display all selected members as radio options
    - Mark selected member with radio indicator
    - Deselect previous payer when new payer selected
    - Update "Paid By" field with selected payer's name on close
    - _Requirements: 9.4, 9.5, 9.6, 9.7_

  - [ ]* 7.3 Write unit tests for SinglePayerTab
    - Test all selected members display as radio options
    - Test only one payer can be selected at a time
    - Test "Paid By" field updates on sheet close

- [ ] 8. Implement equal split calculation
  - [~] 8.1 Implement EqualSplitCalculator
    - Calculate equal shares: `share = amount / memberCount`
    - Handle rounding by adjusting last member's share
    - Ensure sum of all shares exactly equals expense amount
    - _Requirements: 11.3, 11.5, 11.6, 11.7_

  - [~] 8.2 Create EqualSplitSection in AddExpensePage
    - Display "Split Among" label with member chips
    - Allow toggling members in/out of split
    - Display calculated amount card for each member
    - Update calculations when members or amount changes
    - _Requirements: 11.1, 11.2, 11.3, 11.4_

  - [ ]* 8.3 Write property test for equal split equivalence with Splitwise
    - **Property 6: Equal Split Equivalence with Splitwise**
    - **Validates: Requirements 11.7**
    - Generate random expense amounts and member sets
    - Compare output with Splitwise equal split algorithm
    - Verify exact match in calculated amounts
    - Run minimum 100 iterations

- [ ] 9. Implement basic Firebase save functionality
  - [~] 9.1 Create ExpenseFirestoreService
    - Implement `saveExpense()` method to save to `groups/{groupId}/expenses/{expenseId}`
    - Serialize `EnhancedExpenseModel` to Firestore document
    - Handle Firebase exceptions and network errors
    - _Requirements: 17.1, 17.4, 17.5, 17.6_

  - [~] 9.2 Implement save button handler in AddExpensePage
    - Validate all form fields before save
    - Block save if validation fails
    - Call `ExpenseFirestoreService.saveExpense()` on tap
    - Disable button and show loading indicator during save
    - Prevent duplicate submissions with debouncing
    - _Requirements: 17.3, 17.4, 18.6_

  - [~] 9.3 Implement post-save actions
    - Display success Snackbar on successful save
    - Navigate back to GroupDetailsScreen with `Navigator.pop()`
    - Trigger group balance and activity history updates
    - Refresh expenses list on GroupDetailsScreen
    - Display error Snackbar on save failure
    - _Requirements: 18.1, 18.2, 18.3, 18.4, 18.5_

  - [ ]* 9.4 Write property test for Firebase save with valid expenses
    - **Property 10: Firebase Save for Valid Expenses**
    - **Validates: Requirements 17.4**
    - Generate random valid expense data (amount > 0, members selected, payer set, splits balanced)
    - Verify Firestore document created with correct structure
    - Verify all fields preserved accurately
    - Run minimum 100 iterations (mocked Firebase)

  - [ ]* 9.5 Write property test for Firebase no-save with invalid expenses
    - **Property 11: Firebase No-Save for Invalid Expenses**
    - **Validates: Requirements 17.3**
    - Generate random invalid expense data (various validation failures)
    - Verify no Firestore save operation initiated
    - Run minimum 100 iterations (mocked Firebase)

- [~] 10. Checkpoint - Ensure basic expense creation flow works end-to-end
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 11. Implement multi-payer configuration
  - [~] 11.1 Implement MultiPayerTab widget
    - Display all selected members with amount input fields
    - Show "People Selected: X" count at bottom
    - Show "Remaining Amount: ₹Y" at bottom
    - Update remaining amount in real-time as amounts entered
    - _Requirements: 10.1, 10.2, 10.3, 10.4_

  - [~] 11.2 Implement multi-payer validation logic
    - Calculate remaining: `remaining = expenseAmount - sum(payerAmounts)`
    - Disable submit button when remaining ≠ 0
    - Enable submit button when remaining = 0
    - Update "Paid By" field to "Multiple Payers" on valid close
    - _Requirements: 10.4, 10.5, 10.6, 10.7_

  - [ ]* 11.3 Write unit tests for MultiPayerTab
    - Test all members display with amount fields
    - Test remaining amount updates in real-time
    - Test submit button disabled when amounts don't match
    - Test submit button enabled when amounts match exactly

- [ ] 12. Implement unequal split by amount
  - [~] 12.1 Create SplitBottomSheet widget with tab structure
    - Display "By Amount" and "By Shares" tabs
    - Implement tab switching UI
    - Set "By Amount" as default tab when unequal split selected
    - _Requirements: 12.1, 12.2_

  - [~] 12.2 Implement UnequalByAmountTab widget
    - Display amount input fields for each selected member
    - Show remaining amount in real-time
    - Display validation error when total exceeds expense amount
    - Enable submit button only when total equals expense amount
    - Save unequal split configuration on close
    - _Requirements: 12.3, 12.4, 12.5, 12.6, 12.7_

  - [ ]* 12.3 Write property test for unequal split amount validation
    - **Property 2: Unequal Split Amount Validation**
    - **Validates: Requirements 12.4, 12.5, 12.6**
    - Generate random expense amounts and split amount distributions
    - Verify remaining amount calculation is accurate
    - Verify submit button enabled only when remaining equals zero
    - Run minimum 100 iterations

- [ ] 13. Implement unequal split by shares
  - [~] 13.1 Implement UnequalBySharesTab widget
    - Display share input fields for each selected member
    - Calculate proportional amounts: `memberAmount = (memberShare / totalShares) × expenseAmount`
    - Display calculated amount next to share input
    - Show total remaining shares
    - Save share-based split configuration on close
    - _Requirements: 13.1, 13.2, 13.3, 13.4, 13.5_

  - [ ]* 13.2 Write property test for share-based proportional calculation
    - **Property 4: Share-Based Proportional Calculation**
    - **Validates: Requirements 13.2**
    - Generate random expense amounts and share distributions
    - Verify each member's amount equals their proportional share
    - Verify formula: `memberAmount = (memberShare / totalShares) × expenseAmount`
    - Run minimum 100 iterations

  - [ ]* 13.3 Write unit tests for UnequalBySharesTab
    - Test share inputs accept integer values
    - Test calculated amounts update when shares change
    - Test total shares displayed correctly

- [~] 14. Checkpoint - Ensure advanced split options work correctly
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 15. Implement item-wise split
  - [~] 15.1 Create ItemWiseSplitTab widget
    - Display "Remaining ₹X / Y" header showing unallocated amount
    - Display "Split All Equally" button at top
    - Display list of item cards
    - Display "Add More Item" button at bottom
    - _Requirements: 14.1, 14.2, 14.3, 14.7_

  - [~] 15.2 Create ItemCard widget
    - Display item description text field
    - Display quantity increase/decrease buttons with count
    - Display price input field
    - Display calculated total: `quantity × price`
    - Display delete button
    - Display member chips for member assignment
    - _Requirements: 14.4_

  - [~] 15.3 Implement item quantity and price handling
    - Update quantity on increase/decrease button tap
    - Recalculate item total when quantity or price changes
    - Update remaining amount when item totals change
    - _Requirements: 14.5, 14.9_

  - [~] 15.4 Implement item member assignment
    - Toggle member selection on chip tap
    - Calculate per-person share for each item: `itemTotal / assignedMemberCount`
    - Require at least one member per item
    - _Requirements: 14.6_

  - [~] 15.5 Implement item-wise split validation
    - Calculate total of all items: `sum(item.quantity × item.price)`
    - Display validation error when total ≠ expense amount
    - Enable Done button only when total = expense amount
    - _Requirements: 14.9, 14.10, 14.11_

  - [~] 15.6 Implement "Split All Equally" functionality
    - Distribute remaining amount equally across all items
    - Adjust rounding discrepancies to ensure sum equals remaining amount
    - _Requirements: 14.12_

  - [~] 15.7 Implement "Add More Item" functionality
    - Create new empty item entry on button tap
    - Add to item list and scroll to new item
    - _Requirements: 14.8_

  - [ ]* 15.8 Write property test for item-wise split amount validation
    - **Property 3: Item-Wise Split Amount Validation**
    - **Validates: Requirements 14.9, 14.10, 14.11**
    - Generate random expense amounts and item collections (with quantities, prices, members)
    - Verify remaining amount equals expense minus sum of item totals
    - Verify Done button enabled only when remaining equals zero
    - Run minimum 100 iterations

  - [ ]* 15.9 Write property test for item-wise equal distribution
    - **Property 9: Item-Wise Equal Distribution**
    - **Validates: Requirements 14.12**
    - Generate random remaining amounts and item counts
    - Verify "Split All Equally" distributes remaining equally among items
    - Verify rounding adjustments ensure sum equals remaining exactly
    - Run minimum 100 iterations

  - [ ]* 15.10 Write unit tests for ItemWiseSplitTab
    - Test item cards display correctly
    - Test "Add More Item" creates new item
    - Test item deletion removes item from list
    - Test remaining amount updates as items change

- [ ] 16. Implement multi-bill tab management
  - [~] 16.1 Enhance BillTabNotifier to persist full tab state
    - Save state per tab: description, amount, category, payer, split config, members, images, date
    - Implement state switching when tab changes
    - Validate each tab independently
    - _Requirements: 4.5_

  - [~] 16.2 Update BillTabsRow to handle tab state persistence
    - Save current tab state before switching
    - Load target tab state when switching
    - Display validation indicator per tab
    - _Requirements: 4.4, 4.5_

  - [~] 16.3 Implement multi-bill Firebase save
    - Save each bill as separate expense document
    - Link bills with `parentExpenseId` field
    - Set `billNumber` field for each bill (1, 2, 3, etc.)
    - Wrap all saves in a transaction for atomicity
    - _Requirements: 17.2_

  - [ ]* 16.4 Write unit tests for multi-bill state management
    - Test tab state persists when switching
    - Test validation runs per tab independently
    - Test new tab creation initializes empty state

- [~] 17. Checkpoint - Ensure item-wise split and multi-bill features work
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 18. Implement image attachment and bill scanning UI
  - [~] 18.1 Create ImageAttachmentSection in AddExpensePage
    - Display "Add Image" card
    - Display "Scan Bill" card
    - Display selected image previews with remove buttons
    - _Requirements: 15.1_

  - [~] 18.2 Implement image picker integration
    - Open bottom sheet with Camera and Gallery options on "Add Image" tap
    - Use `image_picker` package to capture/select images
    - Support multiple image selection
    - Display thumbnails after selection
    - _Requirements: 15.2, 15.3, 15.4_

  - [~] 18.3 Implement Firebase Storage image upload
    - Upload images to `groups/{groupId}/expenses/{expenseId}/image_{index}.jpg`
    - Return list of download URLs
    - Store URLs in `imageUrls` field of expense model
    - Handle upload errors gracefully
    - _Requirements: 17.2_

  - [~] 18.4 Create ScanBillPlaceholder screen
    - Display "Coming Soon" message
    - Display back button to return to AddExpensePage
    - Navigate to placeholder on "Scan Bill" tap
    - _Requirements: 15.5, 15.6_

  - [ ]* 18.5 Write unit tests for image attachment
    - Test "Add Image" opens picker options
    - Test multiple image selection
    - Test image preview display
    - Test image removal from selection

- [ ] 19. Implement date picker functionality
  - [~] 19.1 Create DatePickerCard widget
    - Display current date as default
    - Open Material date picker dialog on tap
    - Allow selecting past dates
    - Restrict selecting future dates
    - Update date display after selection
    - _Requirements: 16.1, 16.2, 16.3, 16.4, 16.5_

  - [ ]* 19.2 Write unit tests for date picker
    - Test date picker opens on card tap
    - Test default date is current date
    - Test past date selection updates display
    - Test future date selection is blocked

- [ ] 20. Implement Material 3 design polish
  - [~] 20.1 Apply Material 3 theming to all components
    - Use Material 3 color schemes from theme
    - Apply Material 3 typography scales
    - Use Material 3 elevation and shadows
    - Ensure proper contrast and accessibility
    - _Requirements: 20.1, 20.2, 20.3, 20.4_

  - [~] 20.2 Create reusable widget components
    - Extract common widgets: custom buttons, input fields, cards, chips
    - Ensure consistency across all screens
    - Make components responsive to all Android screen sizes
    - _Requirements: 20.5, 20.6_

  - [~] 20.3 Add animations and transitions
    - Implement Material 3 navigation transitions
    - Add smooth scroll animations
    - Add micro-interactions for button taps and selections
    - Use Material motion guidelines
    - _Requirements: 1.4_

  - [ ]* 20.4 Write widget tests for UI components
    - Test AddExpensePage renders correctly
    - Test bottom sheets open and close properly
    - Test form inputs accept valid data
    - Test validation messages display correctly
    - Test save button state changes based on validation

- [ ] 21. Implement error handling and edge cases
  - [~] 21.1 Implement Firebase error handling
    - Catch `FirebaseException` with specific error codes
    - Display user-friendly error messages in Snackbar
    - Handle network unavailable scenario
    - Handle permission denied scenario
    - _Requirements: 17.5, 17.6_

  - [~] 21.2 Implement offline handling
    - Detect offline state
    - Display offline indicator
    - Show clear error message when save attempted offline
    - Prevent navigation until save confirmed
    - _Requirements: 17.5_

  - [~] 21.3 Handle stale data scenarios
    - Refresh group members before save
    - Validate payer and split members still in group
    - Handle member removal during expense creation
    - Display appropriate error if members changed
    - _Requirements: 19.3, 19.4_

  - [ ]* 21.4 Write integration tests for error scenarios
    - Test network error displays error message
    - Test offline scenario prevents save
    - Test validation errors prevent save
    - Test stale member data handled gracefully

- [~] 22. Checkpoint - Ensure all features work correctly and handle errors gracefully
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 23. Final integration and cleanup
  - [~] 23.1 Verify Provider architecture consistency
    - Ensure all providers follow existing Riverpod patterns
    - Verify no existing providers were modified outside feature scope
    - Confirm clean architecture boundaries maintained
    - _Requirements: 19.1, 19.2, 19.3, 19.4_

  - [~] 23.2 Verify backward compatibility with existing expenses
    - Test reading legacy expenses with `EnhancedExpenseModel.fromMap()`
    - Verify legacy expenses display correctly in UI
    - Ensure new expenses don't break existing features
    - _Requirements: 17.2_

  - [~] 23.3 Performance optimization
    - Add debouncing to amount input fields
    - Memoize split calculations where possible
    - Use `const` constructors for immutable widgets
    - Implement ListView.builder for large member lists
    - _Requirements: 8.2_

  - [ ]* 23.4 Write end-to-end integration tests
    - Test complete flow: open page → fill form → save → navigate back
    - Test group balance updates after save
    - Test activity log entry created
    - Test expenses list refreshes on GroupDetailsScreen

- [~] 24. Final checkpoint - Complete feature verification
  - Ensure all tests pass, ask the user if questions arise.


## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP delivery
- Each task references specific requirements for traceability
- Checkpoints are placed after major implementation phases to ensure incremental validation
- Property-based tests validate universal correctness properties from the design document
- Unit tests and widget tests validate specific examples and UI behavior
- The implementation follows 5 phases: Core (Phase 1), Advanced Split (Phase 2), Item-Wise & Multi-Bill (Phase 3), Image & UI Polish (Phase 4), Testing & Error Handling (Phase 5)
- All property tests must run minimum 100 iterations as specified in the design
- Multi-bill support links expenses via `parentExpenseId` and `billNumber` fields
- Image uploads use Firebase Storage with path pattern: `groups/{groupId}/expenses/{expenseId}/image_{index}.jpg`
- Custom categories are stored locally only in Phase 1 (no Firebase persistence)
- Partner logos are UI-only in Phase 1 (no integration)
- Bill scanning is placeholder only in Phase 1 (no OCR)
- Backward compatibility ensures legacy expenses continue to work with `EnhancedExpenseModel`

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2", "1.3"] },
    { "id": 1, "tasks": ["1.4", "1.5"] },
    { "id": 2, "tasks": ["2.1", "2.2", "2.3", "2.4", "2.5"] },
    { "id": 3, "tasks": ["2.6", "2.7", "2.8"] },
    { "id": 4, "tasks": ["3.1"] },
    { "id": 5, "tasks": ["3.2", "3.3", "3.4", "3.5"] },
    { "id": 6, "tasks": ["3.6", "3.7", "3.8"] },
    { "id": 7, "tasks": ["5.1", "6.1"] },
    { "id": 8, "tasks": ["5.2", "5.3", "6.2", "6.3", "7.1"] },
    { "id": 9, "tasks": ["7.2", "7.3", "8.1"] },
    { "id": 10, "tasks": ["8.2", "8.3", "9.1"] },
    { "id": 11, "tasks": ["9.2"] },
    { "id": 12, "tasks": ["9.3", "9.4", "9.5"] },
    { "id": 13, "tasks": ["11.1"] },
    { "id": 14, "tasks": ["11.2", "11.3", "12.1"] },
    { "id": 15, "tasks": ["12.2", "12.3", "13.1"] },
    { "id": 16, "tasks": ["13.2", "13.3"] },
    { "id": 17, "tasks": ["15.1"] },
    { "id": 18, "tasks": ["15.2", "15.3", "15.4"] },
    { "id": 19, "tasks": ["15.5", "15.6", "15.7"] },
    { "id": 20, "tasks": ["15.8", "15.9", "15.10", "16.1"] },
    { "id": 21, "tasks": ["16.2", "16.3", "16.4"] },
    { "id": 22, "tasks": ["18.1", "19.1"] },
    { "id": 23, "tasks": ["18.2", "18.3", "18.4", "18.5", "19.2"] },
    { "id": 24, "tasks": ["20.1", "20.2"] },
    { "id": 25, "tasks": ["20.3", "20.4"] },
    { "id": 26, "tasks": ["21.1", "21.2", "21.3"] },
    { "id": 27, "tasks": ["21.4"] },
    { "id": 28, "tasks": ["23.1", "23.2", "23.3"] },
    { "id": 29, "tasks": ["23.4"] }
  ]
}
```
