import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleController extends ChangeNotifier {
  static const _localeKey = 'app_locale';
  Locale _locale = const Locale('ar');

  Locale get locale => _locale;

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final languageCode = preferences.getString(_localeKey);
    if (languageCode == 'en' || languageCode == 'ar') {
      _locale = Locale(languageCode!);
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (locale.languageCode != 'ar' && locale.languageCode != 'en') return;
    if (_locale.languageCode == locale.languageCode) return;
    _locale = Locale(locale.languageCode);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_localeKey, _locale.languageCode);
    notifyListeners();
  }
}
