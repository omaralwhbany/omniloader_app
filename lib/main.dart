import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'app.dart';
import 'l10n/locale_controller.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Show the first Flutter frame immediately. Optional startup services must
  // never keep Android's native splash screen visible indefinitely.
  final localeController = LocaleController();
  runApp(OmniLoaderApp(localeController: localeController));

  unawaited(
    localeController.load().timeout(const Duration(seconds: 5)).catchError(
      (Object error, StackTrace stackTrace) {
        debugPrint('Locale initialization failed: $error');
      },
    ),
  );

  unawaited(
    initializeNotifications().timeout(const Duration(seconds: 5)).catchError(
      (Object error, StackTrace stackTrace) {
        debugPrint('Notification initialization failed: $error');
      },
    ),
  );
}
