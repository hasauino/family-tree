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

  // Search
  String get searchTooltip => _t('searchTooltip');
  String get searchHint => _t('searchHint');
  String get searchError => _t('searchError');
  String get searchNoResults => _t('searchNoResults');

  // Account / auth
  String get login => _t('login');
  String get logout => _t('logout');
  String get account => _t('account');
  String get loginTitle => _t('loginTitle');
  String get loginInvalid => _t('loginInvalid');
  String get usernameLabel => _t('usernameLabel');
  String get passwordLabel => _t('passwordLabel');
  String get fieldRequired => _t('fieldRequired');
  String get signIn => _t('signIn');

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

  static const Map<String, Map<String, String>> _values = {
    'en': {
      'appTitle': 'Family Tree',
      'cancel': 'Cancel',
      'fitTreeTooltip': 'Fit tree to window',
      'reloadTooltip': 'Reload',
      'noData': 'No data.',
      'noDetails': 'No further details.',
      'centerTreeHere': 'Center tree here',
      'retry': 'Retry',
      'errorConnection':
          'Could not load the family tree. Check your connection and try again.',
      'errorPersonNotFound': 'Person #{id} was not found.',
      'treePathTooltip': 'Show path from ancestor to descendant',
      'treePathTitle': 'Show path',
      'treePathFromLabel': 'From (ancestor)',
      'treePathToLabel': 'To (descendant)',
      'treePathFromHint': 'Search for the ancestor',
      'treePathToHint': 'Search for the descendant',
      'treePathPickHint': 'Tap to choose a person',
      'treePathGo': 'Go',
      'errorNoPath':
          'No path found. Make sure the first person is an ancestor of the second.',
      'searchTooltip': 'Search by name',
      'searchHint': 'Search by name',
      'searchError': 'Search failed. Check your connection and try again.',
      'searchNoResults': 'No matching people found.',
      'login': 'Login',
      'logout': 'Logout',
      'account': 'Account',
      'loginTitle': 'Sign in',
      'loginInvalid': 'Invalid username or password.',
      'usernameLabel': 'Username',
      'passwordLabel': 'Password',
      'fieldRequired': 'This field is required.',
      'signIn': 'Sign In',
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
      'reloadTooltip': 'إعادة التحميل',
      'noData': 'لا توجد بيانات.',
      'noDetails': 'لا توجد تفاصيل إضافية.',
      'centerTreeHere': 'اجعل الشجرة هنا',
      'retry': 'إعادة المحاولة',
      'errorConnection':
          'تعذّر تحميل شجرة العائلة. تحقّق من اتصالك وحاول مرة أخرى.',
      'errorPersonNotFound': 'لم يتم العثور على الشخص رقم {id}.',
      'treePathTooltip': 'عرض المسار من الجد إلى الحفيد',
      'treePathTitle': 'عرض المسار',
      'treePathFromLabel': 'من (الجد)',
      'treePathToLabel': 'إلى (الحفيد)',
      'treePathFromHint': 'ابحث عن الجد',
      'treePathToHint': 'ابحث عن الحفيد',
      'treePathPickHint': 'اضغط لاختيار شخص',
      'treePathGo': 'انتقال',
      'errorNoPath':
          'لم يُعثر على مسار. تأكد أن الشخص الأول هو جد الشخص الثاني.',
      'searchTooltip': 'البحث بالاسم',
      'searchHint': 'البحث بالاسم',
      'searchError': 'فشل البحث. تحقّق من اتصالك وحاول مرة أخرى.',
      'searchNoResults': 'لا يوجد أشخاص مطابقون.',
      'login': 'تسجيل الدخول',
      'logout': 'تسجيل الخروج',
      'account': 'الحساب',
      'loginTitle': 'تسجيل الدخول',
      'loginInvalid': 'اسم المستخدم أو كلمة المرور غير صحيحة.',
      'usernameLabel': 'اسم المستخدم',
      'passwordLabel': 'كلمة المرور',
      'fieldRequired': 'هذا الحقل مطلوب.',
      'signIn': 'دخول',
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
