import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../services/settings_service.dart';

class MobileLanguageSelectionScreen extends StatelessWidget {
  final SettingsService settingsService;
  final VoidCallback onContinue;

  const MobileLanguageSelectionScreen({
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.language_rounded,
                      size: 64,
                      color: Color(0xFF38BDF8),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l10n.tr('selectLanguage'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildLanguageItem(
                      title: 'العربية (افتراضي)',
                      subtitle: 'Arabic',
                      selected: currentCode == 'ar',
                      onTap: () => settingsService.setLocale(const Locale('ar')),
                      theme: theme,
                    ),
                    const SizedBox(height: 14),
                    _buildLanguageItem(
                      title: 'English',
                      subtitle: 'English',
                      selected: currentCode == 'en',
                      onTap: () => settingsService.setLocale(const Locale('en')),
                      theme: theme,
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onContinue,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(l10n.tr('next')),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageItem({
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return Card(
      elevation: selected ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? const Color(0xFF38BDF8) : theme.colorScheme.outline,
          width: selected ? 2 : 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_off,
          color: selected ? const Color(0xFF38BDF8) : Colors.grey,
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ),
    );
  }
}
