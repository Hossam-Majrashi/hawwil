import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../l10n/app_localizations.dart';
import '../../models/conversion_settings.dart';
import '../../services/settings_service.dart';
import '../../widgets/developer_section.dart';

class MobileSettingsScreen extends StatefulWidget {
  final SettingsService settingsService;
  final VoidCallback onBack;

  const MobileSettingsScreen({
    super.key,
    required this.settingsService,
    required this.onBack,
  });

  @override
  State<MobileSettingsScreen> createState() => _MobileSettingsScreenState();
}

class _MobileSettingsScreenState extends State<MobileSettingsScreen> {
  late String _resolution;
  late String _videoBitrate;
  late String _audioBitrate;
  String? _outputFolder;

  @override
  void initState() {
    super.initState();
    final cs = widget.settingsService.conversionSettings;
    _resolution = cs.defaultResolution;
    _videoBitrate = cs.defaultVideoBitrate;
    _audioBitrate = cs.defaultAudioBitrate;
    _outputFolder = cs.outputFolder;
  }

  void _saveSettings() {
    widget.settingsService.updateConversionSettings(
      defaultResolution: _resolution,
      defaultVideoBitrate: _videoBitrate,
      defaultAudioBitrate: _audioBitrate,
      outputFolder: _outputFolder,
    );
  }

  Future<void> _pickFolder() async {
    final selectedDir = await FilePicker.getDirectoryPath();
    if (selectedDir != null) {
      setState(() => _outputFolder = selectedDir);
      _saveSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Language & Appearance Section
            Text(
              l10n.tr('languageAndAppearance'),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Language
                    Row(
                      children: [
                        const Icon(Icons.language_rounded, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.tr('selectLanguage'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DropdownButton<String>(
                          value: currentLang,
                          underline: const SizedBox(),
                          items: const [
                            DropdownMenuItem(value: 'ar', child: Text('العربية')),
                            DropdownMenuItem(value: 'en', child: Text('English')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              widget.settingsService.setLocale(Locale(val));
                            }
                          },
                        ),
                      ],
                    ),
                    const Divider(height: 24),

                    // Theme
                    Row(
                      children: [
                        const Icon(Icons.palette_outlined, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.tr('selectTheme'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DropdownButton<ThemeMode>(
                          value: currentTheme,
                          underline: const SizedBox(),
                          items: [
                            DropdownMenuItem(
                              value: ThemeMode.dark,
                              child: Text(l10n.tr('themeDark')),
                            ),
                            DropdownMenuItem(
                              value: ThemeMode.light,
                              child: Text(l10n.tr('themeLight')),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              widget.settingsService.setThemeMode(val);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Conversion Defaults Section
            Text(
              l10n.tr('outputSettings'),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.tr('defaultResolution'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
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
                    const SizedBox(height: 16),

                    Text(l10n.tr('defaultVideoBitrate'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
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
                    const SizedBox(height: 16),

                    Text(l10n.tr('defaultAudioBitrate'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
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
                    const SizedBox(height: 16),

                    Text(l10n.tr('defaultOutputFolder'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.folder_open_rounded),
                      title: Text(
                        _outputFolder ?? l10n.tr('notSet'),
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: TextButton(
                        onPressed: _pickFolder,
                        child: Text(l10n.tr('changeFolder')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const DeveloperSection(),
          ],
        ),
      ),
    );
  }
}
