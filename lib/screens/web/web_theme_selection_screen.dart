import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../services/settings_service.dart';

class WebThemeSelectionScreen extends StatelessWidget {
  final SettingsService settingsService;
  final VoidCallback onContinue;

  const WebThemeSelectionScreen({
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
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.palette_rounded,
                      size: 56,
                      color: Color(0xFF38BDF8),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.tr('selectTheme'),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        // Dark
                        Expanded(
                          child: InkWell(
                            onTap: () => settingsService.setThemeMode(ThemeMode.dark),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFF212327),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: currentMode == ThemeMode.dark
                                      ? const Color(0xFF38BDF8)
                                      : Colors.grey.withOpacity(0.3),
                                  width: currentMode == ThemeMode.dark ? 2.5 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  const Icon(Icons.dark_mode_rounded, color: Color(0xFFF3F4F6)),
                                  const SizedBox(height: 12),
                                  Text(
                                    l10n.tr('themeDark'),
                                    style: const TextStyle(
                                      color: Color(0xFFF3F4F6),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    '#212327 / #232627',
                                    style: TextStyle(color: Colors.grey, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        // Light
                        Expanded(
                          child: InkWell(
                            onTap: () => settingsService.setThemeMode(ThemeMode.light),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFEEF1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: currentMode == ThemeMode.light
                                      ? const Color(0xFF38BDF8)
                                      : Colors.grey.withOpacity(0.3),
                                  width: currentMode == ThemeMode.light ? 2.5 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  const Icon(Icons.light_mode_rounded, color: Color(0xFF111827)),
                                  const SizedBox(height: 12),
                                  Text(
                                    l10n.tr('themeLight'),
                                    style: const TextStyle(
                                      color: Color(0xFF111827),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    '#efeef1 / #fefefe',
                                    style: TextStyle(color: Colors.black54, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: onContinue,
                      icon: const Icon(Icons.check_rounded),
                      label: Text(l10n.tr('getStarted')),
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
