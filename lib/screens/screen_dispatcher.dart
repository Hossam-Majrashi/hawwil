import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../services/batch_conversion_service.dart';
import '../services/ffmpeg_service.dart';

// Desktop screens
import 'desktop/desktop_ffmpeg_setup_screen.dart';
import 'desktop/desktop_splash_about_screen.dart';
import 'desktop/desktop_language_selection_screen.dart';
import 'desktop/desktop_theme_selection_screen.dart';
import 'desktop/desktop_home_screen.dart';
import 'desktop/desktop_create_project_screen.dart';
import 'desktop/desktop_progress_screen.dart';
import 'desktop/desktop_cover_editor_screen.dart';
import 'desktop/desktop_merge_media_screen.dart';
import 'desktop/desktop_settings_screen.dart';

// Mobile screens
import 'mobile/mobile_splash_about_screen.dart';
import 'mobile/mobile_language_selection_screen.dart';
import 'mobile/mobile_theme_selection_screen.dart';
import 'mobile/mobile_home_screen.dart';
import 'mobile/mobile_create_project_screen.dart';
import 'mobile/mobile_progress_screen.dart';
import 'mobile/mobile_cover_editor_screen.dart';
import 'mobile/mobile_merge_media_screen.dart';
import 'mobile/mobile_settings_screen.dart';

// Web screens
import 'web/web_splash_about_screen.dart';
import 'web/web_language_selection_screen.dart';
import 'web/web_theme_selection_screen.dart';
import 'web/web_home_screen.dart';
import 'web/web_create_project_screen.dart';
import 'web/web_progress_screen.dart';
import 'web/web_cover_editor_screen.dart';
import 'web/web_merge_media_screen.dart';
import 'web/web_settings_screen.dart';

enum AppScreenRoute {
  ffmpegSetup,
  splashAbout,
  languageSelection,
  themeSelection,
  home,
  createProject,
  progress,
  coverEditor,
  mergeMedia,
  settings,
}

class ScreenDispatcher extends StatefulWidget {
  final SettingsService settingsService;
  final BatchConversionService batchService;

  const ScreenDispatcher({
    super.key,
    required this.settingsService,
    required this.batchService,
  });

  @override
  State<ScreenDispatcher> createState() => _ScreenDispatcherState();
}

class _ScreenDispatcherState extends State<ScreenDispatcher> {
  AppScreenRoute _currentRoute = AppScreenRoute.splashAbout;
  bool _isFFmpegAvailable = true;
  bool _checkingFFmpeg = true;

  @override
  void initState() {
    super.initState();
    _checkInitialState();
  }

  Future<void> _checkInitialState() async {
    if (!kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows)) {
      final available = await FFmpegService.checkDesktopFFmpeg();
      _isFFmpegAvailable = available;
      if (!available) {
        setState(() {
          _currentRoute = AppScreenRoute.ffmpegSetup;
          _checkingFFmpeg = false;
        });
        return;
      }
    }

    setState(() {
      _checkingFFmpeg = false;
      if (widget.settingsService.firstRunCompleted) {
        _currentRoute = AppScreenRoute.home;
      } else {
        _currentRoute = AppScreenRoute.splashAbout;
      }
    });
  }

  void _navigateTo(AppScreenRoute route) {
    setState(() {
      _currentRoute = route;
    });
  }

  void _startNewProject() {
    if (widget.batchService.isProcessing) {
      _navigateTo(AppScreenRoute.progress);
      return;
    }

    if (widget.batchService.hasCompletedItems || widget.batchService.allFinished) {
      widget.batchService.resetForNewProject();
    }

    _navigateTo(AppScreenRoute.createProject);
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingFFmpeg) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobileWidth = constraints.maxWidth < 650;
        final isDesktopPlatform = !kIsWeb &&
            (Platform.isLinux || Platform.isMacOS || Platform.isWindows);
        final isMobilePlatform = !kIsWeb &&
            (Platform.isAndroid || Platform.isIOS);

        // Decide form-factor
        if (kIsWeb) {
          return _buildWebScreen();
        } else if (isMobilePlatform || isMobileWidth) {
          return _buildMobileScreen();
        } else if (isDesktopPlatform) {
          return _buildDesktopScreen();
        } else {
          return _buildDesktopScreen();
        }
      },
    );
  }

  Widget _buildDesktopScreen() {
    switch (_currentRoute) {
      case AppScreenRoute.ffmpegSetup:
        return DesktopFfmpegSetupScreen(
          onFfmpegFound: () {
            setState(() {
              _isFFmpegAvailable = true;
              _currentRoute = widget.settingsService.firstRunCompleted
                  ? AppScreenRoute.home
                  : AppScreenRoute.splashAbout;
            });
          },
        );

      case AppScreenRoute.splashAbout:
        return DesktopSplashAboutScreen(
          onContinue: () {
            if (widget.settingsService.firstRunCompleted) {
              _navigateTo(AppScreenRoute.home);
            } else {
              _navigateTo(AppScreenRoute.languageSelection);
            }
          },
        );

      case AppScreenRoute.languageSelection:
        return DesktopLanguageSelectionScreen(
          settingsService: widget.settingsService,
          onContinue: () => _navigateTo(AppScreenRoute.themeSelection),
        );

      case AppScreenRoute.themeSelection:
        return DesktopThemeSelectionScreen(
          settingsService: widget.settingsService,
          onContinue: () async {
            await widget.settingsService.completeFirstRun();
            _navigateTo(AppScreenRoute.home);
          },
        );

      case AppScreenRoute.home:
        return DesktopHomeScreen(
          settingsService: widget.settingsService,
          batchService: widget.batchService,
          isFFmpegAvailable: _isFFmpegAvailable,
          onCreateProject: _startNewProject,
          onOpenCoverEditor: () => _navigateTo(AppScreenRoute.coverEditor),
          onOpenMergeMedia: () => _navigateTo(AppScreenRoute.mergeMedia),
          onOpenSettings: () => _navigateTo(AppScreenRoute.settings),
          onOpenProgress: () => _navigateTo(AppScreenRoute.progress),
        );

      case AppScreenRoute.createProject:
        return DesktopCreateProjectScreen(
          batchService: widget.batchService,
          settingsService: widget.settingsService,
          onStartConversion: () => _navigateTo(AppScreenRoute.progress),
          onBack: () => _navigateTo(AppScreenRoute.home),
        );

      case AppScreenRoute.progress:
        return DesktopProgressScreen(
          batchService: widget.batchService,
          settingsService: widget.settingsService,
          onBackToHome: () => _navigateTo(AppScreenRoute.home),
          onNewProject: _startNewProject,
        );

      case AppScreenRoute.coverEditor:
        return DesktopCoverEditorScreen(
          onBack: () => _navigateTo(AppScreenRoute.home),
        );

      case AppScreenRoute.mergeMedia:
        return DesktopMergeMediaScreen(
          onBack: () => _navigateTo(AppScreenRoute.home),
          settingsService: widget.settingsService,
        );

      case AppScreenRoute.settings:
        return DesktopSettingsScreen(
          settingsService: widget.settingsService,
          onBack: () => _navigateTo(AppScreenRoute.home),
        );
    }
  }

  Widget _buildMobileScreen() {
    switch (_currentRoute) {
      case AppScreenRoute.ffmpegSetup:
      case AppScreenRoute.splashAbout:
        return MobileSplashAboutScreen(
          onContinue: () {
            if (widget.settingsService.firstRunCompleted) {
              _navigateTo(AppScreenRoute.home);
            } else {
              _navigateTo(AppScreenRoute.languageSelection);
            }
          },
        );

      case AppScreenRoute.languageSelection:
        return MobileLanguageSelectionScreen(
          settingsService: widget.settingsService,
          onContinue: () => _navigateTo(AppScreenRoute.themeSelection),
        );

      case AppScreenRoute.themeSelection:
        return MobileThemeSelectionScreen(
          settingsService: widget.settingsService,
          onContinue: () async {
            await widget.settingsService.completeFirstRun();
            _navigateTo(AppScreenRoute.home);
          },
        );

      case AppScreenRoute.home:
        return MobileHomeScreen(
          settingsService: widget.settingsService,
          batchService: widget.batchService,
          onCreateProject: _startNewProject,
          onOpenCoverEditor: () => _navigateTo(AppScreenRoute.coverEditor),
          onOpenMergeMedia: () => _navigateTo(AppScreenRoute.mergeMedia),
          onOpenSettings: () => _navigateTo(AppScreenRoute.settings),
          onOpenProgress: () => _navigateTo(AppScreenRoute.progress),
        );

      case AppScreenRoute.createProject:
        return MobileCreateProjectScreen(
          batchService: widget.batchService,
          settingsService: widget.settingsService,
          onStartConversion: () => _navigateTo(AppScreenRoute.progress),
          onBack: () => _navigateTo(AppScreenRoute.home),
        );

      case AppScreenRoute.progress:
        return MobileProgressScreen(
          batchService: widget.batchService,
          settingsService: widget.settingsService,
          onBackToHome: () => _navigateTo(AppScreenRoute.home),
          onNewProject: _startNewProject,
        );

      case AppScreenRoute.coverEditor:
        return MobileCoverEditorScreen(
          onBack: () => _navigateTo(AppScreenRoute.home),
        );

      case AppScreenRoute.mergeMedia:
        return MobileMergeMediaScreen(
          onBack: () => _navigateTo(AppScreenRoute.home),
          settingsService: widget.settingsService,
        );

      case AppScreenRoute.settings:
        return MobileSettingsScreen(
          settingsService: widget.settingsService,
          onBack: () => _navigateTo(AppScreenRoute.home),
        );
    }
  }

  Widget _buildWebScreen() {
    switch (_currentRoute) {
      case AppScreenRoute.ffmpegSetup:
      case AppScreenRoute.splashAbout:
        return WebSplashAboutScreen(
          onContinue: () {
            if (widget.settingsService.firstRunCompleted) {
              _navigateTo(AppScreenRoute.home);
            } else {
              _navigateTo(AppScreenRoute.languageSelection);
            }
          },
        );

      case AppScreenRoute.languageSelection:
        return WebLanguageSelectionScreen(
          settingsService: widget.settingsService,
          onContinue: () => _navigateTo(AppScreenRoute.themeSelection),
        );

      case AppScreenRoute.themeSelection:
        return WebThemeSelectionScreen(
          settingsService: widget.settingsService,
          onContinue: () async {
            await widget.settingsService.completeFirstRun();
            _navigateTo(AppScreenRoute.home);
          },
        );

      case AppScreenRoute.home:
        return WebHomeScreen(
          settingsService: widget.settingsService,
          batchService: widget.batchService,
          onCreateProject: _startNewProject,
          onOpenCoverEditor: () => _navigateTo(AppScreenRoute.coverEditor),
          onOpenMergeMedia: () => _navigateTo(AppScreenRoute.mergeMedia),
          onOpenSettings: () => _navigateTo(AppScreenRoute.settings),
          onOpenProgress: () => _navigateTo(AppScreenRoute.progress),
        );

      case AppScreenRoute.createProject:
        return WebCreateProjectScreen(
          batchService: widget.batchService,
          settingsService: widget.settingsService,
          onStartConversion: () => _navigateTo(AppScreenRoute.progress),
          onBack: () => _navigateTo(AppScreenRoute.home),
        );

      case AppScreenRoute.progress:
        return WebProgressScreen(
          batchService: widget.batchService,
          settingsService: widget.settingsService,
          onBackToHome: () => _navigateTo(AppScreenRoute.home),
          onNewProject: _startNewProject,
        );

      case AppScreenRoute.coverEditor:
        return WebCoverEditorScreen(
          onBack: () => _navigateTo(AppScreenRoute.home),
        );

      case AppScreenRoute.mergeMedia:
        return WebMergeMediaScreen(
          onBack: () => _navigateTo(AppScreenRoute.home),
          settingsService: widget.settingsService,
        );

      case AppScreenRoute.settings:
        return WebSettingsScreen(
          settingsService: widget.settingsService,
          onBack: () => _navigateTo(AppScreenRoute.home),
        );
    }
  }
}
