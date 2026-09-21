import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/conversion_settings.dart';
import '../../services/settings_service.dart';

class WebSettingsScreen extends StatefulWidget {
  final SettingsService settingsService;
  final VoidCallback onBack;

  const WebSettingsScreen({
    super.key,
    required this.settingsService,
    required this.onBack,
  });

  @override
  State<WebSettingsScreen> createState() => _WebSettingsScreenState();
}

class _WebSettingsScreenState extends State<WebSettingsScreen> {
  late String _resolution;
  late String _videoBitrate;
  late String _audioBitrate;

  @override
  void initState() {
    super.initState();
    final cs = widget.settingsService.conversionSettings;
    _resolution = cs.defaultResolution;
    _videoBitrate = cs.defaultVideoBitrate;
    _audioBitrate = cs.defaultAudioBitrate;
  }

  void _saveSettings() {
    widget.settingsService.updateConversionSettings(
      defaultResolution: _resolution,
      defaultVideoBitrate: _videoBitrate,
      defaultAudioBitrate: _audioBitrate,
    );
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.all(32),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      // Language
                      ListTile(
                        leading: const Icon(Icons.language_rounded),
                        title: Text(l10n.tr('selectLanguage')),
                        trailing: DropdownButton<String>(
                          value: currentLang,
                          items: const [
                            DropdownMenuItem(value: 'ar', child: Text('العربية')),
                            DropdownMenuItem(value: 'en', child: Text('English')),
                          ],
                          onChanged: (val) {
                            if (val != null) widget.settingsService.setLocale(Locale(val));
                          },
                        ),
                      ),
                      const Divider(),
                      // Theme
                      ListTile(
                        leading: const Icon(Icons.palette_outlined),
                        title: Text(l10n.tr('selectTheme')),
                        trailing: DropdownButton<ThemeMode>(
                          value: currentTheme,
                          items: [
                            DropdownMenuItem(value: ThemeMode.dark, child: Text(l10n.tr('themeDark'))),
                            DropdownMenuItem(value: ThemeMode.light, child: Text(l10n.tr('themeLight'))),
                          ],
                          onChanged: (val) {
                            if (val != null) widget.settingsService.setThemeMode(val);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.tr('defaultResolution')),
                      const SizedBox(height: 6),
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
                      Text(l10n.tr('defaultVideoBitrate')),
                      const SizedBox(height: 6),
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
