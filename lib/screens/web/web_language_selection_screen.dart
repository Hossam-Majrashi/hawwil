import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../services/settings_service.dart';

class WebLanguageSelectionScreen extends StatelessWidget {
  final SettingsService settingsService;
  final VoidCallback onContinue;

  const WebLanguageSelectionScreen({
    super.key,
    required this.settingsService,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final currentCode = settingsService.locale.languageCode;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.language_rounded,
                      size: 56,
                      color: Color(0xFF38BDF8),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l10n.tr('selectLanguage'),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 32),
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: currentCode == 'ar'
                              ? const Color(0xFF38BDF8)
                              : theme.colorScheme.outline,
                          width: currentCode == 'ar' ? 2 : 1,
                        ),
                      ),
                      leading: Icon(
                        currentCode == 'ar'
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: currentCode == 'ar' ? const Color(0xFF38BDF8) : Colors.grey,
                      ),
                      title: const Text('العربية (افتراضي)', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Arabic'),
                      onTap: () => settingsService.setLocale(const Locale('ar')),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: currentCode == 'en'
                              ? const Color(0xFF38BDF8)
                              : theme.colorScheme.outline,
                          width: currentCode == 'en' ? 2 : 1,
                        ),
                      ),
                      leading: Icon(
                        currentCode == 'en'
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: currentCode == 'en' ? const Color(0xFF38BDF8) : Colors.grey,
                      ),
                      title: const Text('English', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('English'),
                      onTap: () => settingsService.setLocale(const Locale('en')),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: onContinue,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: Text(l10n.tr('next')),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
