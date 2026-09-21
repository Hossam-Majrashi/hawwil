import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../services/settings_service.dart';
import '../../services/batch_conversion_service.dart';

class DesktopHomeScreen extends StatelessWidget {
  final SettingsService settingsService;
  final BatchConversionService batchService;
  final VoidCallback onCreateProject;
  final VoidCallback onOpenCoverEditor;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenProgress;
  final bool isFFmpegAvailable;

  const DesktopHomeScreen({
    super.key,
    required this.settingsService,
    required this.batchService,
    required this.onCreateProject,
    required this.onOpenCoverEditor,
    required this.onOpenSettings,
    required this.onOpenProgress,
    this.isFFmpegAvailable = true,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Column(
        children: [
          // Top Desktop Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
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

                // System Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isFFmpegAvailable
                        ? const Color(0xFF10B981).withOpacity(0.12)
                        : Colors.amber.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isFFmpegAvailable ? const Color(0xFF10B981) : Colors.amber,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isFFmpegAvailable
                            ? Icons.check_circle_rounded
                            : Icons.warning_rounded,
                        size: 14,
                        color: isFFmpegAvailable ? const Color(0xFF10B981) : Colors.amber,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isFFmpegAvailable
                            ? l10n.tr('ffmpegReady')
                            : l10n.tr('ffmpegMissing'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isFFmpegAvailable ? const Color(0xFF10B981) : Colors.amber,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // Active Queue shortcut if files are queued
                if (batchService.items.isNotEmpty)
                  ActionChip(
                    avatar: const Icon(Icons.queue_music_rounded, size: 16),
                    label: Text(
                      '${l10n.tr('screenProgress')} (${batchService.items.length})',
                    ),
                    onPressed: onOpenProgress,
                  ),

                IconButton(
                  tooltip: l10n.tr('screenSettings'),
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: onOpenSettings,
                ),
              ],
            ),
          ),

          // Main Dashboard Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 36),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.tr('aboutTitle'),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.tr('appTagline'),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 36),

                      // Two Main Action Cards (Create Project, Cover Art Editor) + Settings
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 800;

                          if (isWide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: _buildMainActionCard(
                                    title: l10n.tr('homeCreateProjectTitle'),
                                    subtitle: l10n.tr('homeCreateProjectSub'),
                                    buttonLabel: l10n.tr('screenCreateProject'),
                                    icon: Icons.add_circle_outline_rounded,
                                    iconColor: const Color(0xFF38BDF8),
                                    onTap: onCreateProject,
                                    isDark: isDark,
                                    theme: theme,
                                    isPrimary: true,
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  flex: 4,
                                  child: _buildMainActionCard(
                                    title: l10n.tr('homeCoverEditorTitle'),
                                    subtitle: l10n.tr('homeCoverEditorSub'),
                                    buttonLabel: l10n.tr('screenCoverEditor'),
                                    icon: Icons.photo_filter_rounded,
                                    iconColor: const Color(0xFF10B981),
                                    onTap: onOpenCoverEditor,
                                    isDark: isDark,
                                    theme: theme,
                                    isPrimary: false,
                                  ),
                                ),
                              ],
                            );
                          } else {
                            return Column(
                              children: [
                                _buildMainActionCard(
                                  title: l10n.tr('homeCreateProjectTitle'),
                                  subtitle: l10n.tr('homeCreateProjectSub'),
                                  buttonLabel: l10n.tr('screenCreateProject'),
                                  icon: Icons.add_circle_outline_rounded,
                                  iconColor: const Color(0xFF38BDF8),
                                  onTap: onCreateProject,
                                  isDark: isDark,
                                  theme: theme,
                                  isPrimary: true,
                                ),
                                const SizedBox(height: 20),
                                _buildMainActionCard(
                                  title: l10n.tr('homeCoverEditorTitle'),
                                  subtitle: l10n.tr('homeCoverEditorSub'),
                                  buttonLabel: l10n.tr('screenCoverEditor'),
                                  icon: Icons.photo_filter_rounded,
                                  iconColor: const Color(0xFF10B981),
                                  onTap: onOpenCoverEditor,
                                  isDark: isDark,
                                  theme: theme,
                                  isPrimary: false,
                                ),
                              ],
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 28),

                      // Quick settings banner
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.tune_rounded,
                                  color: Colors.purpleAccent,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.tr('homeSettingsTitle'),
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      l10n.tr('homeSettingsSub'),
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: onOpenSettings,
                                icon: const Icon(Icons.settings_outlined, size: 18),
                                label: Text(l10n.tr('screenSettings')),
                              ),
                            ],
                          ),
                        ),
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

  Widget _buildMainActionCard({
    required String title,
    required String subtitle,
    required String buttonLabel,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
    required bool isDark,
    required ThemeData theme,
    required bool isPrimary,
  }) {
    return Card(
      elevation: isPrimary ? 3 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 36),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: Text(buttonLabel),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
