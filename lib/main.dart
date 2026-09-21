import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'theme/app_theme.dart';
import 'services/settings_service.dart';
import 'services/batch_conversion_service.dart';
import 'screens/screen_dispatcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settingsService = SettingsService();
  await settingsService.init();

  final batchService = BatchConversionService();

  runApp(HawwilApp(
    settingsService: settingsService,
    batchService: batchService,
  ));
}

class HawwilApp extends StatelessWidget {
  final SettingsService settingsService;
  final BatchConversionService batchService;

  const HawwilApp({
    super.key,
    required this.settingsService,
    required this.batchService,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settingsService,
      builder: (context, _) {
        return MaterialApp(
          title: 'Hawwil (حوّل)',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: settingsService.themeMode,
          locale: settingsService.locale,
          supportedLocales: const [
            Locale('ar'), // Arabic default
            Locale('en'), // English
          ],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: ScreenDispatcher(
            settingsService: settingsService,
            batchService: batchService,
          ),
        );
      },
    );
  }
}
