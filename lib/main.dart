import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'theme/app_theme.dart';
import 'services/settings_service.dart';
import 'services/batch_conversion_service.dart';
import 'services/merge_media_controller.dart';
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

class HawwilApp extends StatefulWidget {
  final SettingsService settingsService;
  final BatchConversionService batchService;

  const HawwilApp({
    super.key,
    required this.settingsService,
    required this.batchService,
  });

  @override
  State<HawwilApp> createState() => _HawwilAppState();
}

class _HawwilAppState extends State<HawwilApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    MergeMediaController.hookExitSignals();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    MergeMediaController.stopAllPlayback();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      MergeMediaController.stopAllPlayback();
    }
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    MergeMediaController.stopAllPlayback();
    return AppExitResponse.exit;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settingsService,
      builder: (context, _) {
        return MaterialApp(
          title: 'Hawwil (حوّل)',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: widget.settingsService.themeMode,
          locale: widget.settingsService.locale,
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
            settingsService: widget.settingsService,
            batchService: widget.batchService,
          ),
        );
      },
    );
  }
}
