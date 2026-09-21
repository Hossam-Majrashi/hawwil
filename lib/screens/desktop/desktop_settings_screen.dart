import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../l10n/app_localizations.dart';
import '../../models/conversion_settings.dart';
import '../../services/settings_service.dart';

class DesktopSettingsScreen extends StatefulWidget {
  final SettingsService settingsService;
  final VoidCallback onBack;

  const DesktopSettingsScreen({
    super.key,
    required this.settingsService,
    required this.onBack,
  });

  @override
  State<DesktopSettingsScreen> createState() => _DesktopSettingsScreenState();
}

class _DesktopSettingsScreenState extends State<DesktopSettingsScreen> {
  late String _resolution;
  late String _videoBitrate;
  late String _audioBitrate;
  String? _outputFolder;
  late String _filenamePattern;

  @override
  void initState() {
    super.initState();
    final cs = widget.settingsService.conversionSettings;
    _resolution = cs.defaultResolution;
    _videoBitrate = cs.defaultVideoBitrate;
    _audioBitrate = cs.defaultAudioBitrate;
    _outputFolder = cs.outputFolder;
    _filenamePattern = cs.filenamePattern;
  }

  Future<void> _pickFolder() async {
    final selectedDir = await FilePicker.getDirectoryPath();
    if (selectedDir != null) {
      setState(() => _outputFolder = selectedDir);
      _saveSettings();
    }
  }

  void _saveSettings() {
    widget.settingsService.updateConversionSettings(
      defaultResolution: _resolution,
      defaultVideoBitrate: _videoBitrate,
      defaultAudioBitrate: _audioBitrate,
      outputFolder: _outputFolder,
      filenamePattern: _filenamePattern,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentLang = widget.settingsService.locale.languageCode;
    final currentTheme = widget.settingsService.themeMode;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tr('settingsTitle')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: widget.onBack,
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
            children: [
              // Language & Appearance Section
              Text(
                l10n.tr('languageAndAppearance'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF38BDF8),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      // Language
                      Row(
                        children: [
                          const Icon(Icons.language_rounded, size: 24),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.tr('selectLanguage'),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  currentLang == 'ar' ? 'العربية' : 'English',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'ar', label: Text('العربية')),
                              ButtonSegment(value: 'en', label: Text('English')),
                            ],
                            selected: {currentLang},
                            onSelectionChanged: (val) {
                              widget.settingsService.setLocale(Locale(val.first));
                            },
                          ),
                        ],
                      ),
                      const Divider(height: 32),

                      // Theme
                      Row(
                        children: [
                          const Icon(Icons.palette_outlined, size: 24),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.tr('selectTheme'),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  currentTheme == ThemeMode.dark
                                      ? l10n.tr('themeDark')
                                      : (currentTheme == ThemeMode.light
                                          ? l10n.tr('themeLight')
                                          : l10n.tr('themeSystem')),
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          SegmentedButton<ThemeMode>(
                            segments: [
                              ButtonSegment(
                                value: ThemeMode.dark,
                                icon: const Icon(Icons.dark_mode_rounded, size: 16),
                                label: Text(l10n.tr('themeDark')),
                              ),
                              ButtonSegment(
                                value: ThemeMode.light,
                                icon: const Icon(Icons.light_mode_rounded, size: 16),
                                label: Text(l10n.tr('themeLight')),
                              ),
                            ],
                            selected: {currentTheme},
                            onSelectionChanged: (val) {
                              widget.settingsService.setThemeMode(val.first);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Conversion Defaults Section
              Text(
                l10n.tr('outputSettings'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF38BDF8),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Resolution
                      Text(
                        l10n.tr('defaultResolution'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _resolution,
                        items: ConversionSettings.availableResolutions.map((r) {
                          return DropdownMenuItem(value: r, child: Text(r));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _resolution = val);
                            _saveSettings();
                          }
                        },
                      ),
                      const SizedBox(height: 20),

                      // Video Bitrate
                      Text(
                        l10n.tr('defaultVideoBitrate'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _videoBitrate,
                        items: ConversionSettings.availableVideoBitrates.map((b) {
                          return DropdownMenuItem(value: b, child: Text(b));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _videoBitrate = val);
                            _saveSettings();
                          }
                        },
                      ),
                      const SizedBox(height: 20),

                      // Audio Bitrate
                      Text(
                        l10n.tr('defaultAudioBitrate'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _audioBitrate,
                        items: ConversionSettings.availableAudioBitrates.map((a) {
                          return DropdownMenuItem(value: a, child: Text(a));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _audioBitrate = val);
                            _saveSettings();
                          }
                        },
                      ),
                      const SizedBox(height: 20),

                      // Output Folder
                      Text(
                        l10n.tr('defaultOutputFolder'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _pickFolder,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? const Color(0xFF3F444D) : const Color(0xFFD1D5DB),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.folder_open_rounded),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _outputFolder ?? l10n.tr('notSet'),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              TextButton(
                                onPressed: _pickFolder,
                                child: Text(l10n.tr('changeFolder')),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
