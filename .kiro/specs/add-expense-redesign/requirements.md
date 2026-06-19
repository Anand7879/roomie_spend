# Requirements Document

## Introduction

This document specifies the requirements for redesigning the Add Expense flow in the RoomieSpend Flutter application. The redesign changes the navigation behavior from opening member selection first to directly opening the Add Expense page when the user taps the + button. The new flow provides a comprehensive expense entry interface with member selection, multiple bill support, partner logo integration, category management, split options, payer configuration, and Firebase integration.

## Glossary

- **Add_Expense_Page**: The main screen for creating a new expense
- **Member_Selection_Screen**: Bottom sheet or screen showing group members available for selection
- **Category_Bottom_Sheet**: Bottom sheet displaying expense categories with icons
- **Paid_By_Bottom_Sheet**: Bottom sheet for selecting who paid for the expense (single or multiple payers)
- **Split_Bottom_Sheet**: Bottom sheet for configuring how the expense is split among members
- **Group_Detail_Page**: The screen displaying group information, members, and expenses
- **Expense_Entry**: A record of a single expense transaction
- **Bill_Tab**: A tab representing one bill within the multi-bill interface
- **Partner_Logo**: Visual representation of payment or service partners (PhonePe, Google Pay, etc.)
- **Split_Type**: The method of splitting an expense (Equally, Unequally, Item Wise)
- **Payer**: A member who paid for the expense
- **Firestore**: Firebase Cloud Firestore database service
- **Provider**: Flutter state management architecture using Riverpod
- **Material_3**: Material Design 3 design system
- **Bottom_Sheet**: A surface that slides up from the bottom of the screen
- **Snackbar**: A brief message at the bottom of the screen

## Requirements

### Requirement 1: Navigation from + Button to Add Expense Page

**User Story:** As a user, I want to tap the black circular + button and directly open the Add Expense page, so that I can immediately start creating an expense without navigating through member selection first.

#### Acceptance Criteria

1. WHEN the user taps the black circular + button at top left, THE Add_Expense_Page SHALL open directly
2. THE Member_Selection_Screen SHALL NOT open automatically when the + button is tapped
3. THE existing functionality outside this feature SHALL remain unchanged
4. THE navigation transition SHALL use Material 3 animations

### Requirement 2: Add Expense Page Layout Structure

**User Story:** As a user, I want a well-organized Add Expense page with clear sections, so that I can easily enter all expense details.

#### Acceptance Criteria

1. THE Add_Expense_Page SHALL display a back button in the top row
2. THE Add_Expense_Page SHALL display the title "Add Expense" in the top row
3. THE Add_Expense_Page SHALL display a current room badge at the top right
4. THE Add_Expense_Page SHALL display member avatars horizontally below the top row
5. THE Add_Expense_Page SHALL display bill tabs ("Bill 1", "+ Add Bill") below member avatars
6. THE Add_Expense_Page SHALL display partner logos in a row below bill tabs
7. THE Add_Expense_Page SHALL display a divider labeled "OR" below partner logos
8. THE Add_Expense_Page SHALL display the expense form below the divider
9. THE Add_Expense_Page SHALL be responsive on all Android screen sizes

### Requirement 3: Member Selection Interface

**User Story:** As a user, I want to select which group members are involved in the expense, so that the expense is split correctly.

#### Acceptance Criteria

1. THE Add_Expense_Page SHALL display an "Add Friends" avatar as the first avatar
2. WHEN the user taps the "Add Friends" avatar, THE Member_Selection_Screen SHALL open
3. THE Add_Expense_Page SHALL display selected member avatars with image and name
4. WHEN a member is selected, THE Add_Expense_Page SHALL display that member's avatar with a remove button
5. WHEN the user taps a member's remove button, THE Add_Expense_Page SHALL remove that member from the selection
6. THE Add_Expense_Page SHALL update split calculations when members are added or removed

### Requirement 4: Bill Tabs Interface

**User Story:** As a user, I want to create multiple bills within one expense entry, so that I can organize related expenses together.

#### Acceptance Criteria

1. THE Add_Expense_Page SHALL display "Bill 1" tab by default
2. THE Add_Expense_Page SHALL display a "+ Add Bill" button next to the last bill tab
3. WHEN the user taps "+ Add Bill", THE Add_Expense_Page SHALL create a new bill tab
4. THE Add_Expense_Page SHALL display the active bill tab with visual distinction
5. WHEN the user taps a bill tab, THE Add_Expense_Page SHALL switch to that bill's content

### Requirement 5: Partner Logos Display

**User Story:** As a user, I want to see partner payment and service logos, so that I can quickly identify the source of the expense.

#### Acceptance Criteria

1. THE Add_Expense_Page SHALL display logos for PhonePe, Google Pay, Paytm, Uber, Swiggy, Zomato, Zepto, and Blinkit
2. THE Add_Expense_Page SHALL display partner logos horizontally in a scrollable row
3. THE partner logos SHALL be UI-only elements in Phase 1
4. THE partner logos SHALL not trigger any actions when tapped in Phase 1

### Requirement 6: Category Selection

**User Story:** As a user, I want to select a category for my expense, so that expenses are properly organized.

#### Acceptance Criteria

1. THE Add_Expense_Page SHALL display a category field that looks like a dropdown
2. THE category field SHALL display "Misc." as the default value
3. WHEN the user taps the category field, THE Category_Bottom_Sheet SHALL open
4. THE Category_Bottom_Sheet SHALL display categories: Food, Groceries, Travel, Stay, Bills, Subscription, Shopping, Gifts, Drinks, Fuel, Udhaar (Debt), Health, Entertainment, Misc., Add Custom
5. THE Category_Bottom_Sheet SHALL display an icon for each category
6. WHEN the user selects a category, THE Category_Bottom_Sheet SHALL close immediately
7. WHEN the user selects a category, THE Add_Expense_Page SHALL update the category field with the selected value
8. WHEN the user taps "Add Custom", THE Add_Expense_Page SHALL open a dialog for custom category entry
9. THE custom category dialog SHALL not implement Firebase save in Phase 2

### Requirement 7: Expense Description Field

**User Story:** As a user, I want to enter a description for my expense, so that I can remember what the expense was for.

#### Acceptance Criteria

1. THE Add_Expense_Page SHALL display a description text field
2. THE description field SHALL display the hint "Add a description"
3. THE description field SHALL accept alphanumeric and special characters
4. THE description field SHALL not have a maximum character limit

### Requirement 8: Price Entry and Validation

**User Story:** As a user, I want to enter the expense amount with proper validation, so that I create accurate expense records.

#### Acceptance Criteria

1. THE Add_Expense_Page SHALL display a price input field with currency symbol ₹
2. THE price field SHALL display a numeric keyboard only
3. THE price field SHALL accept decimal values
4. WHEN the user enters a price of zero or less, THE Add_Expense_Page SHALL display a validation error
5. WHEN the user enters a price of zero or less, THE Add_Expense_Page SHALL disable the submit button
6. THE price field SHALL format large numbers with proper separators

### Requirement 9: Single Payer Selection

**User Story:** As a user, I want to select who paid for the expense, so that I can track who is owed money.

#### Acceptance Criteria

1. THE Add_Expense_Page SHALL display a "Paid By" field
2. WHEN the user taps the "Paid By" field, THE Paid_By_Bottom_Sheet SHALL open
3. THE Paid_By_Bottom_Sheet SHALL display two tabs: "Single Payer" and "Multi Payer"
4. WHEN the "Single Payer" tab is active, THE Paid_By_Bottom_Sheet SHALL display all selected members
5. WHEN the user selects a member in Single Payer mode, THE Paid_By_Bottom_Sheet SHALL mark that member as the sole payer
6. WHEN the user selects a member in Single Payer mode, THE Paid_By_Bottom_Sheet SHALL deselect any previously selected payer
7. WHEN the user closes the Paid_By_Bottom_Sheet, THE Add_Expense_Page SHALL update the "Paid By" field with the selected payer's name

### Requirement 10: Multi Payer Selection

**User Story:** As a user, I want to split the payment among multiple members, so that I can accurately record when multiple people pay for one expense.

#### Acceptance Criteria

1. WHEN the "Multi Payer" tab is active, THE Paid_By_Bottom_Sheet SHALL display all selected members with editable amount fields
2. THE Paid_By_Bottom_Sheet SHALL display "People Selected" count at the bottom
3. THE Paid_By_Bottom_Sheet SHALL display "Remaining Amount" at the bottom
4. WHEN the user enters amounts in the payer fields, THE Paid_By_Bottom_Sheet SHALL update the remaining amount in real-time
5. WHEN the sum of payer amounts does not equal the expense amount, THE Paid_By_Bottom_Sheet SHALL disable the submit button
6. WHEN the sum of payer amounts equals the expense amount, THE Paid_By_Bottom_Sheet SHALL enable the submit button
7. WHEN the user closes the Paid_By_Bottom_Sheet with valid multi-payer data, THE Add_Expense_Page SHALL update the "Paid By" field to show "Multiple Payers"

### Requirement 11: Equal Split Configuration

**User Story:** As a user, I want to split an expense equally among selected members, so that everyone pays a fair share.

#### Acceptance Criteria

1. THE Add_Expense_Page SHALL display a split configuration section with three tabs: "Equally", "Unequally", "Item Wise"
2. WHEN the "Equally" tab is active, THE Add_Expense_Page SHALL display "Split Among" with selectable members
3. WHEN a member is deselected from "Split Among", THE Add_Expense_Page SHALL recalculate the split among remaining members
4. THE Add_Expense_Page SHALL display an amount card for each selected member showing their equal share
5. THE Add_Expense_Page SHALL handle decimal amounts correctly when splitting
6. WHEN the total split amount does not equal the expense amount due to rounding, THE Add_Expense_Page SHALL adjust the last member's amount
7. THE equal split calculation SHALL behave exactly like Splitwise equal split

### Requirement 12: Unequal Split by Amount

**User Story:** As a user, I want to specify exact amounts for each member, so that I can split expenses based on what each person actually consumed.

#### Acceptance Criteria

1. WHEN the "Unequally" tab is active, THE Split_Bottom_Sheet SHALL open
2. THE Split_Bottom_Sheet SHALL display two tabs: "By Amount" and "By Shares"
3. WHEN the "By Amount" tab is active, THE Split_Bottom_Sheet SHALL display amount input fields for each selected member
4. THE Split_Bottom_Sheet SHALL display the remaining amount in real-time as amounts are entered
5. WHEN the total amount exceeds the expense amount, THE Split_Bottom_Sheet SHALL display a validation error
6. WHEN the total amount equals the expense amount, THE Split_Bottom_Sheet SHALL enable the submit button
7. WHEN the user closes the Split_Bottom_Sheet, THE Add_Expense_Page SHALL save the unequal split configuration

### Requirement 13: Unequal Split by Shares

**User Story:** As a user, I want to assign shares to each member, so that the system automatically calculates proportional splits.

#### Acceptance Criteria

1. WHEN the "By Shares" tab is active, THE Split_Bottom_Sheet SHALL display share input fields for each selected member
2. THE Split_Bottom_Sheet SHALL calculate each member's amount based on their share proportion
3. THE Split_Bottom_Sheet SHALL display the calculated amount for each member
4. THE Split_Bottom_Sheet SHALL display the total remaining shares
5. WHEN the user closes the Split_Bottom_Sheet, THE Add_Expense_Page SHALL save the share-based split configuration

### Requirement 14: Item Wise Split

**User Story:** As a user, I want to split an expense by individual items, so that each person pays only for what they consumed.

#### Acceptance Criteria

1. WHEN the "Item Wise" tab is active, THE Split_Bottom_Sheet SHALL open with item management interface
2. THE Split_Bottom_Sheet SHALL display "Remaining ₹X / Y" at the top showing unallocated amount
3. THE Split_Bottom_Sheet SHALL display a "Split All Equally" button at the top
4. THE Split_Bottom_Sheet SHALL display item cards with description, quantity, price, delete button, and member chips
5. WHEN the user taps quantity increase/decrease, THE item card SHALL update the quantity and total
6. WHEN the user taps member chips on an item, THE item card SHALL toggle member selection for that item
7. THE Split_Bottom_Sheet SHALL display an "Add More Item" button
8. WHEN the user taps "Add More Item", THE Split_Bottom_Sheet SHALL create a new item entry
9. THE Split_Bottom_Sheet SHALL update the remaining amount as items are added or modified
10. WHEN the sum of all item amounts does not equal the expense amount, THE Split_Bottom_Sheet SHALL display a validation error
11. WHEN the sum of all item amounts equals the expense amount, THE Split_Bottom_Sheet SHALL enable the Done button
12. WHEN the user taps "Split All Equally", THE Split_Bottom_Sheet SHALL distribute the remaining amount equally among all items

### Requirement 15: Image and Bill Scanning

**User Story:** As a user, I want to attach images and scan bills, so that I have visual records of my expenses.

#### Acceptance Criteria

1. THE Add_Expense_Page SHALL display three cards: "Add Image", "Scan Bill", and date picker
2. WHEN the user taps "Add Image", THE Add_Expense_Page SHALL open gallery and camera options
3. THE Add_Expense_Page SHALL support selecting multiple images
4. THE Add_Expense_Page SHALL display image previews after selection
5. WHEN the user taps "Scan Bill", THE Add_Expense_Page SHALL open a placeholder screen
6. THE Scan Bill feature SHALL not implement OCR functionality in Phase 7

### Requirement 16: Date Selection

**User Story:** As a user, I want to set the expense date, so that expenses are recorded with the correct timestamp.

#### Acceptance Criteria

1. THE Add_Expense_Page SHALL display a date picker card
2. THE date picker SHALL default to the current date
3. WHEN the user taps the date picker, THE Add_Expense_Page SHALL open a date selection dialog
4. THE date picker SHALL allow selecting past dates
5. THE date picker SHALL not allow selecting future dates

### Requirement 17: Firebase Expense Storage

**User Story:** As a user, I want my expenses saved to Firebase, so that they are persisted and synchronized across devices.

#### Acceptance Criteria

1. THE Add_Expense_Page SHALL save expenses under the path: groups/{groupId}/expenses/{expenseId}
2. THE Expense_Entry SHALL store: description, amount, category, paidBy, splitType, splitDetails, selectedMembers, payerDetails, billImages, expenseDate, createdBy, createdAt, updatedAt, billNumber, roomId
3. WHEN the user submits an invalid expense, THE Add_Expense_Page SHALL not save the expense to Firestore
4. WHEN the user submits a valid expense, THE Add_Expense_Page SHALL save the expense to Firestore
5. THE Add_Expense_Page SHALL handle offline scenarios gracefully
6. WHEN a Firebase exception occurs, THE Add_Expense_Page SHALL display an error message to the user

### Requirement 18: Post-Save Actions

**User Story:** As a user, I want immediate feedback after creating an expense, so that I know the expense was saved successfully.

#### Acceptance Criteria

1. WHEN an expense is saved successfully, THE Add_Expense_Page SHALL update the group balance
2. WHEN an expense is saved successfully, THE Add_Expense_Page SHALL update the activity history
3. WHEN an expense is saved successfully, THE Add_Expense_Page SHALL display a success Snackbar
4. WHEN an expense is saved successfully, THE Add_Expense_Page SHALL navigate back to the Group_Detail_Page
5. WHEN returning to the Group_Detail_Page, THE Group_Detail_Page SHALL refresh the expenses list automatically
6. THE Add_Expense_Page SHALL prevent duplicate expense submissions

### Requirement 19: Provider Architecture Preservation

**User Story:** As a developer, I want the existing Provider architecture to remain unchanged, so that the codebase maintains consistency.

#### Acceptance Criteria

1. THE Add_Expense_Page SHALL use the existing Provider state management pattern
2. THE Add_Expense_Page SHALL not modify existing provider implementations outside the add expense feature
3. THE Add_Expense_Page SHALL integrate with existing Firestore service layer
4. THE Add_Expense_Page SHALL follow the existing clean architecture pattern

### Requirement 20: Material 3 Design Compliance

**User Story:** As a user, I want the Add Expense page to follow Material 3 design guidelines, so that it feels consistent with modern Android apps.

#### Acceptance Criteria

1. THE Add_Expense_Page SHALL use Material 3 components
2. THE Add_Expense_Page SHALL use Material 3 color schemes
3. THE Add_Expense_Page SHALL use Material 3 typography
4. THE Add_Expense_Page SHALL use Material 3 elevation and shadows
5. THE Add_Expense_Page SHALL use reusable widget components
6. THE Add_Expense_Page SHALL be responsive on every Android screen size

### Requirement 21: Form Validation and Error Handling

**User Story:** As a user, I want clear validation messages, so that I know what needs to be corrected before submitting.

#### Acceptance Criteria

1. WHEN the price is zero or negative, THE Add_Expense_Page SHALL display an error message "Amount must be greater than zero"
2. WHEN no members are selected for split, THE Add_Expense_Page SHALL display an error message "Please select members to split with"
3. WHEN no payer is selected, THE Add_Expense_Page SHALL display an error message "Please select who paid"
4. WHEN the split amounts don't equal the expense amount, THE Add_Expense_Page SHALL display an error message "Split amounts must equal expense amount"
5. WHEN validation fails, THE Add_Expense_Page SHALL disable the save button
6. WHEN all validations pass, THE Add_Expense_Page SHALL enable the save button
