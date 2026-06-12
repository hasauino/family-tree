import 'package:flutter/widgets.dart';

import '../config.dart';

/// Lightweight, dependency-free localization for the app's UI strings.
///
/// English and Arabic live in [_values] below; to add a language, add a new
/// `languageCode` map here and the matching [Locale] to
/// [AppConfig.supportedLocales]. Arabic flips the layout to RTL automatically
/// (handled by Flutter once `ar` is the active locale).
///
/// Usage in a widget:
///
///   final t = AppStrings.of(context);
///   Text(t.appTitle);
class AppStrings {
  AppStrings(this.locale);

  final Locale locale;

  /// The strings for the locale currently in scope.
  static AppStrings of(BuildContext context) =>
      Localizations.of<AppStrings>(context, AppStrings)!;

  /// Plug this into `MaterialApp.localizationsDelegates`.
  static const LocalizationsDelegate<AppStrings> delegate =
      _AppStringsDelegate();

  String _t(String key) {
    final code = locale.languageCode;
    return _values[code]?[key] ?? _values['en']![key] ?? key;
  }

  String get appTitle => _t('appTitle');
  String get cancel => _t('cancel');
  String get fitTreeTooltip => _t('fitTreeTooltip');
  String get reloadTooltip => _t('reloadTooltip');

  // Theme (light / dark / auto)
  String get themeModeLight => _t('themeModeLight');
  String get themeModeDark => _t('themeModeDark');
  String get themeModeAuto => _t('themeModeAuto');
  String themeToggleTooltip(String mode) =>
      _t('themeToggleTooltip').replaceFirst('{mode}', mode);
  String get noData => _t('noData');
  String get noDetails => _t('noDetails');
  String get centerTreeHere => _t('centerTreeHere');
  String get retry => _t('retry');
  String get errorConnection => _t('errorConnection');

  // Tree path ("from ancestor to descendant")
  String get treePathTooltip => _t('treePathTooltip');
  String get treePathTitle => _t('treePathTitle');
  String get treePathFromLabel => _t('treePathFromLabel');
  String get treePathToLabel => _t('treePathToLabel');
  String get treePathFromHint => _t('treePathFromHint');
  String get treePathToHint => _t('treePathToHint');
  String get treePathPickHint => _t('treePathPickHint');
  String get treePathGo => _t('treePathGo');
  String get errorNoPath => _t('errorNoPath');
  String get treePathResultTitle => _t('treePathResultTitle');
  String treePathDirectLine(String ancestor, String descendant) =>
      _t('treePathDirectLine')
          .replaceFirst('{ancestor}', ancestor)
          .replaceFirst('{descendant}', descendant);
  String treePathApart(int count) =>
      _t('treePathApart').replaceFirst('{count}', '$count');
  String treePathMeetAt(String name) =>
      _t('treePathMeetAt').replaceFirst('{name}', name);
  String treePathGenerationsAway(String name, int count) =>
      _t('treePathGenerationsAway')
          .replaceFirst('{name}', name)
          .replaceFirst('{count}', '$count');

  // Search
  String get searchTooltip => _t('searchTooltip');
  String get searchHint => _t('searchHint');
  String get searchError => _t('searchError');
  String get searchNoResults => _t('searchNoResults');

  // Account / auth
  String get login => _t('login');
  String get logout => _t('logout');
  String get account => _t('account');

  // Account page (profile editing, photo, deletion)
  String get fatherNameLabel => _t('fatherNameLabel');
  String get grandfatherNameLabel => _t('grandfatherNameLabel');
  String get birthPlaceLabel => _t('birthPlaceLabel');
  String get birthDateLabel => _t('birthDateLabel');
  String get changePhoto => _t('changePhoto');
  String get chooseFromGallery => _t('chooseFromGallery');
  String get takePhoto => _t('takePhoto');
  String get removePhoto => _t('removePhoto');
  String get profileUpdated => _t('profileUpdated');
  String get imageUpdateError => _t('imageUpdateError');
  String get deleteAccount => _t('deleteAccount');
  String get deleteAccountTitle => _t('deleteAccountTitle');
  String get deleteAccountConfirm => _t('deleteAccountConfirm');
  String get accountDeleted => _t('accountDeleted');

  // Admin: database restore
  String get restoreDatabase => _t('restoreDatabase');
  String get restorePointPrompt => _t('restorePointPrompt');
  String get noRestorePoints => _t('noRestorePoints');
  String get restore => _t('restore');
  String restoreConfirm(String label) =>
      _t('restoreConfirm').replaceFirst('{label}', label);
  String get restoreSuccess => _t('restoreSuccess');
  String get restoreError => _t('restoreError');
  String get loginTitle => _t('loginTitle');
  String get loginInvalid => _t('loginInvalid');
  String get usernameLabel => _t('usernameLabel');
  String get passwordLabel => _t('passwordLabel');
  String get fieldRequired => _t('fieldRequired');
  String get signIn => _t('signIn');
  String get signUp => _t('signUp');
  String get signInTab => _t('signInTab');
  String get signUpTab => _t('signUpTab');
  String get emailLabel => _t('emailLabel');
  String get emailOrUsernameLabel => _t('emailOrUsernameLabel');
  String get confirmPasswordLabel => _t('confirmPasswordLabel');
  String get firstNameLabel => _t('firstNameLabel');
  String get lastNameLabel => _t('lastNameLabel');
  String get passwordsDontMatch => _t('passwordsDontMatch');
  String get invalidEmail => _t('invalidEmail');
  String get createAccount => _t('createAccount');
  String get noAccountPrompt => _t('noAccountPrompt');
  String get haveAccountPrompt => _t('haveAccountPrompt');
  String get orDivider => _t('orDivider');
  String get continueWithGoogle => _t('continueWithGoogle');
  String get continueWithApple => _t('continueWithApple');
  String get continueWithFacebook => _t('continueWithFacebook');
  String get verifyCodeTitle => _t('verifyCodeTitle');
  String verifyCodeBody(String email) =>
      _t('verifyCodeBody').replaceFirst('{email}', email);
  String get verifyCodeButton => _t('verifyCodeButton');
  String get codeResend => _t('codeResend');
  String get codeResent => _t('codeResent');
  String get codeInvalid => _t('codeInvalid');
  String get codeExpired => _t('codeExpired');
  String get codeTooManyAttempts => _t('codeTooManyAttempts');
  String get codeResendTooSoon => _t('codeResendTooSoon');
  String get backToSignIn => _t('backToSignIn');
  String get forgotPassword => _t('forgotPassword');
  String get forgotPasswordTitle => _t('forgotPasswordTitle');
  String get resetEmailPrompt => _t('resetEmailPrompt');
  String get sendResetCode => _t('sendResetCode');
  String resetCodeSentBody(String email) =>
      _t('resetCodeSentBody').replaceFirst('{email}', email);
  String get newPasswordLabel => _t('newPasswordLabel');
  String get resetPasswordButton => _t('resetPasswordButton');
  String get authGenericError => _t('authGenericError');

  // Person actions
  String get add => _t('add');
  String get addChildren => _t('addChildren');
  String get addChildrenTitle => _t('addChildrenTitle');
  String get childNameLabel => _t('childNameLabel');
  String get childNamesHint => _t('childNamesHint');
  String get childrenAdded => _t('childrenAdded');
  String get moveNode => _t('moveNode');
  String get moveNodeTitle => _t('moveNodeTitle');
  String get addParent => _t('addParent');
  String get addParentTitle => _t('addParentTitle');
  String get parentNameLabel => _t('parentNameLabel');
  String get parentAdded => _t('parentAdded');
  String get nodeMoved => _t('nodeMoved');
  String get selectParentHint => _t('selectParentHint');
  String get edit => _t('edit');
  String get editPersonTitle => _t('editPersonTitle');
  String get save => _t('save');
  String get nameLabel => _t('nameLabel');
  String get designationLabel => _t('designationLabel');
  String get historyLabel => _t('historyLabel');
  String get personUpdated => _t('personUpdated');
  String get delete => _t('delete');
  String get deleteTitle => _t('deleteTitle');
  String get personDeleted => _t('personDeleted');
  String get publish => _t('publish');
  String get unpublish => _t('unpublish');
  String get published => _t('published');
  String get unpublished => _t('unpublished');
  String get bookmark => _t('bookmark');
  String get removeBookmark => _t('removeBookmark');
  String get bookmarked => _t('bookmarked');
  String get bookmarkRemoved => _t('bookmarkRemoved');

  // Home screen
  String get homeTitle => _t('homeTitle');
  String get noBookmarks => _t('noBookmarks');
  String get openTreeTooltip => _t('openTreeTooltip');

  // Tag management
  String get createTagTooltip => _t('createTagTooltip');
  String get createTagTitle => _t('createTagTitle');
  String get tagNameLabel => _t('tagNameLabel');
  String get tagCreated => _t('tagCreated');
  String get renameTagTitle => _t('renameTagTitle');
  String get tagRenamed => _t('tagRenamed');
  String get deleteTagTitle => _t('deleteTagTitle');
  String get tagDeleted => _t('tagDeleted');
  String get assignTag => _t('assignTag');
  String get noTag => _t('noTag');
  String get tagAssigned => _t('tagAssigned');
  String get parentTagLabel => _t('parentTagLabel');
  String get topLevelTag => _t('topLevelTag');
  String get moveTagTitle => _t('moveTagTitle');
  String get tagMoved => _t('tagMoved');
  String get goHomeTooltip => _t('goHomeTooltip');
  String get setHomeCenter => _t('setHomeCenter');
  String get resetHomeCenter => _t('resetHomeCenter');
  String get homeCenterUpdated => _t('homeCenterUpdated');
  String get nodeSizeSettingsTooltip => _t('nodeSizeSettingsTooltip');
  String get nodeSizeSettingsTitle => _t('nodeSizeSettingsTitle');
  String get nodeMaxScaleLabel => _t('nodeMaxScaleLabel');
  String get nodeMinScaleLabel => _t('nodeMinScaleLabel');
  String get nodeSizeDecayLabel => _t('nodeSizeDecayLabel');
  String get nodePaddingLabel => _t('nodePaddingLabel');
  String get nodeSpreadLabel => _t('nodeSpreadLabel');
  String get nodeEdgeLengthLabel => _t('nodeEdgeLengthLabel');
  String get nodeSizeSettingsHelp => _t('nodeSizeSettingsHelp');
  String get nodeSizeSettingsInvalid => _t('nodeSizeSettingsInvalid');
  String get nodeSizeSettingsUpdated => _t('nodeSizeSettingsUpdated');
  String get editStyleTitle => _t('editStyleTitle');
  String get nodeColorLabel => _t('nodeColorLabel');
  String get fontColorLabel => _t('fontColorLabel');
  String get fontSizeLabel => _t('fontSizeLabel');
  String get colorHexHint => _t('colorHexHint');
  String get resetToDefault => _t('resetToDefault');
  String get styleUpdated => _t('styleUpdated');
  String get styleInvalid => _t('styleInvalid');
  String get rootLabelLabel => _t('rootLabelLabel');
  String get rootLabelHint => _t('rootLabelHint');
  String get nodeLabelLabel => _t('nodeLabelLabel');
  String get nodeLabelHint => _t('nodeLabelHint');

  String deleteTagConfirm(String name) =>
      _t('deleteTagConfirm').replaceFirst('{name}', name);

  String deleteConfirm(String name) =>
      _t('deleteConfirm').replaceFirst('{name}', name);

  String deleteOrphanConfirm(String name) =>
      _t('deleteOrphanConfirm').replaceFirst('{name}', name);

  String deleteCascadeConfirm(String name, int count) => _t(
    'deleteCascadeConfirm',
  ).replaceFirst('{name}', name).replaceFirst('{count}', '$count');

  String childrenAddedWarning(String names) =>
      _t('childrenAddedWarning').replaceFirst('{names}', names);

  String errorPersonNotFound(int id) =>
      _t('errorPersonNotFound').replaceFirst('{id}', '$id');

  // Notifications (bell + list)
  String get notificationsTooltip => _t('notificationsTooltip');
  String get notificationsTitle => _t('notificationsTitle');
  String get notificationsEmpty => _t('notificationsEmpty');
  String get markAllRead => _t('markAllRead');
  String get notifKindPending => _t('notifKindPending');
  String get notifKindVerified => _t('notifKindVerified');
  String get notifKindChanged => _t('notifKindChanged');
  String get notifKindBroadcast => _t('notifKindBroadcast');
  String get timeJustNow => _t('timeJustNow');
  String timeMinutesAgo(int n) => _t('timeMinutesAgo').replaceFirst('{n}', '$n');
  String timeHoursAgo(int n) => _t('timeHoursAgo').replaceFirst('{n}', '$n');
  String timeDaysAgo(int n) => _t('timeDaysAgo').replaceFirst('{n}', '$n');

  // Notification bodies (built client-side so they're in the reader's language)
  String get listSeparator => _t('listSeparator');
  String notifAndMore(int n) => _t('notifAndMore').replaceFirst('{n}', '$n');
  String notifBodyAddedOne(String user, String name) => _t('notifBodyAddedOne')
      .replaceFirst('{user}', user)
      .replaceFirst('{name}', name);
  String notifBodyAddedMany(String user, int count, String list) =>
      _t('notifBodyAddedMany')
          .replaceFirst('{user}', user)
          .replaceFirst('{count}', '$count')
          .replaceFirst('{list}', list);
  String notifBodyVerifiedOne(String name) =>
      _t('notifBodyVerifiedOne').replaceFirst('{name}', name);
  String notifBodyVerifiedMany(int count, String list) =>
      _t('notifBodyVerifiedMany')
          .replaceFirst('{count}', '$count')
          .replaceFirst('{list}', list);
  String notifBodyChanged(String name, String fields) => _t('notifBodyChanged')
      .replaceFirst('{name}', name)
      .replaceFirst('{fields}', fields);
  String get notifFieldName => _t('notifFieldName');
  String get notifFieldDesignation => _t('notifFieldDesignation');
  String get notifFieldHistory => _t('notifFieldHistory');
  String get notifFieldParent => _t('notifFieldParent');

  // Admin verification screen
  String get verificationTitle => _t('verificationTitle');
  String get verificationEmpty => _t('verificationEmpty');
  String get verificationNoMatch => _t('verificationNoMatch');
  String get verifySearchHint => _t('verifySearchHint');
  String get verifyAnyUser => _t('verifyAnyUser');
  String get verifyDateFilter => _t('verifyDateFilter');
  String get verifyClearFilters => _t('verifyClearFilters');
  String get verifySelectAll => _t('verifySelectAll');
  String get verifyDeselectAll => _t('verifyDeselectAll');
  String get verifyOpen => _t('verifyOpen');
  String get verifyAction => _t('verifyAction');
  String get verifyConfirmTitle => _t('verifyConfirmTitle');
  String verifyConfirmBody(int n) => _t('verifyConfirmBody').replaceFirst('{n}', '$n');
  String verifyDone(int n) => _t('verifyDone').replaceFirst('{n}', '$n');
  String verifyCount(int n) => _t('verifyCount').replaceFirst('{n}', '$n');
  String verifyBy(String names) => _t('verifyBy').replaceFirst('{names}', names);
  String verifyPublishSelected(int n) =>
      _t('verifyPublishSelected').replaceFirst('{n}', '$n');
  String verifyPublishAll(int n) => _t('verifyPublishAll').replaceFirst('{n}', '$n');

  // Admin broadcast composer
  String get broadcastTitle => _t('broadcastTitle');
  String get broadcastIntro => _t('broadcastIntro');
  String get broadcastTitleLabel => _t('broadcastTitleLabel');
  String get broadcastBodyLabel => _t('broadcastBodyLabel');
  String get broadcastTitleRequired => _t('broadcastTitleRequired');
  String get broadcastBodyRequired => _t('broadcastBodyRequired');
  String get broadcastSend => _t('broadcastSend');
  String get broadcastConfirmTitle => _t('broadcastConfirmTitle');
  String get broadcastConfirmBody => _t('broadcastConfirmBody');
  String broadcastDone(int n) => _t('broadcastDone').replaceFirst('{n}', '$n');

  // Account menu entries (admin)
  String get menuVerifyAdditions => _t('menuVerifyAdditions');
  String get menuBroadcast => _t('menuBroadcast');

  static const Map<String, Map<String, String>> _values = {
    'en': {
      'appTitle': 'Family Tree',
      'cancel': 'Cancel',
      'fitTreeTooltip': 'Fit tree to window',
      'reloadTooltip': 'Reload',
      // Notifications
      'notificationsTooltip': 'Notifications',
      'notificationsTitle': 'Notifications',
      'notificationsEmpty': 'No notifications yet',
      'markAllRead': 'Mark all as read',
      'notifKindPending': 'New additions to verify',
      'notifKindVerified': 'Your additions were published',
      'notifKindChanged': 'Your entry was updated',
      'notifKindBroadcast': 'Announcement',
      'timeJustNow': 'just now',
      'timeMinutesAgo': '{n} min ago',
      'timeHoursAgo': '{n} h ago',
      'timeDaysAgo': '{n} d ago',
      'listSeparator': ', ',
      'notifAndMore': 'and {n} more',
      'notifBodyAddedOne': '{user} added {name}',
      'notifBodyAddedMany': '{user} added {count} people: {list}',
      'notifBodyVerifiedOne': '“{name}” was published',
      'notifBodyVerifiedMany': '{count} of your additions were published: {list}',
      'notifBodyChanged': 'Your entry “{name}” was updated ({fields})',
      'notifFieldName': 'name',
      'notifFieldDesignation': 'designation',
      'notifFieldHistory': 'history',
      'notifFieldParent': 'parent',
      // Verification
      'verificationTitle': 'Verify additions',
      'verificationEmpty': 'Nothing to verify — all additions are published.',
      'verificationNoMatch': 'No additions match your filters.',
      'verifySearchHint': 'Search by name',
      'verifyAnyUser': 'Any contributor',
      'verifyDateFilter': 'Filter by date',
      'verifyClearFilters': 'Clear filters',
      'verifySelectAll': 'Select all',
      'verifyDeselectAll': 'Deselect all',
      'verifyOpen': 'Open in tree',
      'verifyAction': 'Verify',
      'verifyConfirmTitle': 'Verify additions?',
      'verifyConfirmBody': 'Publish {n} addition(s)? They will become visible to everyone.',
      'verifyDone': '{n} addition(s) published',
      'verifyCount': '{n} shown',
      'verifyBy': 'by {names}',
      'verifyPublishSelected': 'Verify {n} selected',
      'verifyPublishAll': 'Verify all {n}',
      // Broadcast
      'broadcastTitle': 'Send announcement',
      'broadcastIntro': 'Send a notification to every user — for example a greeting or an important note.',
      'broadcastTitleLabel': 'Title',
      'broadcastBodyLabel': 'Message',
      'broadcastTitleRequired': 'Enter a title',
      'broadcastBodyRequired': 'Enter a message',
      'broadcastSend': 'Send to all',
      'broadcastConfirmTitle': 'Send to all users?',
      'broadcastConfirmBody': 'This message will be sent to every user.',
      'broadcastDone': 'Sent to {n} user(s)',
      // Account menu
      'menuVerifyAdditions': 'Verify additions',
      'menuBroadcast': 'Send announcement',
      'themeModeLight': 'Light',
      'themeModeDark': 'Dark',
      'themeModeAuto': 'Auto',
      'themeToggleTooltip': 'Theme: {mode} (tap to change)',
      'noData': 'No data.',
      'noDetails': 'No further details.',
      'centerTreeHere': 'Center tree here',
      'retry': 'Retry',
      'errorConnection':
          'Could not load the family tree. Check your connection and try again.',
      'errorPersonNotFound': 'Person #{id} was not found.',
      'treePathTooltip': 'Show how two people are connected',
      'treePathTitle': 'Connect two people',
      'treePathFromLabel': 'Person A',
      'treePathToLabel': 'Person B',
      'treePathFromHint': 'Search for the first person',
      'treePathToHint': 'Search for the second person',
      'treePathPickHint': 'Tap to choose a person',
      'treePathGo': 'Go',
      'errorNoPath':
          'These two people are not connected in the tree.',
      'treePathResultTitle': 'Connection',
      'treePathDirectLine': '{ancestor} is a direct ancestor of {descendant}.',
      'treePathApart': '{count} generations apart',
      'treePathMeetAt': 'They meet at {name}',
      'treePathGenerationsAway': '{name}: {count} generations away',
      'searchTooltip': 'Search by name',
      'searchHint': 'Search by name',
      'searchError': 'Search failed. Check your connection and try again.',
      'searchNoResults': 'No matching people found.',
      'login': 'Login',
      'logout': 'Logout',
      'account': 'Account',
      'fatherNameLabel': "Father's name",
      'grandfatherNameLabel': "Grandfather's name",
      'birthPlaceLabel': 'Place of birth',
      'birthDateLabel': 'Date of birth',
      'changePhoto': 'Change photo',
      'chooseFromGallery': 'Choose from gallery',
      'takePhoto': 'Take photo',
      'removePhoto': 'Remove photo',
      'profileUpdated': 'Profile updated.',
      'imageUpdateError': 'Could not update the photo. Please try again.',
      'deleteAccount': 'Delete account',
      'deleteAccountTitle': 'Delete account',
      'deleteAccountConfirm':
          'This will permanently delete your account and sign you out. '
          'This cannot be undone. Continue?',
      'accountDeleted': 'Your account has been deleted.',
      'restoreDatabase': 'Restore database',
      'restorePointPrompt': 'Pick a restore point of the database:',
      'noRestorePoints': 'No restore points are available yet.',
      'restore': 'Restore',
      'restoreConfirm':
          'This will replace the entire database with the backup from '
          '{label}. Any changes made since then will be lost. Continue?',
      'restoreSuccess': 'Database restored.',
      'restoreError': 'Could not restore the database. Please try again.',
      'loginTitle': 'Sign in',
      'loginInvalid': 'Invalid username or password.',
      'usernameLabel': 'Username',
      'passwordLabel': 'Password',
      'fieldRequired': 'This field is required.',
      'signIn': 'Sign In',
      'signUp': 'Sign Up',
      'signInTab': 'Sign in',
      'signUpTab': 'Sign up',
      'emailLabel': 'Email',
      'emailOrUsernameLabel': 'Email or username',
      'confirmPasswordLabel': 'Confirm password',
      'firstNameLabel': 'First name',
      'lastNameLabel': 'Last name',
      'passwordsDontMatch': 'Passwords do not match.',
      'invalidEmail': 'Enter a valid email address.',
      'createAccount': 'Create account',
      'noAccountPrompt': "Don't have an account? Sign up",
      'haveAccountPrompt': 'Already have an account? Sign in',
      'orDivider': 'or',
      'continueWithGoogle': 'Continue with Google',
      'continueWithApple': 'Continue with Apple',
      'continueWithFacebook': 'Continue with Facebook',
      'verifyCodeTitle': 'Enter the code',
      'verifyCodeBody':
          'We sent a 6-digit code to {email}. Enter it below to verify your '
          'account.',
      'verifyCodeButton': 'Verify',
      'codeResend': 'Resend code',
      'codeResent': 'A new code has been sent.',
      'codeInvalid': "That code isn't right. Please try again.",
      'codeExpired': 'This code has expired. Tap Resend to get a new one.',
      'codeTooManyAttempts': 'Too many attempts. Tap Resend to get a new code.',
      'codeResendTooSoon': 'Please wait a moment before requesting another code.',
      'backToSignIn': 'Back to sign in',
      'forgotPassword': 'Forgot password?',
      'forgotPasswordTitle': 'Reset password',
      'resetEmailPrompt':
          "Enter your account email and we'll send you a reset code.",
      'sendResetCode': 'Send code',
      'resetCodeSentBody':
          'We sent a code to {email}. Enter it with your new password.',
      'newPasswordLabel': 'New password',
      'resetPasswordButton': 'Reset password',
      'authGenericError': 'Something went wrong. Please try again.',
      'add': 'Add',
      'addChildren': 'Add children',
      'addChildrenTitle': 'Add children',
      'childNameLabel': "Child's name",
      'childNamesHint': 'Enter a name then tap +',
      'childrenAdded': 'Children added.',
      'childrenAddedWarning': 'Children added. Already existed: {names}',
      'moveNode': 'Move',
      'moveNodeTitle': 'Move to new parent',
      'addParent': 'Add parent',
      'addParentTitle': 'Add a parent',
      'parentNameLabel': "Parent's name",
      'parentAdded': 'Parent added.',
      'nodeMoved': 'Person moved.',
      'selectParentHint': 'Search for the new parent',
      'edit': 'Edit',
      'editPersonTitle': 'Edit person',
      'save': 'Save',
      'nameLabel': 'Name',
      'designationLabel': 'Designation (optional)',
      'historyLabel': 'Historical background (optional)',
      'personUpdated': 'Changes saved.',
      'delete': 'Delete',
      'deleteTitle': 'Delete person',
      'deleteConfirm': 'Do you really want to delete {name}?',
      'deleteOrphanConfirm':
          'Deleting {name} will make their child the new root. Continue?',
      'deleteCascadeConfirm':
          'Deleting {name} will permanently delete {count} descendant(s). Continue?',
      'personDeleted': 'Person deleted.',
      'publish': 'Publish',
      'unpublish': 'Unpublish',
      'published': 'Published.',
      'unpublished': 'Unpublished.',
      'bookmark': 'Bookmark',
      'removeBookmark': 'Remove bookmark',
      'bookmarked': 'Bookmarked.',
      'bookmarkRemoved': 'Bookmark removed.',
      'homeTitle': 'Family Tree',
      'noBookmarks':
          'No bookmarks yet.\nOpen the tree and bookmark people to see them here.',
      'openTreeTooltip': 'Open full tree',
      'createTagTooltip': 'New tag',
      'createTagTitle': 'New tag',
      'tagNameLabel': 'Tag name',
      'tagCreated': 'Tag created.',
      'renameTagTitle': 'Rename tag',
      'tagRenamed': 'Tag renamed.',
      'deleteTagTitle': 'Delete tag',
      'deleteTagConfirm':
          'Delete tag "{name}"? Bookmarks will become untagged.',
      'tagDeleted': 'Tag deleted.',
      'assignTag': 'Assign tag',
      'noTag': 'No tag (floating)',
      'tagAssigned': 'Tag updated.',
      'parentTagLabel': 'Parent tag',
      'topLevelTag': 'Top level (no parent)',
      'moveTagTitle': 'Move tag',
      'tagMoved': 'Tag moved.',
      'goHomeTooltip': 'Back to home',
      'setHomeCenter': 'Set as home center',
      'resetHomeCenter': 'Reset home center',
      'homeCenterUpdated': 'Home center updated.',
      'nodeSizeSettingsTooltip': 'Node size settings',
      'nodeSizeSettingsTitle': 'Node size settings',
      'nodeMaxScaleLabel': 'Root node size',
      'nodeMinScaleLabel': 'Leaf node size',
      'nodeSizeDecayLabel': 'Shrink rate',
      'nodePaddingLabel': 'Cluster spacing',
      'nodeSpreadLabel': 'Spread angle (°)',
      'nodeEdgeLengthLabel': 'Max edge length (×)',
      'nodeSizeSettingsHelp':
          'Controls how node size shrinks with distance from the tree root. '
          'Higher shrink rate makes the difference between root and leaf '
          'nodes more pronounced.',
      'nodeSizeSettingsInvalid':
          'Enter valid, positive numbers (leaf size ≤ root size).',
      'nodeSizeSettingsUpdated': 'Node size settings updated.',
      'editStyleTitle': 'Edit style',
      'nodeColorLabel': 'Node color',
      'fontColorLabel': 'Font color',
      'fontSizeLabel': 'Font size',
      'colorHexHint': 'RRGGBB',
      'resetToDefault': 'Reset to default',
      'styleUpdated': 'Style updated.',
      'styleInvalid': 'Colors must be 6 hex digits (RRGGBB) or empty.',
      'rootLabelLabel': 'Root label',
      'rootLabelHint': 'Leave empty for the default icon',
      'nodeLabelLabel': 'Label',
      'nodeLabelHint': 'Leave empty for the default name',
    },
    'ar': {
      'appTitle': 'شجرة العائلة',
      'cancel': 'إلغاء',
      'fitTreeTooltip': 'ملاءمة الشجرة للنافذة',
      // Notifications
      'notificationsTooltip': 'الإشعارات',
      'notificationsTitle': 'الإشعارات',
      'notificationsEmpty': 'لا توجد إشعارات بعد',
      'markAllRead': 'تعليم الكل كمقروء',
      'notifKindPending': 'إضافات جديدة للمراجعة',
      'notifKindVerified': 'تم نشر إضافاتك',
      'notifKindChanged': 'تم تحديث مُدخلك',
      'notifKindBroadcast': 'إعلان',
      'timeJustNow': 'الآن',
      'timeMinutesAgo': 'قبل {n} دقيقة',
      'timeHoursAgo': 'قبل {n} ساعة',
      'timeDaysAgo': 'قبل {n} يوم',
      'listSeparator': '، ',
      'notifAndMore': 'و{n} غيرها',
      'notifBodyAddedOne': 'أضاف {user} {name}',
      'notifBodyAddedMany': 'أضاف {user} {count} أشخاص: {list}',
      'notifBodyVerifiedOne': 'تم نشر «{name}»',
      'notifBodyVerifiedMany': 'تم نشر {count} من إضافاتك: {list}',
      'notifBodyChanged': 'تم تحديث مُدخلك «{name}» ({fields})',
      'notifFieldName': 'الاسم',
      'notifFieldDesignation': 'اللقب',
      'notifFieldHistory': 'النبذة التاريخية',
      'notifFieldParent': 'الأب',
      // Verification
      'verificationTitle': 'مراجعة الإضافات',
      'verificationEmpty': 'لا شيء للمراجعة — كل الإضافات منشورة.',
      'verificationNoMatch': 'لا توجد إضافات تطابق عوامل التصفية.',
      'verifySearchHint': 'البحث بالاسم',
      'verifyAnyUser': 'أي مساهم',
      'verifyDateFilter': 'تصفية حسب التاريخ',
      'verifyClearFilters': 'مسح عوامل التصفية',
      'verifySelectAll': 'تحديد الكل',
      'verifyDeselectAll': 'إلغاء تحديد الكل',
      'verifyOpen': 'فتح في الشجرة',
      'verifyAction': 'اعتماد',
      'verifyConfirmTitle': 'اعتماد الإضافات؟',
      'verifyConfirmBody': 'نشر {n} إضافة؟ ستصبح ظاهرة للجميع.',
      'verifyDone': 'تم نشر {n} إضافة',
      'verifyCount': '{n} ظاهرة',
      'verifyBy': 'بواسطة {names}',
      'verifyPublishSelected': 'اعتماد {n} محددة',
      'verifyPublishAll': 'اعتماد الكل ({n})',
      // Broadcast
      'broadcastTitle': 'إرسال إعلان',
      'broadcastIntro': 'أرسل إشعارًا إلى كل المستخدمين — مثل تهنئة أو ملاحظة مهمة.',
      'broadcastTitleLabel': 'العنوان',
      'broadcastBodyLabel': 'الرسالة',
      'broadcastTitleRequired': 'أدخل عنوانًا',
      'broadcastBodyRequired': 'أدخل رسالة',
      'broadcastSend': 'إرسال للجميع',
      'broadcastConfirmTitle': 'إرسال لكل المستخدمين؟',
      'broadcastConfirmBody': 'سترسل هذه الرسالة إلى كل مستخدم.',
      'broadcastDone': 'أُرسلت إلى {n} مستخدم',
      // Account menu
      'menuVerifyAdditions': 'مراجعة الإضافات',
      'menuBroadcast': 'إرسال إعلان',
      'reloadTooltip': 'إعادة التحميل',
      'themeModeLight': 'فاتح',
      'themeModeDark': 'داكن',
      'themeModeAuto': 'تلقائي',
      'themeToggleTooltip': 'المظهر: {mode} (اضغط للتغيير)',
      'noData': 'لا توجد بيانات.',
      'noDetails': 'لا توجد تفاصيل إضافية.',
      'centerTreeHere': 'اجعل الشجرة هنا',
      'retry': 'إعادة المحاولة',
      'errorConnection':
          'تعذّر تحميل شجرة العائلة. تحقّق من اتصالك وحاول مرة أخرى.',
      'errorPersonNotFound': 'لم يتم العثور على الشخص رقم {id}.',
      'treePathTooltip': 'عرض صلة القرابة بين شخصين',
      'treePathTitle': 'الربط بين شخصين',
      'treePathFromLabel': 'الشخص الأول',
      'treePathToLabel': 'الشخص الثاني',
      'treePathFromHint': 'ابحث عن الشخص الأول',
      'treePathToHint': 'ابحث عن الشخص الثاني',
      'treePathPickHint': 'اضغط لاختيار شخص',
      'treePathGo': 'انتقال',
      'errorNoPath':
          'لا توجد صلة بين هذين الشخصين في الشجرة.',
      'treePathResultTitle': 'صلة القرابة',
      'treePathDirectLine': '{ancestor} جدٌّ مباشر لـ {descendant}.',
      'treePathApart': 'يفصل بينهما {count} أجيال',
      'treePathMeetAt': 'يلتقيان عند {name}',
      'treePathGenerationsAway': '{name}: يبعد {count} أجيال',
      'searchTooltip': 'البحث بالاسم',
      'searchHint': 'البحث بالاسم',
      'searchError': 'فشل البحث. تحقّق من اتصالك وحاول مرة أخرى.',
      'searchNoResults': 'لا يوجد أشخاص مطابقون.',
      'login': 'تسجيل الدخول',
      'logout': 'تسجيل الخروج',
      'account': 'الحساب',
      'fatherNameLabel': 'اسم الأب',
      'grandfatherNameLabel': 'اسم الجد',
      'birthPlaceLabel': 'مكان الميلاد',
      'birthDateLabel': 'تاريخ الميلاد',
      'changePhoto': 'تغيير الصورة',
      'chooseFromGallery': 'اختيار من المعرض',
      'takePhoto': 'التقاط صورة',
      'removePhoto': 'إزالة الصورة',
      'profileUpdated': 'تم تحديث الملف الشخصي.',
      'imageUpdateError': 'تعذّر تحديث الصورة. حاول مرة أخرى.',
      'deleteAccount': 'حذف الحساب',
      'deleteAccountTitle': 'حذف الحساب',
      'deleteAccountConfirm':
          'سيؤدي هذا إلى حذف حسابك نهائيًا وتسجيل خروجك. لا يمكن التراجع عن '
          'هذا الإجراء. هل تريد المتابعة؟',
      'accountDeleted': 'تم حذف حسابك.',
      'restoreDatabase': 'استعادة قاعدة البيانات',
      'restorePointPrompt': 'اختر نقطة استعادة لقاعدة البيانات:',
      'noRestorePoints': 'لا توجد نقاط استعادة متاحة بعد.',
      'restore': 'استعادة',
      'restoreConfirm':
          'سيؤدي هذا إلى استبدال قاعدة البيانات بالكامل بالنسخة الاحتياطية من '
          '{label}. ستُفقد أي تغييرات أُجريت بعد ذلك. هل تريد المتابعة؟',
      'restoreSuccess': 'تمت استعادة قاعدة البيانات.',
      'restoreError': 'تعذّرت استعادة قاعدة البيانات. حاول مرة أخرى.',
      'loginTitle': 'تسجيل الدخول',
      'loginInvalid': 'اسم المستخدم أو كلمة المرور غير صحيحة.',
      'usernameLabel': 'اسم المستخدم',
      'passwordLabel': 'كلمة المرور',
      'fieldRequired': 'هذا الحقل مطلوب.',
      'signIn': 'دخول',
      'signUp': 'إنشاء حساب',
      'signInTab': 'تسجيل الدخول',
      'signUpTab': 'إنشاء حساب',
      'emailLabel': 'البريد الإلكتروني',
      'emailOrUsernameLabel': 'البريد الإلكتروني أو اسم المستخدم',
      'confirmPasswordLabel': 'تأكيد كلمة المرور',
      'firstNameLabel': 'الاسم الأول',
      'lastNameLabel': 'اسم العائلة',
      'passwordsDontMatch': 'كلمتا المرور غير متطابقتين.',
      'invalidEmail': 'أدخل بريدًا إلكترونيًا صحيحًا.',
      'createAccount': 'إنشاء حساب',
      'noAccountPrompt': 'ليس لديك حساب؟ أنشئ حسابًا',
      'haveAccountPrompt': 'لديك حساب بالفعل؟ سجّل الدخول',
      'orDivider': 'أو',
      'continueWithGoogle': 'المتابعة باستخدام Google',
      'continueWithApple': 'المتابعة باستخدام Apple',
      'continueWithFacebook': 'المتابعة باستخدام Facebook',
      'verifyCodeTitle': 'أدخل الرمز',
      'verifyCodeBody':
          'أرسلنا رمزًا مكوّنًا من 6 أرقام إلى {email}. أدخله أدناه للتحقّق من حسابك.',
      'verifyCodeButton': 'تحقّق',
      'codeResend': 'إعادة إرسال الرمز',
      'codeResent': 'تم إرسال رمز جديد.',
      'codeInvalid': 'الرمز غير صحيح. يرجى المحاولة مرة أخرى.',
      'codeExpired': 'انتهت صلاحية الرمز. اضغط "إعادة الإرسال" للحصول على رمز جديد.',
      'codeTooManyAttempts': 'محاولات كثيرة جدًا. اضغط "إعادة الإرسال" للحصول على رمز جديد.',
      'codeResendTooSoon': 'يرجى الانتظار قليلًا قبل طلب رمز آخر.',
      'backToSignIn': 'العودة إلى تسجيل الدخول',
      'forgotPassword': 'هل نسيت كلمة المرور؟',
      'forgotPasswordTitle': 'إعادة تعيين كلمة المرور',
      'resetEmailPrompt': 'أدخل بريدك الإلكتروني وسنرسل لك رمز إعادة التعيين.',
      'sendResetCode': 'إرسال الرمز',
      'resetCodeSentBody': 'أرسلنا رمزًا إلى {email}. أدخله مع كلمة المرور الجديدة.',
      'newPasswordLabel': 'كلمة المرور الجديدة',
      'resetPasswordButton': 'إعادة تعيين كلمة المرور',
      'authGenericError': 'حدث خطأ ما. يرجى المحاولة مرة أخرى.',
      'add': 'إضافة',
      'addChildren': 'إضافة أبناء',
      'addChildrenTitle': 'إضافة أبناء',
      'childNameLabel': 'اسم الابن',
      'childNamesHint': 'أدخل اسمًا ثم اضغط +',
      'childrenAdded': 'تمت إضافة الأبناء.',
      'childrenAddedWarning': 'تمت الإضافة. موجود مسبقًا: {names}',
      'moveNode': 'نقل',
      'moveNodeTitle': 'نقل إلى أب جديد',
      'addParent': 'إضافة أب',
      'addParentTitle': 'إضافة أب جديد',
      'parentNameLabel': 'اسم الأب',
      'parentAdded': 'تمت إضافة الأب.',
      'nodeMoved': 'تم نقل الشخص.',
      'selectParentHint': 'ابحث عن الأب الجديد',
      'edit': 'تعديل',
      'editPersonTitle': 'تعديل شخص',
      'save': 'حفظ',
      'nameLabel': 'الاسم',
      'designationLabel': 'اللقب (اختياري)',
      'historyLabel': 'النبذة التاريخية (اختياري)',
      'personUpdated': 'تم حفظ التغييرات.',
      'delete': 'حذف',
      'deleteTitle': 'حذف شخص',
      'deleteConfirm': 'هل تريد حقًّا حذف {name}؟',
      'deleteOrphanConfirm':
          'حذف {name} سيجعل ابنه الجذرَ الجديد. هل تريد المتابعة؟',
      'deleteCascadeConfirm':
          'حذف {name} سيحذف {count} من أحفاده نهائيًا. هل تريد المتابعة؟',
      'personDeleted': 'تم حذف الشخص.',
      'publish': 'نشر',
      'unpublish': 'إلغاء النشر',
      'published': 'تم النشر.',
      'unpublished': 'تم إلغاء النشر.',
      'bookmark': 'إضافة إشارة مرجعية',
      'removeBookmark': 'إزالة الإشارة المرجعية',
      'bookmarked': 'تمت إضافة الإشارة المرجعية.',
      'bookmarkRemoved': 'تمت إزالة الإشارة المرجعية.',
      'homeTitle': 'شجرة العائلة',
      'noBookmarks':
          'لا توجد إشارات مرجعية بعد.\nافتح الشجرة وأضف إشارات مرجعية لتظهر هنا.',
      'openTreeTooltip': 'فتح الشجرة الكاملة',
      'createTagTooltip': 'تصنيف جديد',
      'createTagTitle': 'تصنيف جديد',
      'tagNameLabel': 'اسم التصنيف',
      'tagCreated': 'تم إنشاء التصنيف.',
      'renameTagTitle': 'إعادة تسمية التصنيف',
      'tagRenamed': 'تم تغيير اسم التصنيف.',
      'deleteTagTitle': 'حذف التصنيف',
      'deleteTagConfirm': 'حذف التصنيف "{name}"؟ ستصبح الإشارات غير مصنّفة.',
      'tagDeleted': 'تم حذف التصنيف.',
      'assignTag': 'تعيين تصنيف',
      'noTag': 'بدون تصنيف',
      'tagAssigned': 'تم تحديث التصنيف.',
      'parentTagLabel': 'التصنيف الأب',
      'topLevelTag': 'المستوى الأعلى (بدون أب)',
      'moveTagTitle': 'نقل التصنيف',
      'tagMoved': 'تم نقل التصنيف.',
      'goHomeTooltip': 'العودة إلى الرئيسية',
      'setHomeCenter': 'اجعله مركز الصفحة الرئيسية',
      'resetHomeCenter': 'إعادة تعيين مركز الصفحة الرئيسية',
      'homeCenterUpdated': 'تم تحديث مركز الصفحة الرئيسية.',
      'nodeSizeSettingsTooltip': 'إعدادات حجم العقد',
      'nodeSizeSettingsTitle': 'إعدادات حجم العقد',
      'nodeMaxScaleLabel': 'حجم العقدة الجذرية',
      'nodeMinScaleLabel': 'حجم العقد الطرفية',
      'nodeSizeDecayLabel': 'معدل التصغير',
      'nodePaddingLabel': 'تباعد المجموعات',
      'nodeSpreadLabel': 'زاوية الانتشار (°)',
      'nodeEdgeLengthLabel': 'أقصى طول للحافة (×)',
      'nodeSizeSettingsHelp':
          'يتحكم في كيفية تصغير حجم العقد كلما ابتعدنا عن جذر الشجرة. '
          'كلما زاد معدل التصغير، زاد الفرق بين حجم العقدة الجذرية والعقد الطرفية.',
      'nodeSizeSettingsInvalid':
          'أدخل أرقامًا موجبة وصحيحة (حجم العقدة الطرفية ≤ حجم العقدة الجذرية).',
      'nodeSizeSettingsUpdated': 'تم تحديث إعدادات حجم العقد.',
      'editStyleTitle': 'تعديل المظهر',
      'nodeColorLabel': 'لون العقدة',
      'fontColorLabel': 'لون الخط',
      'fontSizeLabel': 'حجم الخط',
      'colorHexHint': 'RRGGBB',
      'resetToDefault': 'إعادة التعيين إلى الافتراضي',
      'styleUpdated': 'تم تحديث المظهر.',
      'styleInvalid':
          'يجب أن تكون الألوان 6 أرقام سداسية عشرية (RRGGBB) أو فارغة.',
      'rootLabelLabel': 'نص العقدة الجذرية',
      'rootLabelHint': 'اتركه فارغًا لعرض الأيقونة الافتراضية',
      'nodeLabelLabel': 'النص',
      'nodeLabelHint': 'اتركه فارغًا لعرض الاسم الافتراضي',
    },
  };
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppStrings._values.containsKey(locale.languageCode);

  @override
  Future<AppStrings> load(Locale locale) async => AppStrings(locale);

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}
