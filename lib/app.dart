import 'package:flutter/material.dart';

import 'l10n/generated/app_localizations.dart';
import 'l10n/locale_controller.dart';
import 'screens/main_screen.dart';

class OmniLoaderApp extends StatelessWidget {
  final LocaleController localeController;

  const OmniLoaderApp({super.key, required this.localeController});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: localeController,
      builder: (context, _) {
        final baseTheme = ThemeData.dark();
        return MaterialApp(
          title: 'OmniLoader',
          debugShowCheckedModeBanner: false,
          locale: localeController.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: baseTheme.copyWith(
            scaffoldBackgroundColor: const Color(0xFF0F172A),
            textTheme: baseTheme.textTheme.apply(fontFamily: 'ArefRuqaa'),
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF38BDF8),
              surface: Color(0xFF1E293B),
            ),
          ),
          home: MainScreen(localeController: localeController),
        );
      },
    );
  }
}
