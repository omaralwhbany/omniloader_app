import 'package:flutter/widgets.dart';

import 'app.dart';
import 'l10n/locale_controller.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeNotifications();

  final localeController = LocaleController();
  await localeController.load();

  runApp(OmniLoaderApp(localeController: localeController));
}
