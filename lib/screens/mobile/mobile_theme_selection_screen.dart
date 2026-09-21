import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../services/settings_service.dart';

class MobileThemeSelectionScreen extends StatelessWidget {
  final SettingsService settingsService;
  final VoidCallback onContinue;

  const MobileThemeSelectionScreen({
    super.key,
    required this.settingsService,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final currentMode = settingsService.themeMode;

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
                      Icons.palette_rounded,
                      size: 64,
                      color: Color(0xFF38BDF8),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l10n.tr('selectTheme'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Dark Theme Card
                    _buildMobileThemeOption(
                      title: l10n.tr('themeDark'),
                      subtitle: 'Background #212327 • Icons/Buttons #232627',
                      bgColor: const Color(0xFF212327),
                      btnColor: const Color(0xFF232627),
                      textColor: const Color(0xFFF3F4F6),
                      selected: currentMode == ThemeMode.dark,
                      onTap: () => settingsService.setThemeMode(ThemeMode.dark),
                      icon: Icons.dark_mode_rounded,
                    ),
                    const SizedBox(height: 16),

                    // Light Theme Card
                    _buildMobileThemeOption(
                      title: l10n.tr('themeLight'),
                      subtitle: 'Background #efeef1 • Icons/Buttons #fefefe',
                      bgColor: const Color(0xFFEFEEF1),
                      btnColor: const Color(0xFFFEFEFE),
                      textColor: const Color(0xFF111827),
                      selected: currentMode == ThemeMode.light,
                      onTap: () => settingsService.setThemeMode(ThemeMode.light),
                      icon: Icons.light_mode_rounded,
                    ),
                  ],
                ),
              ),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onContinue,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(
                    l10n.tr('getStarted'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
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

  Widget _buildMobileThemeOption({
    required String title,
    required String subtitle,
    required Color bgColor,
    required Color btnColor,
    required Color textColor,
    required bool selected,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFF38BDF8) : Colors.grey.withOpacity(0.3),
            width: selected ? 2.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: btnColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
              ),
              child: Icon(icon, color: textColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: textColor.withOpacity(0.6),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: selected ? const Color(0xFF38BDF8) : textColor.withOpacity(0.4),
            ),
          ],
        ),
      ),
    );
  }
}
