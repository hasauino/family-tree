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
  String get openPersonTooltip => _t('openPersonTooltip');
  String get openPersonTitle => _t('openPersonTitle');
  String get personIdLabel => _t('personIdLabel');
  String get personIdHint => _t('personIdHint');
  String get cancel => _t('cancel');
  String get open => _t('open');
  String get centerOnActiveTooltip => _t('centerOnActiveTooltip');
  String get reloadTooltip => _t('reloadTooltip');
  String get noData => _t('noData');
  String get noDetails => _t('noDetails');
  String get centerTreeHere => _t('centerTreeHere');
  String get retry => _t('retry');
  String get errorConnection => _t('errorConnection');

  String errorPersonNotFound(int id) =>
      _t('errorPersonNotFound').replaceFirst('{id}', '$id');

  static const Map<String, Map<String, String>> _values = {
    'en': {
      'appTitle': 'Family Tree',
      'openPersonTooltip': 'Open person',
      'openPersonTitle': 'Open person tree',
      'personIdLabel': 'Person id',
      'personIdHint': 'e.g. 1',
      'cancel': 'Cancel',
      'open': 'Open',
      'centerOnActiveTooltip': 'Center on active person',
      'reloadTooltip': 'Reload',
      'noData': 'No data.',
      'noDetails': 'No further details.',
      'centerTreeHere': 'Center tree here',
      'retry': 'Retry',
      'errorConnection':
          'Could not load the family tree. Check your connection and try again.',
      'errorPersonNotFound': 'Person #{id} was not found.',
    },
    'ar': {
      'appTitle': 'شجرة العائلة',
      'openPersonTooltip': 'فتح شخص',
      'openPersonTitle': 'فتح شجرة شخص',
      'personIdLabel': 'معرّف الشخص',
      'personIdHint': 'مثال: 1',
      'cancel': 'إلغاء',
      'open': 'فتح',
      'centerOnActiveTooltip': 'التمركز على الشخص الحالي',
      'reloadTooltip': 'إعادة التحميل',
      'noData': 'لا توجد بيانات.',
      'noDetails': 'لا توجد تفاصيل إضافية.',
      'centerTreeHere': 'اجعل الشجرة هنا',
      'retry': 'إعادة المحاولة',
      'errorConnection':
          'تعذّر تحميل شجرة العائلة. تحقّق من اتصالك وحاول مرة أخرى.',
      'errorPersonNotFound': 'لم يتم العثور على الشخص رقم {id}.',
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
