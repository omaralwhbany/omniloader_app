import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleController extends ChangeNotifier {
  static const _localeKey = 'app_locale';
  Locale _locale = const Locale('ar');

  Locale get locale => _locale;

  Future<void> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final languageCode = preferences.getString(_localeKey);
      if (languageCode == 'en' || languageCode == 'ar') {
        _locale = Locale(languageCode!);
        notifyListeners();
      }
    } catch (error) {
      debugPrint('Could not load saved locale; using Arabic: $error');
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (locale.languageCode != 'ar' && locale.languageCode != 'en') return;
    if (_locale.languageCode == locale.languageCode) return;
    _locale = Locale(locale.languageCode);
    notifyListeners();

    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_localeKey, _locale.languageCode);
    } catch (error) {
      debugPrint('Could not save selected locale: $error');
    }
  }
}
