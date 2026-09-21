import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../services/settings_service.dart';

class DesktopLanguageSelectionScreen extends StatelessWidget {
  final SettingsService settingsService;
  final VoidCallback onContinue;

  const DesktopLanguageSelectionScreen({
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
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(36.0),
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
                    const SizedBox(height: 8),
                    Text(
                      'اختر لغة الواجهة المفضلة لك / Select interface language',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 36),
                    _buildLanguageOption(
                      title: 'العربية (افتراضي)',
                      subtitle: 'Arabic - الواجهة العربية بالكامل من اليمين لليسار',
                      code: 'ar',
                      selected: currentCode == 'ar',
                      onSelect: () => settingsService.setLocale(const Locale('ar')),
                      theme: theme,
                    ),
                    const SizedBox(height: 16),
                    _buildLanguageOption(
                      title: 'English',
                      subtitle: 'English - Left to Right standard interface',
                      code: 'en',
                      selected: currentCode == 'en',
                      onSelect: () => settingsService.setLocale(const Locale('en')),
                      theme: theme,
                    ),
                    const SizedBox(height: 36),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 200),
                      child: ElevatedButton.icon(
                        onPressed: onContinue,
                        icon: const Icon(Icons.check_rounded),
                        label: Text(l10n.tr('next')),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                        ),
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

  Widget _buildLanguageOption({
    required String title,
    required String subtitle,
    required String code,
    required bool selected,
    required VoidCallback onSelect,
    required ThemeData theme,
  }) {
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xFF38BDF8) : theme.colorScheme.outline,
            width: selected ? 2 : 1,
          ),
          color: selected
              ? const Color(0xFF38BDF8).withOpacity(0.08)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? const Color(0xFF38BDF8) : Colors.grey,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
