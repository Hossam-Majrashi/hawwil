import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/conversion_settings.dart';

class SettingsService extends ChangeNotifier {
  static const String _keyLocale = 'hawwil_locale';
  static const String _keyThemeMode = 'hawwil_theme_mode';
  static const String _keyFirstRun = 'hawwil_first_run_completed';
  static const String _keyResolution = 'hawwil_resolution';
  static const String _keyVideoBitrate = 'hawwil_video_bitrate';
  static const String _keyAudioBitrate = 'hawwil_audio_bitrate';
  static const String _keyHardwareAcceleration = 'hawwil_hwaccel';
  static const String _keyVideoOutputFormat = 'hawwil_video_output_format';
  static const String _keyOutputFolder = 'hawwil_output_folder';
  static const String _keyFilenamePattern = 'hawwil_filename_pattern';

  late SharedPreferences _prefs;
  bool _initialized = false;

  Locale _locale = const Locale('ar'); // Default Arabic
  ThemeMode _themeMode = ThemeMode.dark; // Default Dark
  bool _firstRunCompleted = false;
  ConversionSettings _conversionSettings = ConversionSettings();

  bool get isInitialized => _initialized;
  Locale get locale => _locale;
  ThemeMode get themeMode => _themeMode;
  bool get firstRunCompleted => _firstRunCompleted;
  ConversionSettings get conversionSettings => _conversionSettings;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    final langCode = _prefs.getString(_keyLocale) ?? 'ar';
    _locale = Locale(langCode);

    final themeStr = _prefs.getString(_keyThemeMode) ?? 'dark';
    if (themeStr == 'light') {
      _themeMode = ThemeMode.light;
    } else if (themeStr == 'system') {
      _themeMode = ThemeMode.system;
    } else {
      _themeMode = ThemeMode.dark;
    }

    _firstRunCompleted = _prefs.getBool(_keyFirstRun) ?? false;

    _conversionSettings = ConversionSettings(
      defaultResolution: _prefs.getString(_keyResolution) ?? '1920x1080',
      defaultVideoBitrate: _prefs.getString(_keyVideoBitrate) ?? '5000k',
      defaultAudioBitrate: _prefs.getString(_keyAudioBitrate) ?? '320k',
      hardwareAcceleration: _prefs.getString(_keyHardwareAcceleration) ?? 'auto',
      defaultVideoOutputFormat: _prefs.getString(_keyVideoOutputFormat) ?? 'mp4',
      outputFolder: _prefs.getString(_keyOutputFolder),
      filenamePattern: _prefs.getString(_keyFilenamePattern) ?? '{name}_hawwil',
    );

    _initialized = true;
    notifyListeners();
  }

  Future<void> setLocale(Locale newLocale) async {
    _locale = newLocale;
    await _prefs.setString(_keyLocale, newLocale.languageCode);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode newMode) async {
    _themeMode = newMode;
    String modeStr = 'dark';
    if (newMode == ThemeMode.light) {
      modeStr = 'light';
    } else if (newMode == ThemeMode.system) {
      modeStr = 'system';
    }
    await _prefs.setString(_keyThemeMode, modeStr);
    notifyListeners();
  }

  Future<void> completeFirstRun() async {
    _firstRunCompleted = true;
    await _prefs.setBool(_keyFirstRun, true);
    notifyListeners();
  }

  Future<void> updateConversionSettings({
    String? defaultResolution,
    String? defaultVideoBitrate,
    String? defaultAudioBitrate,
    String? hardwareAcceleration,
    String? defaultVideoOutputFormat,
    String? outputFolder,
    String? filenamePattern,
  }) async {
    _conversionSettings = _conversionSettings.copyWith(
      defaultResolution: defaultResolution,
      defaultVideoBitrate: defaultVideoBitrate,
      defaultAudioBitrate: defaultAudioBitrate,
      hardwareAcceleration: hardwareAcceleration,
      defaultVideoOutputFormat: defaultVideoOutputFormat,
      outputFolder: outputFolder,
      filenamePattern: filenamePattern,
    );

    if (defaultResolution != null) {
      await _prefs.setString(_keyResolution, defaultResolution);
    }
    if (defaultVideoBitrate != null) {
      await _prefs.setString(_keyVideoBitrate, defaultVideoBitrate);
    }
    if (defaultAudioBitrate != null) {
      await _prefs.setString(_keyAudioBitrate, defaultAudioBitrate);
    }
    if (hardwareAcceleration != null) {
      await _prefs.setString(_keyHardwareAcceleration, hardwareAcceleration);
    }
    if (defaultVideoOutputFormat != null) {
      await _prefs.setString(_keyVideoOutputFormat, defaultVideoOutputFormat);
    }
    if (outputFolder != null) {
      await _prefs.setString(_keyOutputFolder, outputFolder);
    }
    if (filenamePattern != null) {
      await _prefs.setString(_keyFilenamePattern, filenamePattern);
    }

    notifyListeners();
  }
}
