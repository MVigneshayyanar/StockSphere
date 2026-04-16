import re

with open(r'C:\MaxBillUp\lib\Menu\Menu.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Count before
before = content.count('Icons.')
print(f"Icons. found before: {before}")

# Map of Icon(Icons.xxx replacements to HeroIcon(HeroIcons.xxx
# Format: (old_pattern, new_pattern)
replacements = [
    # Arrow backs
    ('Icon(Icons.arrow_back, color: kWhite, size: 22)', 'HeroIcon(HeroIcons.arrowLeft, color: kWhite, size: 22)'),
    ('Icon(Icons.arrow_back, color: kWhite)', 'HeroIcon(HeroIcons.arrowLeft, color: kWhite)'),
    ('Icon(Icons.arrow_back_rounded, color: kWhite, size: 18)', 'HeroIcon(HeroIcons.arrowLeft, color: kWhite, size: 18)'),
    ('Icon(Icons.arrow_back, size: 22)', 'HeroIcon(HeroIcons.arrowLeft, size: 22)'),

    # Person/User
    ('Icon(Icons.person, color: kOrange, size: 18)', 'HeroIcon(HeroIcons.user, color: kOrange, size: 18)'),
    ('Icon(Icons.person_rounded, color: kOrange, size: 18)', 'HeroIcon(HeroIcons.user, color: kOrange, size: 18)'),
    ('Icon(Icons.person_rounded, color: kWhite : kOrange, size: 20)', 'HeroIcon(HeroIcons.user, color: kWhite : kOrange, size: 20)'),
    ('Icon(Icons.person_rounded, color: hasCustomer ? kWhite : kOrange, size: 20)', 'HeroIcon(HeroIcons.user, color: hasCustomer ? kWhite : kOrange, size: 20)'),
    ('Icon(Icons.person_add_rounded, size: 14, color: kOrange)', 'HeroIcon(HeroIcons.userPlus, size: 14, color: kOrange)'),
    ('Icon(Icons.person_outline, color: kPrimaryColor)', 'HeroIcon(HeroIcons.user, color: kPrimaryColor)'),
    ('Icon(Icons.people_outline_rounded, size: 64, color: kGrey300)', 'HeroIcon(HeroIcons.userGroup, size: 64, color: kGrey300)'),

    # Receipt/Document
    ('Icon(Icons.receipt_long_rounded, size: 38, color: kPrimaryColor)', 'HeroIcon(HeroIcons.documentText, size: 38, color: kPrimaryColor)'),
    ('Icon(Icons.receipt_long_rounded, size: 16, color: kPrimaryColor)', 'HeroIcon(HeroIcons.documentText, size: 16, color: kPrimaryColor)'),
    ('Icon(Icons.receipt_long_outlined, size: 60, color: kPrimaryColor.withOpacity(0.1))', 'HeroIcon(HeroIcons.documentText, size: 60, color: kPrimaryColor.withOpacity(0.1))'),

    # Wallet
    ('Icon(Icons.account_balance_wallet_outlined, size: 14, color: kPrimaryColor)', 'HeroIcon(HeroIcons.wallet, size: 14, color: kPrimaryColor)'),
    ('Icon(Icons.account_balance_wallet_rounded, color: color, size: 24)', 'HeroIcon(HeroIcons.wallet, color: color, size: 24)'),

    # Notes
    ('Icon(Icons.note_alt_outlined, size: 14, color: kOrange)', 'HeroIcon(HeroIcons.pencilSquare, size: 14, color: kOrange)'),
    ('Icon(Icons.note_rounded, size: 16, color: kBlack54)', 'HeroIcon(HeroIcons.documentText, size: 16, color: kBlack54)'),

    # Location
    ('Icon(Icons.location_on_outlined, size: 14, color: kPrimaryColor)', 'HeroIcon(HeroIcons.mapPin, size: 14, color: kPrimaryColor)'),

    # Return/keyboard_return
    ('Icon(Icons.keyboard_return_rounded, size: 14, color: kErrorColor)', 'HeroIcon(HeroIcons.arrowUturnLeft, size: 14, color: kErrorColor)'),
    ('Icon(Icons.keyboard_return_rounded, size: 12, color: kErrorColor)', 'HeroIcon(HeroIcons.arrowUturnLeft, size: 12, color: kErrorColor)'),

    # Remove/minus circle
    ('Icon(Icons.remove_circle_outline, size: 12, color: kErrorColor)', 'HeroIcon(HeroIcons.minusCircle, size: 12, color: kErrorColor)'),

    # Search
    ('Icon(Icons.search, color: kPrimaryColor, size: 20)', 'HeroIcon(HeroIcons.magnifyingGlass, color: kPrimaryColor, size: 20)'),
    ('Icon(Icons.search_off_rounded, size: 40, color: kGrey300)', 'HeroIcon(HeroIcons.magnifyingGlass, size: 40, color: kGrey300)'),

    # Tune/filter
    ('Icon(Icons.tune_rounded, color: kPrimaryColor, size: 20)', 'HeroIcon(HeroIcons.adjustmentsHorizontal, color: kPrimaryColor, size: 20)'),

    # Inventory
    ('Icon(Icons.inventory_2_outlined, size: 64, color: kGrey300)', 'HeroIcon(HeroIcons.archiveBox, size: 64, color: kGrey300)'),

    # History
    ('Icon(Icons.history_rounded, size: 64, color: kGrey300)', 'HeroIcon(HeroIcons.clock, size: 64, color: kGrey300)'),

    # Close
    ('Icon(Icons.close_rounded, color: kBlack54, size: 24)', 'HeroIcon(HeroIcons.xMark, color: kBlack54, size: 24)'),
    ('Icon(Icons.close : Icons.search, size: 22)', 'HeroIcon(_isSearching ? HeroIcons.xMark : HeroIcons.magnifyingGlass, size: 22)'),

    # Notifications
    ('Icon(Icons.notifications, size: 22, color: kWhite)', 'HeroIcon(HeroIcons.bell, size: 22, color: kWhite)'),

    # Sort
    ('Icon(Icons.sort_rounded, color: kPrimaryColor, size: 22)', 'HeroIcon(HeroIcons.bars3BottomLeft, color: kPrimaryColor, size: 22)'),

    # Star
    ('Icon(Icons.star_rounded, color: kOrange, size: 20)', 'HeroIcon(HeroIcons.star, style: HeroIconStyle.solid, color: kOrange, size: 20)'),

    # Check circle
    ('Icon(Icons.check_circle, color: color, size: 20)', 'HeroIcon(HeroIcons.checkCircle, color: color, size: 20)'),
    ('Icon(Icons.check_circle_rounded, color: color, size: 18)', 'HeroIcon(HeroIcons.checkCircle, color: color, size: 18)'),
    ('Icon(Icons.check_circle_rounded, color: kPrimaryColor, size: 20)', 'HeroIcon(HeroIcons.checkCircle, color: kPrimaryColor, size: 20)'),
    ('Icon(Icons.check_circle_outline_rounded, size: 60, color: kGoogleGreen.withOpacity(0.3))', 'HeroIcon(HeroIcons.checkCircle, size: 60, color: kGoogleGreen.withOpacity(0.3))'),
    ('Icon(Icons.check_circle_outline, size: 64, color: kGoogleGreen.withOpacity(0.5))', 'HeroIcon(HeroIcons.checkCircle, size: 64, color: kGoogleGreen.withOpacity(0.5))'),

    # Chevron right
    ('Icon(Icons.chevron_right_rounded, color: kGrey400, size: 20)', 'HeroIcon(HeroIcons.chevronRight, color: kGrey400, size: 20)'),
    ('Icon(Icons.arrow_forward_ios_rounded, size: 10, color: kOrange)', 'HeroIcon(HeroIcons.chevronRight, size: 10, color: kOrange)'),
    ('Icon(Icons.arrow_forward_ios_rounded, color: kOrange, size: 14)', 'HeroIcon(HeroIcons.chevronRight, color: kOrange, size: 14)'),

    # Edit
    ('Icon(Icons.edit_rounded, size: 14, color: kPrimaryColor)', 'HeroIcon(HeroIcons.pencil, size: 14, color: kPrimaryColor)'),
    ('Icon(Icons.edit_rounded, size: 12, color: kPrimaryColor)', 'HeroIcon(HeroIcons.pencil, size: 12, color: kPrimaryColor)'),
    ('Icon(Icons.edit, color: kHeaderColor, size: 22)', 'HeroIcon(HeroIcons.pencil, color: kHeaderColor, size: 22)'),
    ('Icon(Icons.edit_note_rounded, size: 16, color: color ?? kHeaderColor)', 'HeroIcon(HeroIcons.pencilSquare, size: 16, color: color ?? kHeaderColor)'),

    # Cancel
    ('Icon(Icons.cancel_rounded, color: kErrorColor, size: 22)', 'HeroIcon(HeroIcons.xCircle, color: kErrorColor, size: 22)'),

    # Warning
    ('Icon(Icons.warning_amber_rounded, color: kErrorColor, size: 24)', 'HeroIcon(HeroIcons.exclamationTriangle, color: kErrorColor, size: 24)'),
    ('Icon(Icons.warning_amber_rounded, size: 16, color: kOrange)', 'HeroIcon(HeroIcons.exclamationTriangle, size: 16, color: kOrange)'),

    # Chat
    ('Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 16)', 'HeroIcon(HeroIcons.chatBubbleLeft, color: Color(0xFF25D366), size: 16)'),

    # Share
    ('Icon(Icons.share_rounded, color: kPrimaryColor, size: 16)', 'HeroIcon(HeroIcons.share, color: kPrimaryColor, size: 16)'),
    ('Icon(Icons.share_rounded, color: Colors.purple, size: 16)', 'HeroIcon(HeroIcons.share, color: Colors.purple, size: 16)'),

    # Touch/hand
    ('Icon(Icons.touch_app_rounded, size: 11, color: kPrimaryColor.withOpacity(0.7))', 'HeroIcon(HeroIcons.cursorArrowRays, size: 11, color: kPrimaryColor.withOpacity(0.7))'),

    # Add
    ('Icon(Icons.add_circle_outline_rounded, size: 14, color: Colors.purple)', 'HeroIcon(HeroIcons.plusCircle, size: 14, color: Colors.purple)'),
    ('Icon(Icons.add_circle_outline_rounded, size: 14, color: kHeaderColor)', 'HeroIcon(HeroIcons.plusCircle, size: 14, color: kHeaderColor)'),
    ('Icon(Icons.add_circle_outline, size: 20, color: kWhite)', 'HeroIcon(HeroIcons.plusCircle, size: 20, color: kWhite)'),
    ('Icon(Icons.add_circle_outline, size: 16, color: kPrimaryColor)', 'HeroIcon(HeroIcons.plusCircle, size: 16, color: kPrimaryColor)'),
    ('Icon(Icons.add_rounded, color: kHeaderColor, size: 20)', 'HeroIcon(HeroIcons.plus, color: kHeaderColor, size: 20)'),
    ('Icon(Icons.add_circle_rounded,', 'HeroIcon(HeroIcons.plusCircle, style: HeroIconStyle.solid,'),

    # Remove/minus
    ('Icon(Icons.remove_rounded,', 'HeroIcon(HeroIcons.minus,'),

    # Delete
    ('Icon(Icons.delete_outline_rounded, size: 18)', 'HeroIcon(HeroIcons.trash, size: 18)'),

    # Close (small)
    ('Icon(Icons.close, size: 16, color: kErrorColor)', 'HeroIcon(HeroIcons.xMark, size: 16, color: kErrorColor)'),

    # Confirmation/ticket number
    ('Icon(Icons.confirmation_number_outlined, size: 14, color: kPrimaryColor)', 'HeroIcon(HeroIcons.hashtag, size: 14, color: kPrimaryColor)'),
    ('Icon(Icons.confirmation_number_outlined, size: 14, color: Colors.purple)', 'HeroIcon(HeroIcons.hashtag, size: 14, color: Colors.purple)'),

    # Calendar/event
    ('Icon(Icons.event_rounded, size: 14, color: dueDateColor)', 'HeroIcon(HeroIcons.calendarDays, size: 14, color: dueDateColor)'),

    # Download
    ('Icon(Icons.download_rounded, color: kWhite, size: 22)', 'HeroIcon(HeroIcons.arrowDownTray, color: kWhite, size: 22)'),

    # Support
    ('Icon(Icons.support_agent_rounded, size: 32, color: Color(0xFF1976D2))', 'HeroIcon(HeroIcons.lifebuoy, size: 32, color: Color(0xFF1976D2))'),

    # Email
    ('Icon(Icons.email_outlined, color: kPrimaryColor)', 'HeroIcon(HeroIcons.envelope, color: kPrimaryColor)'),

    # Phone
    ('Icon(Icons.phone_outlined, color: kPrimaryColor)', 'HeroIcon(HeroIcons.phone, color: kPrimaryColor)'),

    # Category
    ('Icon(Icons.category_outlined, color: kPrimaryColor)', 'HeroIcon(HeroIcons.tag, color: kPrimaryColor)'),

    # Title
    ('Icon(Icons.title_rounded, color: kPrimaryColor)', 'HeroIcon(HeroIcons.pencil, color: kPrimaryColor)'),

    # Description
    ('Icon(Icons.description_outlined, color: kPrimaryColor)', 'HeroIcon(HeroIcons.documentText, color: kPrimaryColor)'),

    # Badge
    ('Icon(Icons.badge_outlined)', 'HeroIcon(HeroIcons.identification)'),

    # Key
    ('Icon(Icons.vpn_key_outlined)', 'HeroIcon(HeroIcons.key)'),

    # Expand
    ('Icon(Icons.expand_more, color: kPrimaryColor)', 'HeroIcon(HeroIcons.chevronDown, color: kPrimaryColor)'),

    # Folder
    ('Icon(Icons.folder_open_outlined, size: 60, color: kSoftAzure)', 'HeroIcon(HeroIcons.folderOpen, size: 60, color: kSoftAzure)'),

    # Shopping basket
    ('Icon(Icons.shopping_basket_outlined, color: kGrey300, size: 40)', 'HeroIcon(HeroIcons.shoppingCart, color: kGrey300, size: 40)'),

    # Store
    ('Icon(Icons.store_rounded, size: 16, color: kBlack54)', 'HeroIcon(HeroIcons.buildingStorefront, size: 16, color: kBlack54)'),
]

# Also handle _buildDetailRow which takes IconData
detail_row_replacements = [
    ('_buildDetailRow(Icons.receipt_long_rounded,', '_buildDetailRow(HeroIcons.documentText,'),
    ('_buildDetailRow(Icons.badge_rounded,', '_buildDetailRow(HeroIcons.identification,'),
    ('_buildDetailRow(Icons.calendar_month_rounded,', '_buildDetailRow(HeroIcons.calendarDays,'),
    ('_buildDetailRow(Icons.payment_rounded,', '_buildDetailRow(HeroIcons.creditCard,'),
    ('_buildDetailRow(Icons.history_rounded,', '_buildDetailRow(HeroIcons.clock,'),
    ('_buildDetailRow(Icons.info_outline_rounded,', '_buildDetailRow(HeroIcons.informationCircle,'),
]

# _buildPaymentSplitRow
split_row_replacements = [
    ('_buildPaymentSplitRow(Icons.payments_outlined,', '_buildPaymentSplitRow(HeroIcons.banknotes,'),
    ('_buildPaymentSplitRow(Icons.account_balance_outlined,', '_buildPaymentSplitRow(HeroIcons.buildingLibrary,'),
    ('_buildPaymentSplitRow(Icons.credit_card_outlined,', '_buildPaymentSplitRow(HeroIcons.creditCard,'),
]

# _squareActionButton
action_btn_replacements = [
    ('_squareActionButton(Icons.receipt_long_rounded,', '_squareActionButton(HeroIcons.documentText,'),
    ('_squareActionButton(Icons.edit_note_rounded,', '_squareActionButton(HeroIcons.pencilSquare,'),
    ('_squareActionButton(Icons.keyboard_return_rounded,', '_squareActionButton(HeroIcons.arrowUturnLeft,'),
    ('_squareActionButton(Icons.cancel_outlined,', '_squareActionButton(HeroIcons.xCircle,'),
]

# _buildIconRow
icon_row_replacements = [
    ('_buildIconRow(Icons.receipt_long,', '_buildIconRow(HeroIcons.documentText,'),
    ('_buildIconRow(Icons.person,', '_buildIconRow(HeroIcons.user,'),
    ('_buildIconRow(Icons.calendar_today,', '_buildIconRow(HeroIcons.calendarDays,'),
]

# _buildDialogField
dialog_field_replacements = [
    ('_buildDialogField(amountController, \'Amount to Pay\', Icons.money_rounded)', '_buildDialogField(amountController, \'Amount to Pay\', HeroIcons.currencyDollar)'),
    ('_buildDialogField(amountController, \'Settlement Amount\', Icons.currency_rupee_rounded)', '_buildDialogField(amountController, \'Settlement Amount\', HeroIcons.currencyDollar)'),
]

# _buildPayOption
pay_option_replacements = [
    ('_buildPayOption(setDialogState, paymentMode, \'Cash\', Icons.payments_outlined, kGoogleGreen,', '_buildPayOption(setDialogState, paymentMode, \'Cash\', HeroIcons.banknotes, kGoogleGreen,'),
    ('_buildPayOption(setDialogState, paymentMode, \'Online\', Icons.account_balance_outlined, kPrimaryColor,', '_buildPayOption(setDialogState, paymentMode, \'Online\', HeroIcons.buildingLibrary, kPrimaryColor,'),
    ('_buildPayOption(setDialogState, paymentMode, \'Waive Off\', Icons.block_outlined, kOrange,', '_buildPayOption(setDialogState, paymentMode, \'Waive Off\', HeroIcons.noSymbol, kOrange,'),
]

# _buildDialogOption
dialog_option_replacements = [
    ('_buildDialogOption(onSelect: () => setState(() => mode = "Cash"), mode: "Cash", current: mode, icon: Icons.payments, color: kSuccessGreen)', '_buildDialogOption(onSelect: () => setState(() => mode = "Cash"), mode: "Cash", current: mode, icon: HeroIcons.banknotes, color: kSuccessGreen)'),
    ('_buildDialogOption(onSelect: () => setState(() => mode = "Online"), mode: "Online", current: mode, icon: Icons.account_balance, color: kPrimaryColor)', '_buildDialogOption(onSelect: () => setState(() => mode = "Online"), mode: "Online", current: mode, icon: HeroIcons.buildingLibrary, color: kPrimaryColor)'),
]

# _buildSortOption
sort_option_replacements = [
    ("_buildSortOption('Sort by Sales', 'sales', Icons.trending_up_rounded)", "_buildSortOption('Sort by Sales', 'sales', HeroIcons.arrowTrendingUp)"),
    ("_buildSortOption('Sort by Credit', 'credit', Icons.account_balance_wallet_rounded)", "_buildSortOption('Sort by Credit', 'credit', HeroIcons.wallet)"),
]

# _buildManagerFormTextField
form_field_replacements = [
    ("_buildManagerFormTextField(_nameCtrl, \"Staff Full Name\", Icons.badge_outlined)", "_buildManagerFormTextField(_nameCtrl, \"Staff Full Name\", HeroIcons.identification)"),
    ("_buildManagerFormTextField(_emailCtrl, \"Email Address / User ID\", Icons.alternate_email_outlined)", "_buildManagerFormTextField(_emailCtrl, \"Email Address / User ID\", HeroIcons.atSymbol)"),
    ("_buildManagerFormTextField(_passCtrl, \"Password\", Icons.vpn_key_outlined", "_buildManagerFormTextField(_passCtrl, \"Password\", HeroIcons.key"),
]

# _buildLargeButton
large_btn_replacements = [
    ('_buildLargeButton(context, label: "Record payment", icon: Icons.receipt_long_rounded,', '_buildLargeButton(context, label: "Record payment", icon: HeroIcons.documentText,'),
]

# icon: property with Icons. (check_circle_outline for modal)
icon_property_replacements = [
    ('icon: Icons.check_circle_outline,', 'icon: HeroIcons.checkCircle,'),
]

# Star icons in ratings (these use ternary)
# Icons.star_rounded : Icons.star_outline_rounded
# We replace the whole pattern
star_replacements = [
    ('Icons.star_rounded : Icons.star_outline_rounded', 'HeroIcons.star : HeroIcons.star'),
    ('Icons.star_rounded', 'HeroIcons.star'),
    ('Icons.star_outline_rounded', 'HeroIcons.star'),
]

# Payment method icons in credit tracker
payment_method_replacements = [
    ("Icons.account_balance_rounded : Icons.payments_outlined", "HeroIcons.buildingLibrary : HeroIcons.banknotes"),
]

# isCancelled ternary for close/arrow icons
cancelled_icon_replacements = [
    ("Icon(isCancelled ? Icons.close : (isPayment ? Icons.arrow_downward : Icons.arrow_upward), color: isCancelled ? Colors.grey : (isPayment ? kGoogleGreen : kErrorColor), size: 16)",
     "HeroIcon(isCancelled ? HeroIcons.xMark : (isPayment ? HeroIcons.arrowDown : HeroIcons.arrowUp), color: isCancelled ? Colors.grey : (isPayment ? kGoogleGreen : kErrorColor), size: 16)"),
]

# _isSearching ternary
search_ternary = [
    ("Icon(_isSearching ? Icons.close : Icons.search, size: 22)", "HeroIcon(_isSearching ? HeroIcons.xMark : HeroIcons.magnifyingGlass, size: 22)"),
]

# delete_outline_rounded : Icons.remove_rounded ternary
delete_ternary = [
    ("Icons.delete_outline_rounded : Icons.remove_rounded", "HeroIcons.trash : HeroIcons.minus"),
]

all_replacements = (replacements + detail_row_replacements + split_row_replacements +
    action_btn_replacements + icon_row_replacements + dialog_field_replacements +
    pay_option_replacements + dialog_option_replacements + sort_option_replacements +
    form_field_replacements + large_btn_replacements + icon_property_replacements +
    star_replacements + payment_method_replacements + cancelled_icon_replacements +
    search_ternary + delete_ternary)

total_replaced = 0
for old, new in all_replacements:
    count = content.count(old)
    if count > 0:
        content = content.replace(old, new)
        total_replaced += count
        print(f"  Replaced {count}x: {old[:60]}...")

after = content.count('Icons.')
print(f"\nTotal replacements made: {total_replaced}")
print(f"Icons. remaining: {after}")

# Show remaining Icons. lines
lines = content.split('\n')
for i, line in enumerate(lines, 1):
    if 'Icons.' in line:
        print(f"  Line {i}: {line.strip()[:150]}")

with open(r'C:\MaxBillUp\lib\Menu\Menu.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("\nDone!")

