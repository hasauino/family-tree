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

  String deleteConfirm(String name) =>
      _t('deleteConfirm').replaceFirst('{name}', name);

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
      'personDeleted': 'Person deleted.',
      'publish': 'Publish',
      'unpublish': 'Unpublish',
      'published': 'Published.',
      'unpublished': 'Unpublished.',
      'bookmark': 'Bookmark',
      'removeBookmark': 'Remove bookmark',
      'bookmarked': 'Bookmarked.',
      'bookmarkRemoved': 'Bookmark removed.',
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
      'errorNoPath': 'لم يُعثر على مسار. تأكد أن الشخص الأول هو جد الشخص الثاني.',
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
      'personDeleted': 'تم حذف الشخص.',
      'publish': 'نشر',
      'unpublish': 'إلغاء النشر',
      'published': 'تم النشر.',
      'unpublished': 'تم إلغاء النشر.',
      'bookmark': 'إضافة إشارة مرجعية',
      'removeBookmark': 'إزالة الإشارة المرجعية',
      'bookmarked': 'تمت إضافة الإشارة المرجعية.',
      'bookmarkRemoved': 'تمت إزالة الإشارة المرجعية.',
    },
  };
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) => AppStrings._values.containsKey(
        locale.languageCode,
      );

  @override
  Future<AppStrings> load(Locale locale) async => AppStrings(locale);

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}
