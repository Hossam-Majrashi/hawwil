import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../services/settings_service.dart';

class DesktopThemeSelectionScreen extends StatelessWidget {
  final SettingsService settingsService;
  final VoidCallback onContinue;

  const DesktopThemeSelectionScreen({
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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(36.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.palette_rounded,
                      size: 56,
                      color: Color(0xFF38BDF8),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l10n.tr('selectTheme'),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'يمكنك تغيير المظهر لاحقاً من الإعدادات في أي وقت',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 36),
                    Row(
                      children: [
                        // Dark Theme Preview Card (#212327, #232627)
                        Expanded(
                          child: _buildThemePreviewCard(
                            title: l10n.tr('themeDark'),
                            subtitle: 'Background #212327 • Buttons #232627',
                            bgColor: const Color(0xFF212327),
                            btnColor: const Color(0xFF232627),
                            textColor: const Color(0xFFF3F4F6),
                            selected: currentMode == ThemeMode.dark,
                            onSelect: () => settingsService.setThemeMode(ThemeMode.dark),
                            icon: Icons.dark_mode_rounded,
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Light Theme Preview Card (#efeef1, #fefefe)
                        Expanded(
                          child: _buildThemePreviewCard(
                            title: l10n.tr('themeLight'),
                            subtitle: 'Background #efeef1 • Buttons #fefefe',
                            bgColor: const Color(0xFFEFEEF1),
                            btnColor: const Color(0xFFFEFEFE),
                            textColor: const Color(0xFF111827),
                            selected: currentMode == ThemeMode.light,
                            onSelect: () => settingsService.setThemeMode(ThemeMode.light),
                            icon: Icons.light_mode_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 36),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 220),
                      child: ElevatedButton.icon(
                        onPressed: onContinue,
                        icon: const Icon(Icons.check_rounded),
                        label: Text(l10n.tr('getStarted')),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 18),
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

  Widget _buildThemePreviewCard({
    required String title,
    required String subtitle,
    required Color bgColor,
    required Color btnColor,
    required Color textColor,
    required bool selected,
    required VoidCallback onSelect,
    required IconData icon,
  }) {
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFF38BDF8) : Colors.grey.withOpacity(0.3),
            width: selected ? 2.5 : 1,
          ),
          boxShadow: [
            if (selected)
              BoxShadow(
                color: const Color(0xFF38BDF8).withOpacity(0.2),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: textColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: selected ? const Color(0xFF38BDF8) : textColor.withOpacity(0.4),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Mock UI preview elements inside card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: btnColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  Icon(Icons.play_circle_fill_rounded, size: 20, color: textColor),
                  const SizedBox(width: 10),
                  Text(
                    'Preview Button',
                    style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              subtitle,
              style: TextStyle(
                color: textColor.withOpacity(0.65),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
