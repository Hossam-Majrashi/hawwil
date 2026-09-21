import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../services/settings_service.dart';
import '../../services/batch_conversion_service.dart';

class WebHomeScreen extends StatelessWidget {
  final SettingsService settingsService;
  final BatchConversionService batchService;
  final VoidCallback onCreateProject;
  final VoidCallback onOpenCoverEditor;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenProgress;

  const WebHomeScreen({
    super.key,
    required this.settingsService,
    required this.batchService,
    required this.onCreateProject,
    required this.onOpenCoverEditor,
    required this.onOpenSettings,
    required this.onOpenProgress,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Column(
        children: [
          // Top Web Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF282B30) : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF3F444D) : const Color(0xFFE5E7EB),
                ),
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.swap_horiz_rounded,
                      size: 32,
                      color: Color(0xFF38BDF8),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  l10n.tr('appName'),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (batchService.items.isNotEmpty) ...[
                  ActionChip(
                    avatar: const Icon(Icons.queue_music_rounded, size: 16),
                    label: Text(
                      '${l10n.tr('screenProgress')} (${batchService.items.length})',
                    ),
                    onPressed: onOpenProgress,
                  ),
                  const SizedBox(width: 12),
                ],
                IconButton(
                  tooltip: l10n.tr('screenSettings'),
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: onOpenSettings,
                ),
              ],
            ),
          ),

          // Main Web Container
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 36),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Notice about web
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 28),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, color: Colors.blue),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                l10n.tr('webNoticeDesc'),
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),

                      Text(
                        l10n.tr('aboutTitle'),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.tr('appTagline'),
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 32),

                      // Action Cards
                      Row(
                        children: [
                          Expanded(
                            child: _buildWebCard(
                              title: l10n.tr('homeCreateProjectTitle'),
                              subtitle: l10n.tr('homeCreateProjectSub'),
                              buttonLabel: l10n.tr('screenCreateProject'),
                              icon: Icons.add_circle_outline_rounded,
                              iconColor: const Color(0xFF38BDF8),
                              onTap: onCreateProject,
                              theme: theme,
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _buildWebCard(
                              title: l10n.tr('homeCoverEditorTitle'),
                              subtitle: l10n.tr('homeCoverEditorSub'),
                              buttonLabel: l10n.tr('screenCoverEditor'),
                              icon: Icons.photo_filter_rounded,
                              iconColor: const Color(0xFF10B981),
                              onTap: onOpenCoverEditor,
                              theme: theme,
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebCard({
    required String title,
    required String subtitle,
    required String buttonLabel,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
    required ThemeData theme,
    required bool isDark,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 32),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: Text(buttonLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
