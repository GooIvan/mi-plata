// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonSaveChanges => 'Save changes';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonArchive => 'Archive';

  @override
  String get commonRestore => 'Restore';

  @override
  String get commonUndo => 'Undo';

  @override
  String get commonOptions => 'Options';

  @override
  String get commonSeeAll => 'See all';

  @override
  String get commonSeeAllMasculine => 'See all';

  @override
  String get commonShowArchived => 'Show archived';

  @override
  String get commonHideArchived => 'Hide archived';

  @override
  String get commonIncomes => 'Income';

  @override
  String get commonExpenses => 'Expenses';

  @override
  String get commonNoCategory => 'No category';

  @override
  String get commonLoadError =>
      'The operation could not be completed. Check your connection and try again.';

  @override
  String get commonSessionExpired =>
      'Your session expired. Please sign in again.';

  @override
  String commonNameTooLong(int max) {
    return 'Use $max characters or fewer';
  }

  @override
  String get commonInvalidAmount =>
      'Invalid amount. Example: 1,500,000 or 1500.50';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authPasswordRepeatLabel => 'Repeat the password';

  @override
  String get authShowPassword => 'Show password';

  @override
  String get authHidePassword => 'Hide password';

  @override
  String get authLoginSubtitle => 'Sign in to continue';

  @override
  String get authRegisterSubtitle => 'Create your account to get started';

  @override
  String get authLoginButton => 'Sign in';

  @override
  String get authRegisterButton => 'Create account';

  @override
  String get authGoToRegister => 'Don\'t have an account? Sign up';

  @override
  String get authGoToLogin => 'Already have an account? Sign in';

  @override
  String get authConfirmEmailSent =>
      'We sent you an email to confirm your account. After that you can sign in.';

  @override
  String get authEmailRequired => 'Enter your email';

  @override
  String get authEmailInvalid => 'The email is not valid';

  @override
  String get authPasswordRequired => 'Enter your password';

  @override
  String get authNewPasswordRequired => 'Create a password';

  @override
  String authPasswordTooShort(int min) {
    return 'Use at least $min characters';
  }

  @override
  String get authPasswordRepeatRequired => 'Repeat your password';

  @override
  String get authPasswordMismatch => 'The passwords don\'t match';

  @override
  String get authErrorOffline =>
      'Could not reach the server. Check your internet and try again.';

  @override
  String get authErrorInvalidCredentials => 'Wrong email or password.';

  @override
  String get authErrorEmailExists =>
      'An account with that email already exists.';

  @override
  String get authErrorWeakPassword =>
      'The password is too weak. Use a longer or more varied one.';

  @override
  String get authErrorEmailNotConfirmed =>
      'Confirm your email before signing in.';

  @override
  String get authErrorRateLimit =>
      'Too many attempts. Wait a moment and try again.';

  @override
  String get authErrorSignupDisabled => 'Sign-ups are disabled.';

  @override
  String get authErrorGeneric =>
      'The operation could not be completed. Please try again.';

  @override
  String get dashboardTotalMoney => 'Total money';

  @override
  String get dashboardLoadMoneyError => 'Couldn\'t load your money.';

  @override
  String get dashboardNoAccounts => 'You don\'t have any accounts yet';

  @override
  String dashboardAccountsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'In $count accounts',
      one: 'In $count account',
    );
    return '$_temp0';
  }

  @override
  String get dashboardRecentTransactions => 'Recent transactions';

  @override
  String get dashboardNoTransactions =>
      'You haven\'t recorded any transactions yet.';

  @override
  String get dashboardDebtsLoadError => 'Couldn\'t load your debts.';

  @override
  String get dashboardDebtsEmpty => 'Record what you owe or are owed';

  @override
  String get dashboardYouOwe => 'You owe';

  @override
  String get dashboardOwedToYou => 'Owed to you';

  @override
  String get dashboardSummaryTooltip => 'Monthly summary';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'Phone language';

  @override
  String get settingsLanguageSpanish => 'Español';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsSession => 'Session';

  @override
  String settingsSignedInAs(String email) {
    return 'Signed in as $email';
  }

  @override
  String get settingsSignOut => 'Sign out';

  @override
  String get budgetsTitle => 'Budgets';

  @override
  String budgetsStatusOk(String amount) {
    return '$amount left';
  }

  @override
  String get budgetsStatusAtLimit => 'You reached the limit';

  @override
  String budgetsStatusNear(String amount) {
    return 'Close to the limit: $amount left';
  }

  @override
  String budgetsStatusOver(String amount) {
    return 'You went over by $amount';
  }

  @override
  String budgetsAlertOver(String category, String spent, String limit) {
    return 'You went over the $category budget: $spent of $limit.';
  }

  @override
  String budgetsAlertNear(
    int percent,
    String category,
    String spent,
    String limit,
  ) {
    return 'You\'re at $percent% of the $category budget ($spent of $limit).';
  }

  @override
  String get budgetsThisCategory => 'this category';

  @override
  String budgetsOverCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count categories over budget',
      one: '$count category over budget',
    );
    return '$_temp0';
  }

  @override
  String budgetsNearCount(int count) {
    return '$count close to the limit';
  }

  @override
  String budgetsOfLimit(String limit) {
    return 'of $limit';
  }

  @override
  String get accountsTitle => 'Accounts';

  @override
  String get accountsNew => 'New account';

  @override
  String get accountsEdit => 'Edit account';

  @override
  String get accountsCreateButton => 'Create account';

  @override
  String get accountsEmpty =>
      'You don\'t have any accounts yet.\nCreate the first one to get started.';

  @override
  String get accountsAllArchived => 'All your accounts are archived.';

  @override
  String get accountsArchivedMessage => 'Account archived';

  @override
  String get accountsRestoredMessage => 'Account restored';

  @override
  String get accountsArchivedTag => 'Archived';

  @override
  String accountsArchivedName(String name) {
    return '$name (archived)';
  }

  @override
  String get accountsNameLabel => 'Name';

  @override
  String get accountsNameHint => 'e.g. Savings account';

  @override
  String get accountsTypeLabel => 'Type';

  @override
  String get accountsInitialBalanceLabel => 'Initial balance';

  @override
  String get accountsInitialBalanceHint => 'e.g. 1,500,000';

  @override
  String get accountsInitialBalanceHelper =>
      'Leave it empty if it starts at zero';

  @override
  String get accountsChoose => 'Choose an account';

  @override
  String get accountTypeCash => 'Cash';

  @override
  String get accountTypeBank => 'Bank';

  @override
  String get accountTypeWallet => 'Digital wallet';

  @override
  String get accountTypeCard => 'Card';

  @override
  String get accountsNameRequired => 'Give the account a name';

  @override
  String get accountsErrorDuplicateName =>
      'You already have an active account with that name.';

  @override
  String get accountsErrorInvalidData =>
      'Check the data: the name cannot be empty.';

  @override
  String get accountsErrorAmountTooLarge => 'The amount is too large.';

  @override
  String get commonArchivedTag => 'Archived';

  @override
  String get categoriesTitle => 'Categories';

  @override
  String get categoriesNew => 'New category';

  @override
  String get categoriesCreateButton => 'Create category';

  @override
  String get categoriesArchivedMessage => 'Category archived';

  @override
  String get categoriesRestoredMessage => 'Category restored';

  @override
  String categoriesNewOfType(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'expense': 'New expense category',
      'income': 'New income category',
      'other': 'New category',
    });
    return '$_temp0';
  }

  @override
  String categoriesEditOfType(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'expense': 'Edit expense category',
      'income': 'Edit income category',
      'other': 'Edit category',
    });
    return '$_temp0';
  }

  @override
  String categoriesEmptyOfType(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'expense': 'You don\'t have any expense categories yet.',
      'income': 'You don\'t have any income categories yet.',
      'other': 'You don\'t have any categories yet.',
    });
    return '$_temp0';
  }

  @override
  String categoriesAllArchivedOfType(String type) {
    String _temp0 = intl.Intl.selectLogic(type, {
      'expense': 'All your expense categories are archived.',
      'income': 'All your income categories are archived.',
      'other': 'All your categories are archived.',
    });
    return '$_temp0';
  }

  @override
  String get categoriesNameLabel => 'Name';

  @override
  String get categoriesNameHint => 'e.g. Pets';

  @override
  String get categoriesNameRequired => 'Give the category a name';

  @override
  String get categoriesErrorDuplicateName =>
      'You already have an active category with that name.';

  @override
  String get categoriesErrorInvalidData =>
      'Check the data: the name cannot be empty.';

  @override
  String get commonAccount => 'Account';

  @override
  String get commonCategory => 'Category';

  @override
  String get commonAmount => 'Amount';

  @override
  String get commonDate => 'Date';

  @override
  String get commonAll => 'All';

  @override
  String get commonTransfers => 'Transfers';

  @override
  String get commonClear => 'Clear';

  @override
  String get commonApply => 'Apply';

  @override
  String get transactionTypeIncome => 'Income';

  @override
  String get transactionTypeExpense => 'Expense';

  @override
  String get transactionTypeTransfer => 'Transfer';

  @override
  String get transactionsTitle => 'Transactions';

  @override
  String get transactionsNew => 'New transaction';

  @override
  String get transactionsEdit => 'Edit transaction';

  @override
  String get transactionsRecord => 'Record';

  @override
  String get transactionsRecordOne => 'Record a transaction';

  @override
  String get transactionsEmpty =>
      'You haven\'t recorded any transactions yet.\nAdd the first one.';

  @override
  String get transactionsNoMatches => 'No transactions match these filters.';

  @override
  String get transactionsClearFilters => 'Clear filters';

  @override
  String get transactionsSearch => 'Search';

  @override
  String get transactionsSearchHint => 'Search descriptions';

  @override
  String get transactionsSearchClose => 'Close search';

  @override
  String get transactionsFilter => 'Filter';

  @override
  String transactionsRemoveFilter(String label) {
    return 'Remove filter: $label';
  }

  @override
  String get transactionsLoadMoreError => 'Couldn\'t load more transactions.';

  @override
  String get transactionsDateHelp => 'Transaction date';

  @override
  String get transactionsAmountHint => 'e.g. 150,000';

  @override
  String get transactionsFrom => 'From';

  @override
  String get transactionsTo => 'To';

  @override
  String get transactionsNeedAnotherAccount =>
      'You need another account to transfer';

  @override
  String get transactionsChooseDestination => 'Choose the destination account';

  @override
  String get transactionsNeedAccountFirst =>
      'Create an account first to record transactions.';

  @override
  String get transactionsDescriptionLabel => 'Description (optional)';

  @override
  String get transactionsDescriptionHint => 'e.g. Weekly groceries';

  @override
  String get transactionsDeleteTooltip => 'Delete transaction';

  @override
  String get transactionsDeleteTitle => 'Delete this transaction?';

  @override
  String get transactionsDeleteBody =>
      'Your account balances will be recalculated without this transaction.';

  @override
  String transactionsDeleteBodyWithWarning(String warnings) {
    return 'Your account balances will be recalculated without this transaction.\n\nHeads up:\n$warnings';
  }

  @override
  String get transactionsDeleted => 'Transaction deleted';

  @override
  String negativeBalanceMessage(String account, String balance) {
    return '$account will be left at $balance.';
  }

  @override
  String get negativeBalanceAdvice =>
      'If the amount is right, you can continue.';

  @override
  String get negativeBalanceFix => 'Fix it';

  @override
  String get negativeBalanceRecordTitle => 'Record it anyway?';

  @override
  String get negativeBalanceSaveTitle => 'Save it anyway?';

  @override
  String get negativeBalanceRecordAnyway => 'Record anyway';

  @override
  String get negativeBalanceSaveAnyway => 'Save anyway';

  @override
  String get transactionsFilterTitle => 'Filter transactions';

  @override
  String get transactionsFilterAllAccounts => 'All accounts';

  @override
  String get transactionsFilterAllCategories => 'All categories';

  @override
  String get transactionsFilterDates => 'Dates';

  @override
  String get transactionsFilterRemoveDates => 'Remove the dates';

  @override
  String get transactionsFilterAnyDate => 'Any date';

  @override
  String get transactionsFilterRangeHelp => 'Date range';

  @override
  String transactionsRangeBetween(String from, String to) {
    return 'from $from to $to';
  }

  @override
  String transactionsRangeSince(String from) {
    return 'since $from';
  }

  @override
  String transactionsRangeUntil(String to) {
    return 'until $to';
  }

  @override
  String get transactionsAmountRequired => 'Enter the amount';

  @override
  String get transactionsAmountNegative => 'The amount cannot be negative';

  @override
  String get transactionsAmountZero => 'The amount must be greater than zero';

  @override
  String get transactionsErrorInvalid =>
      'Check the transaction data: the amount, accounts and category.';

  @override
  String get transactionsErrorMissingReference =>
      'The account or category no longer exists. Reopen the form.';

  @override
  String get commonBack => 'Back';

  @override
  String get debtsTitle => 'Debts';

  @override
  String get debtsTabOwe => 'I owe';

  @override
  String get debtsTabOwed => 'Owed to me';

  @override
  String get debtsNew => 'New debt';

  @override
  String get debtsEdit => 'Edit debt';

  @override
  String get debtsRegister => 'Record a debt';

  @override
  String get debtsEmptyPayable =>
      'You haven\'t recorded any debts you owe yet.';

  @override
  String get debtsEmptyReceivable =>
      'You haven\'t recorded any debts owed to you yet.';

  @override
  String get debtsAllArchived => 'All the debts in this list are archived.';

  @override
  String get debtsTotalPayable => 'You owe in total';

  @override
  String get debtsTotalReceivable => 'Owed to you in total';

  @override
  String debtsOfAmount(String amount) {
    return 'of $amount';
  }

  @override
  String get debtStatusSettled => 'Settled';

  @override
  String get debtStatusNoDueDate => 'No due date';

  @override
  String debtStatusOverdue(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Overdue by $days days',
      one: 'Overdue by $days day',
    );
    return '$_temp0';
  }

  @override
  String get debtStatusDueToday => 'Due today';

  @override
  String get debtStatusDueTomorrow => 'Due tomorrow';

  @override
  String debtStatusDueInDays(int days) {
    return 'Due in $days days';
  }

  @override
  String debtStatusDueOn(String date) {
    return 'Due $date';
  }

  @override
  String get debtsPickStartHelp => 'Start date';

  @override
  String get debtsPickDueHelp => 'Due date';

  @override
  String get debtsCounterpartyPayable => 'Who you owe';

  @override
  String get debtsCounterpartyReceivable => 'Who owes you';

  @override
  String get debtsCounterpartyHint => 'e.g. John';

  @override
  String get debtsAmountLabel => 'Total amount';

  @override
  String get debtsAmountHint => 'e.g. 500,000';

  @override
  String get debtsStartLabel => 'Start';

  @override
  String get debtsDueLabel => 'Due date (optional)';

  @override
  String get debtsNoDate => 'No date';

  @override
  String get debtsRemoveDue => 'Remove the due date';

  @override
  String get debtsNotesLabel => 'Notes (optional)';

  @override
  String get debtsRegisterMoney => 'Record the money in an account';

  @override
  String get debtsRegisterMoneyNeedAccount => 'Create an account first.';

  @override
  String get debtsRegisterMoneyPayable =>
      'The money you borrowed goes into the account.';

  @override
  String get debtsRegisterMoneyReceivable =>
      'The money you lent comes out of the account.';

  @override
  String get debtsReceiveIn => 'Receive in';

  @override
  String get debtsTakeFrom => 'Take from';

  @override
  String get debtsCreate => 'Create debt';

  @override
  String get debtsLockedNote =>
      'The direction and start date can\'t be changed. The amount can\'t be less than what\'s already been paid.';

  @override
  String get debtsCounterpartyRequired => 'Enter the person\'s name';

  @override
  String get debtsDueBeforeStart =>
      'The due date cannot be before the start date';

  @override
  String debtsPaymentExceeds(String remaining) {
    return 'It can\'t exceed what\'s remaining ($remaining)';
  }

  @override
  String debtsAmountBelowPaid(String paid) {
    return 'It can\'t be less than what\'s already paid ($paid)';
  }

  @override
  String get debtsArchivedMessage => 'Debt archived';

  @override
  String get debtsRestoredMessage => 'Debt restored';

  @override
  String get debtsGone => 'This debt no longer exists.';

  @override
  String get debtsRecordPayment => 'Record payment';

  @override
  String get debtsIsSettledNote => 'This debt is already settled.';

  @override
  String get debtsIsArchivedNote =>
      'It\'s archived: restore it to record payments.';

  @override
  String get debtsPaymentsTitle => 'Payments';

  @override
  String debtsYouOweTo(String name) {
    return 'You owe $name';
  }

  @override
  String debtsOwesYou(String name) {
    return '$name owes you';
  }

  @override
  String get debtsRemainingWord => 'remaining';

  @override
  String debtsPaidAmount(String amount) {
    return 'Paid $amount';
  }

  @override
  String debtsTotalAmount(String amount) {
    return 'Total $amount';
  }

  @override
  String debtsSince(String date) {
    return 'Since $date';
  }

  @override
  String get debtsPaymentDeleteTitle => 'Delete this payment?';

  @override
  String get debtsPaymentDeleteBody =>
      'Its transaction is deleted too and the account balance is recalculated.';

  @override
  String get debtsPaymentDeleted => 'Payment deleted';

  @override
  String get debtsPaymentsEmpty => 'No payments yet.';

  @override
  String get debtsPaymentDeleteTooltip => 'Delete payment';

  @override
  String debtsPaySheetTitlePayable(String name) {
    return 'Pay $name';
  }

  @override
  String debtsPaymentDescriptionPayable(String name) {
    return 'Payment to $name';
  }

  @override
  String debtsPaymentDescriptionReceivable(String name) {
    return 'Payment from $name';
  }

  @override
  String debtsPendingAmount(String amount) {
    return 'Remaining: $amount';
  }

  @override
  String get debtsPaymentAmountLabel => 'Payment amount';

  @override
  String get debtsPaymentAmountHint => 'e.g. 100,000';

  @override
  String get debtsPayAll => 'Pay all';

  @override
  String get debtsCollectAll => 'Collect all';

  @override
  String debtsNeedCurrencyAccount(String currency) {
    return 'Create an account in $currency first to record the payment.';
  }

  @override
  String get debtsPayFrom => 'Pay from';

  @override
  String get debtsPaymentDateHelp => 'Payment date';

  @override
  String get debtsErrorInvalid => 'Check the debt data: the amount and dates.';

  @override
  String get debtsErrorMissingReference =>
      'The account or debt no longer exists. Reopen the screen.';

  @override
  String commonPercent(int percent) {
    return '$percent%';
  }

  @override
  String get commonPercentUnderOne => '<1%';

  @override
  String get summaryTitle => 'Monthly summary';

  @override
  String get summaryNoData =>
      'There are no transactions to summarize yet.\nRecord income and expenses to see your summary.';

  @override
  String get summaryPreviousMonth => 'Previous month';

  @override
  String get summaryNextMonth => 'Next month';

  @override
  String get summaryBalanceOfMonth => 'Balance for the month';

  @override
  String get summaryBalanceUp => 'You earned more than you spent';

  @override
  String get summaryBalanceDown => 'You spent more than you earned';

  @override
  String get summaryBalanceEven => 'Income and expenses are equal';

  @override
  String get summaryWhereMoneyGoes => 'Where does the money go?';

  @override
  String get summaryWhereMoneyComes => 'Where does it come from?';

  @override
  String get summaryNoExpensesMonth => 'There are no expenses this month.';

  @override
  String get summaryNoIncomeMonth => 'There is no income this month.';

  @override
  String get summaryOtherCategories => 'Other';

  @override
  String get summaryBudgetsLink =>
      'How much you have spent of what you planned';

  @override
  String get summaryHistoryError => 'Couldn\'t load the money evolution.';

  @override
  String get summaryLoadError =>
      'Couldn\'t load the summary. Check your connection and try again.';

  @override
  String summarySameAs(String month) {
    return 'Same as in $month';
  }

  @override
  String summaryZeroIn(String month) {
    return '\$0 in $month';
  }

  @override
  String summaryNoExpensesIn(String month) {
    return 'No expenses in $month';
  }

  @override
  String summaryNoIncomeIn(String month) {
    return 'No income in $month';
  }

  @override
  String summaryMoreThan(String amount, String month) {
    return '$amount more than in $month';
  }

  @override
  String summaryLessThan(String amount, String month) {
    return '$amount less than in $month';
  }

  @override
  String get summaryPaceTitle => 'Spending pace';

  @override
  String get summaryDailyAverage => 'Daily average';

  @override
  String get summaryProjectedClose => 'At this pace, the month will close at';

  @override
  String summaryProjection(String comparison) {
    return 'Projection: $comparison';
  }

  @override
  String summaryCalculatedPartial(int counted, int total) {
    return 'Calculated over $counted of $total days of the month.';
  }

  @override
  String summaryCalculatedFull(int total) {
    return 'Calculated over the $total days of the month.';
  }

  @override
  String get summaryTrendTitle => 'Income vs. expenses';

  @override
  String summaryLastMonths(int count) {
    return 'Last $count months';
  }

  @override
  String summaryTrendSemantics(int count) {
    return 'Bar chart with income and expenses for the last $count months. The same information is available as a table.';
  }

  @override
  String summaryTrendTooltip(String month, String series, String amount) {
    return '$month\n$series: $amount';
  }

  @override
  String get summaryHideTable => 'Hide table';

  @override
  String get summaryShowTable => 'View as table';

  @override
  String get summaryTableMonth => 'Month';

  @override
  String get summaryHistorySubtitle => 'At the end of each month';

  @override
  String summaryHistorySemantics(int count) {
    return 'Line chart with the total money at the end of each of the last $count months. The same information is available as a table.';
  }

  @override
  String get summaryHistoryHideTable => 'Hide balance table';

  @override
  String get summaryHistoryShowTable => 'View balances as table';

  @override
  String get summaryHistoryTableClosing => 'Closing of';

  @override
  String get summarySincePrevious => 'the previous month';

  @override
  String summarySinceMonths(int months) {
    return '$months months ago';
  }

  @override
  String summaryDeltaUp(String amount, String since) {
    return '$amount more than $since';
  }

  @override
  String summaryDeltaDown(String amount, String since) {
    return '$amount less than $since';
  }

  @override
  String summaryDeltaSame(String since) {
    return 'Same as $since';
  }

  @override
  String get budgetsNew => 'New budget';

  @override
  String get budgetsEmptyEditable =>
      'Set how much you want to spend each month in each category and see how you are doing.';

  @override
  String get budgetsEmptyPast =>
      'There were no budgets or expenses this month.';

  @override
  String get budgetsDefine => 'Set a budget';

  @override
  String get budgetsGoToCurrentMonth => 'Go to the current month';

  @override
  String get budgetsWithBudget => 'With a budget';

  @override
  String get budgetsWithoutBudget => 'Spending without a budget';

  @override
  String get budgetsTapToDefine => 'Tap to set a budget';

  @override
  String get budgetsTotalTitle => 'Total budget';

  @override
  String budgetsTotalOf(String amount) {
    return 'of $amount budgeted';
  }

  @override
  String budgetsFormTitleFixed(String name) {
    return 'Budget for $name';
  }

  @override
  String get budgetsFormTheCategory => 'the category';

  @override
  String budgetsFormAppliesFrom(String month, int year) {
    return 'Applies from $month $year onward, until you change it. Earlier months are not touched.';
  }

  @override
  String get budgetsFormAllBudgeted =>
      'All your expense categories already have a budget.';

  @override
  String get budgetsFormChooseCategory => 'Choose a category';

  @override
  String get budgetsFormCategoryLabel => 'Expense category';

  @override
  String get budgetsFormAmountLabel => 'Monthly amount';

  @override
  String get budgetsFormAmountHint => 'e.g. 800,000';

  @override
  String get budgetsFormRemove => 'Remove the budget';

  @override
  String get budgetsErrorInvalid => 'Check the budget amount.';

  @override
  String get budgetsErrorMissingCategory =>
      'The category no longer exists. Reopen the screen.';

  @override
  String budgetsPercent(int percent) {
    return '$percent%';
  }

  @override
  String get dbErrorTransactionCategoryMismatch =>
      'The chosen category does not match this type of transaction';

  @override
  String get dbErrorTransferCurrencyMismatch =>
      'A transfer requires accounts in the same currency';

  @override
  String get dbErrorBudgetExpenseOnly =>
      'Only expense categories can have a budget';

  @override
  String get dbErrorPaymentDirectionMismatch =>
      'The payment doesn\'t match the type of debt';

  @override
  String get dbErrorPaymentCurrencyMismatch =>
      'The payment must come from an account in the debt\'s currency';

  @override
  String get dbErrorPaymentExceedsRemaining =>
      'The payment exceeds what is left to pay';

  @override
  String get dbErrorDebtAmountBelowPaid =>
      'The amount can\'t be less than what has already been paid';

  @override
  String get dbErrorDebtDirectionLocked =>
      'A debt\'s direction can\'t be changed once it has payments';

  @override
  String get dbErrorPaymentTypeLocked =>
      'This transaction is a debt payment: its type can\'t be changed';

  @override
  String get dbErrorDebtArchived =>
      'The debt is archived: restore it to record payments';

  @override
  String debtsLoanDescriptionPayable(String name) {
    return 'Loan from $name';
  }

  @override
  String debtsLoanDescriptionReceivable(String name) {
    return 'Loan to $name';
  }

  @override
  String get currencyNameCop => 'Colombian peso';

  @override
  String get currencyNameUsd => 'US dollar';

  @override
  String get currencyNameEur => 'Euro';

  @override
  String get currencyNameMxn => 'Mexican peso';

  @override
  String get currencyNameArs => 'Argentine peso';

  @override
  String get currencyNameBrl => 'Brazilian real';

  @override
  String get currencyNameClp => 'Chilean peso';

  @override
  String get currencyNamePen => 'Peruvian sol';

  @override
  String get currencyNameGbp => 'Pound sterling';

  @override
  String get currencyNameCad => 'Canadian dollar';

  @override
  String get currencyLabel => 'Currency';

  @override
  String currencyOption(String code, String name) {
    return '$code · $name';
  }

  @override
  String currencyMissingRates(String currencies) {
    return 'No exchange rate for $currencies: not included in the total.';
  }

  @override
  String get currencyMissingRatesAction => 'Set rate';

  @override
  String get settingsCurrency => 'Currency';

  @override
  String get settingsBaseCurrency => 'Base currency';

  @override
  String settingsBaseCurrencyValue(String code, String name) {
    return '$code · $name';
  }

  @override
  String get settingsExchangeRates => 'Exchange rates';

  @override
  String get settingsExchangeRatesHelp =>
      'What each currency is worth in your base currency';

  @override
  String get baseCurrencyTitle => 'Base currency';

  @override
  String get baseCurrencyIntro =>
      'All your money, summaries and budgets are shown in this currency.';

  @override
  String baseCurrencyRateLabel(String next, String previous) {
    return '1 $next is worth ($previous)';
  }

  @override
  String baseCurrencyRateHelp(String next) {
    return 'Needed to convert your rates and budgets to $next.';
  }

  @override
  String get baseCurrencyChangeButton => 'Change base currency';

  @override
  String get ratesTitle => 'Exchange rates';

  @override
  String ratesIntro(String base) {
    return 'To add up the money in your accounts in other currencies, set what each one is worth in $base. Totals use today\'s rate.';
  }

  @override
  String get ratesEmpty =>
      'You have no accounts or debts in other currencies.\nWhen you do, set their rates here.';

  @override
  String get ratesNoRate => 'No rate';

  @override
  String ratesOneEquals(String currency, String amount) {
    return '1 $currency = $amount';
  }

  @override
  String get ratesUpdatedToday => 'Updated today';

  @override
  String get ratesUpdatedYesterday => 'Updated yesterday';

  @override
  String ratesUpdatedDaysAgo(int days) {
    return 'Updated $days days ago';
  }

  @override
  String get ratesAdd => 'Add rate';

  @override
  String ratesFormTitle(String currency) {
    return '$currency rate';
  }

  @override
  String ratesFormAmountLabel(String currency) {
    return '1 $currency is worth';
  }

  @override
  String get ratesFormHint => 'e.g. 4,000';

  @override
  String get ratesFormInvalid =>
      'Enter a rate greater than zero. Example: 4,012.5';

  @override
  String get ratesFormRemove => 'Remove the rate';

  @override
  String get ratesFormChooseCurrency => 'Choose a currency';

  @override
  String get ratesErrorInvalid =>
      'Check the rate: it must be greater than zero.';

  @override
  String get accountsCurrencyLocked =>
      'An account\'s currency can\'t be changed.';

  @override
  String accountsRateLabel(String currency) {
    return '1 $currency is worth (optional)';
  }

  @override
  String get accountsRateHelp =>
      'Without a rate, this account isn\'t added to your total money.';

  @override
  String transactionsAmountOut(String currency) {
    return 'Amount sent ($currency)';
  }

  @override
  String transactionsAmountIn(String currency) {
    return 'Amount received ($currency)';
  }

  @override
  String transactionsImpliedRate(String from, String rate, String to) {
    return '1 $from = $rate $to';
  }

  @override
  String transactionsReceives(String amount) {
    return 'receives $amount';
  }

  @override
  String summaryConvertedNote(String base) {
    return 'Amounts in other currencies are converted to $base at today\'s rate.';
  }

  @override
  String get dbErrorRateForBaseCurrency =>
      'The base currency does not need an exchange rate';

  @override
  String get dbErrorBaseRateRequired =>
      'The new currency needs a rate to convert your rates and budgets';

  @override
  String get dbErrorTransferDestinationRequired =>
      'A transfer between different currencies needs the amount received';

  @override
  String get dbErrorTransferDestinationUnexpected =>
      'The amount received is only given for transfers between different currencies';

  @override
  String get recurringTitle => 'Recurring payments';

  @override
  String get recurringNew => 'New recurring payment';

  @override
  String get recurringEdit => 'Edit recurring payment';

  @override
  String get recurringCreateButton => 'Create recurring payment';

  @override
  String get recurringEmpty =>
      'You haven\'t recorded any recurring payments yet.\nAdd your subscriptions, rent and anything you pay regularly.';

  @override
  String get recurringEmptyAction => 'Record a recurring payment';

  @override
  String get recurringDashboardEmpty => 'Record your subscriptions and rent';

  @override
  String get recurringNothingSoon => 'You have no upcoming payments.';

  @override
  String recurringNextOne(String name, String date) {
    return 'Next: $name · $date';
  }

  @override
  String get recurringSectionActive => 'Active';

  @override
  String get recurringSectionOther => 'Paused or finished';

  @override
  String recurringStatusOverdue(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Overdue by $days days',
      one: 'Overdue by $days day',
    );
    return '$_temp0';
  }

  @override
  String get recurringStatusToday => 'Upcoming payment: due today';

  @override
  String get recurringStatusTomorrow => 'Upcoming payment: due tomorrow';

  @override
  String recurringStatusSoon(int days) {
    return 'Upcoming payment: due in $days days';
  }

  @override
  String recurringStatusLater(String date) {
    return 'Next payment on $date';
  }

  @override
  String get recurringStatusPaused => 'Paused';

  @override
  String get recurringStatusFinished => 'Finished';

  @override
  String recurrenceEveryWeek(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Every $n weeks',
      one: 'Every week',
    );
    return '$_temp0';
  }

  @override
  String recurrenceEveryMonth(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Every $n months',
      one: 'Every month',
    );
    return '$_temp0';
  }

  @override
  String recurrenceEveryYear(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Every $n years',
      one: 'Every year',
    );
    return '$_temp0';
  }

  @override
  String get recurringNameLabel => 'Name';

  @override
  String get recurringNameHint => 'e.g. Netflix, Rent';

  @override
  String get recurringNameRequired => 'Give the payment a name';

  @override
  String get recurringAccountLabel => 'Paid from';

  @override
  String get recurringFrequencyLabel => 'Frequency';

  @override
  String get recurringNextLabel => 'Next payment';

  @override
  String get recurringNextHelp =>
      'The date it\'s due. After that it\'s worked out for you.';

  @override
  String get recurringEndLabel => 'Ends (optional)';

  @override
  String get recurringNoEnd => 'No end date';

  @override
  String get recurringRemoveEnd => 'Remove the end date';

  @override
  String get recurringPickNextHelp => 'Next payment date';

  @override
  String get recurringPickEndHelp => 'End date';

  @override
  String get recurringEndBeforeNext =>
      'The end date cannot be before the next payment';

  @override
  String get recurringReminderNote =>
      'Nothing is deducted until you confirm you paid.';

  @override
  String get recurringPayAction => 'I paid';

  @override
  String get recurringSkipAction => 'Skip this payment';

  @override
  String get recurringPause => 'Pause';

  @override
  String get recurringResume => 'Resume';

  @override
  String get recurringDelete => 'Delete';

  @override
  String get recurringDeleteTitle => 'Delete this recurring payment?';

  @override
  String get recurringDeleteBody =>
      'The payments you already recorded are kept.';

  @override
  String get recurringPausedMessage => 'Payment paused';

  @override
  String get recurringResumedMessage => 'Payment resumed';

  @override
  String get recurringDeletedMessage => 'Recurring payment deleted';

  @override
  String get recurringGone => 'This recurring payment no longer exists.';

  @override
  String get recurringHistoryTitle => 'Recorded payments';

  @override
  String get recurringHistoryEmpty => 'You haven\'t recorded any payments yet.';

  @override
  String recurringEndsOn(String date) {
    return 'Ends on $date';
  }

  @override
  String recurringConfirmTitle(String name) {
    return 'Payment for $name';
  }

  @override
  String get recurringConfirmButton => 'Confirm payment';

  @override
  String get recurringConfirmDateHelp => 'Payment date';

  @override
  String get recurringConfirmedMessage => 'Payment recorded';

  @override
  String get recurringSkippedMessage => 'Payment skipped';

  @override
  String get recurringErrorGone =>
      'The recurring payment no longer exists. Reopen the screen.';

  @override
  String get recurringErrorInvalid =>
      'Check the payment data: the name, amount and dates.';

  @override
  String get dbErrorRecurringFinished =>
      'This recurring payment has already ended';

  @override
  String get dbErrorRecurringCategory =>
      'Only expense categories can be used in a recurring payment';

  @override
  String get debtsInstallmentsSwitch => 'Pay in installments';

  @override
  String get debtsInstallmentsSwitchHelp =>
      'We\'ll remind you when each installment is due, and you record it as a payment on the debt.';

  @override
  String get debtsInstallmentsCount => 'Number of installments';

  @override
  String get debtsInstallmentsCountHint => 'e.g. 12';

  @override
  String get debtsInstallmentsCountInvalid =>
      'Enter how many installments (1 to 360)';

  @override
  String get debtsInstallmentsAmount => 'Installment amount';

  @override
  String get debtsInstallmentsAmountHelp =>
      'Usually the total divided by the number of installments.';

  @override
  String get debtsInstallmentsFrequency => 'How often';

  @override
  String get debtsInstallmentsFirst => 'First installment';

  @override
  String get debtsInstallmentsFirstHelp => 'First installment date';

  @override
  String get debtsInstallmentsPayFrom => 'Pay installments from';

  @override
  String installmentNumber(int number, int total) {
    return 'Installment $number of $total';
  }

  @override
  String get debtsPlanTitle => 'Installment plan';

  @override
  String recurringDebtRemaining(String amount) {
    return 'Left to pay: $amount';
  }

  @override
  String get recurringDeletePlanBody =>
      'The debt and the payments you already recorded are kept.';

  @override
  String get dbErrorInstallmentDirection =>
      'Only debts you owe can be paid in installments';

  @override
  String get dbErrorInstallmentCurrency =>
      'The installments\' account must be in the debt\'s currency';

  @override
  String get goalsTitle => 'Savings goals';

  @override
  String get goalsNew => 'New goal';

  @override
  String get goalsEdit => 'Edit goal';

  @override
  String get goalsCreateButton => 'Create goal';

  @override
  String get goalsEmpty =>
      'You have no goals yet. A goal is an amount you want to save up in an account: what you\'ve saved is that account\'s balance.';

  @override
  String get goalsAllArchived => 'All your goals are archived.';

  @override
  String get goalsDashboardEmpty =>
      'Save up for something: create a savings goal.';

  @override
  String get goalsNameLabel => 'Name';

  @override
  String get goalsNameHint => 'Trip, bike, emergency fund';

  @override
  String get goalsNameRequired => 'Enter the goal\'s name';

  @override
  String get goalsTargetLabel => 'How much do you want to save';

  @override
  String get goalsTargetPositive => 'The goal must be greater than zero';

  @override
  String get goalsAccountLabel => 'Account where you save';

  @override
  String get goalsAccountHelp =>
      'What you\'ve saved is this account\'s balance. To save, move money into it.';

  @override
  String get goalsAccountLocked => 'A goal\'s account can\'t be changed.';

  @override
  String get goalsAccountRequired => 'Choose the goal\'s account';

  @override
  String get goalsNoFreeAccount =>
      'You have no free account: each account can back only one goal, and cards can\'t.';

  @override
  String get goalsNewAccount => 'Create a new account';

  @override
  String get goalsDeadlineLabel => 'Deadline (optional)';

  @override
  String get goalsDeadlineNone => 'No deadline';

  @override
  String get goalsDeadlineClear => 'Remove the date';

  @override
  String goalsSavedOf(String saved, String target) {
    return '$saved of $target';
  }

  @override
  String goalsRemaining(String amount) {
    return '$amount to go';
  }

  @override
  String goalsDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days left',
      one: '$count day left',
      zero: 'due today',
    );
    return '$_temp0';
  }

  @override
  String get goalsStatusReached => 'Goal reached!';

  @override
  String goalsStatusOverdue(String date, String amount) {
    return 'Was due $date · $amount to go';
  }

  @override
  String get goalsArchivedLabel => 'Archived';

  @override
  String goalsAccountArchivedNote(String name) {
    return 'The account $name is archived: you can\'t save into it anymore.';
  }

  @override
  String goalsSuggestMonthly(String amount) {
    return 'To get there on time, save $amount a month.';
  }

  @override
  String goalsSuggestBefore(String amount, String date) {
    return 'To get there on time, save $amount by $date.';
  }

  @override
  String goalsDeadlineOn(String date) {
    return 'By $date';
  }

  @override
  String get goalsReachedHint =>
      'When you no longer need it, archive it to free up its account.';

  @override
  String get goalsSave => 'Save';

  @override
  String get goalsWithdraw => 'Withdraw';

  @override
  String goalsAccountRow(String name) {
    return 'Account: $name';
  }

  @override
  String get goalsHistoryTitle => 'Goal activity';

  @override
  String get goalsHistoryEmpty =>
      'You haven\'t saved anything in this account yet.';

  @override
  String goalsMovementFrom(String account) {
    return 'From $account';
  }

  @override
  String goalsMovementTo(String account) {
    return 'To $account';
  }

  @override
  String get goalsArchive => 'Archive';

  @override
  String get goalsRestore => 'Restore';

  @override
  String get goalsArchivedMessage => 'Goal archived';

  @override
  String get goalsRestoredMessage => 'Goal restored';

  @override
  String get goalsGone => 'This goal no longer exists.';

  @override
  String get goalsErrorInvalid => 'Check the goal\'s details.';

  @override
  String get goalsErrorAccountTaken =>
      'That account already has another active goal.';

  @override
  String get goalsErrorMissingAccount => 'The chosen account no longer exists.';

  @override
  String get dbErrorGoalAccountCard =>
      'A card can\'t be the account of a savings goal';

  @override
  String get navHome => 'Home';

  @override
  String get navGoals => 'Goals';

  @override
  String get navMore => 'More';

  @override
  String get navTransactions => 'Activity';

  @override
  String get accountsCardLimitLabel => 'Credit limit (optional)';

  @override
  String get accountsCardLimitHelper =>
      'The most the bank lets you spend with the card';

  @override
  String get accountsCardLimitInvalid =>
      'The limit has to be an amount above zero';

  @override
  String get accountsCardStatementDayLabel => 'Statement day (optional)';

  @override
  String get accountsCardStatementDayHelper =>
      'The day of the month your statement closes';

  @override
  String get accountsCardPaymentDayLabel => 'Payment due day (optional)';

  @override
  String get accountsCardPaymentDayHelper =>
      'The day of the month you must pay by';

  @override
  String get accountsCardDayInvalid => 'Enter a day from 1 to 31';

  @override
  String get accountsCardDaysTogether => 'Give both days, or leave both empty';

  @override
  String get accountsCardInitialBalanceHelper =>
      'What you already owe, with a minus sign (e.g. -200,000). Empty if it starts at zero';

  @override
  String accountsCardUsedOf(String used, String limit) {
    return 'Used $used of $limit';
  }

  @override
  String accountsCardAvailable(String amount) {
    return '$amount available';
  }

  @override
  String accountsCardOverLimit(String amount) {
    return 'Over the limit by $amount';
  }

  @override
  String accountsCardDates(String statement, String payment) {
    return 'Statement $statement · Pay by $payment';
  }
}
