import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../services/settings_service.dart';
import '../../services/batch_conversion_service.dart';

class MobileHomeScreen extends StatelessWidget {
  final SettingsService settingsService;
  final BatchConversionService batchService;
  final VoidCallback onCreateProject;
  final VoidCallback onOpenCoverEditor;
  final VoidCallback onOpenMergeMedia;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenProgress;

  const MobileHomeScreen({
    super.key,
    required this.settingsService,
    required this.batchService,
    required this.onCreateProject,
    required this.onOpenCoverEditor,
    required this.onOpenMergeMedia,
    required this.onOpenSettings,
    required this.onOpenProgress,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/icon/app_icon.png',
                width: 28,
                height: 28,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.swap_horiz_rounded,
                  size: 26,
                  color: Color(0xFF38BDF8),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(l10n.tr('appName')),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l10n.tr('screenSettings'),
            icon: const Icon(Icons.settings_outlined),
            onPressed: onOpenSettings,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome Banner
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.tr('aboutTitle'),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.tr('appTagline'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Active Queue Banner if items exist
              if (batchService.items.isNotEmpty) ...[
                Card(
                  color: const Color(0xFF38BDF8).withOpacity(0.1),
                  child: ListTile(
                    leading: const Icon(Icons.queue_music_rounded, color: Color(0xFF38BDF8)),
                    title: Text(
                      '${l10n.tr('screenProgress')} (${batchService.items.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      l10n.tr(
                        'itemsCompleted',
                        {
                          'done': batchService.completedCount.toString(),
                          'total': batchService.totalCount.toString()
                        },
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                    onTap: onOpenProgress,
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Create Project Action Card
              _buildMobileActionCard(
                title: l10n.tr('homeCreateProjectTitle'),
                subtitle: l10n.tr('homeCreateProjectSub'),
                buttonText: l10n.tr('screenCreateProject'),
                icon: Icons.add_circle_outline_rounded,
                iconColor: const Color(0xFF38BDF8),
                onTap: onCreateProject,
                theme: theme,
                isPrimary: true,
              ),
              const SizedBox(height: 16),

              // Cover Art Editor Card
              _buildMobileActionCard(
                title: l10n.tr('homeCoverEditorTitle'),
                subtitle: l10n.tr('homeCoverEditorSub'),
                buttonText: l10n.tr('screenCoverEditor'),
                icon: Icons.photo_filter_rounded,
                iconColor: const Color(0xFF10B981),
                onTap: onOpenCoverEditor,
                theme: theme,
                isPrimary: false,
              ),
              const SizedBox(height: 16),

              // Merge Media Card
              _buildMobileActionCard(
                title: l10n.tr('homeMergeMediaTitle'),
                subtitle: l10n.tr('homeMergeMediaSub'),
                buttonText: l10n.tr('screenMergeMedia'),
                icon: Icons.movie_creation_rounded,
                iconColor: const Color(0xFFF59E0B),
                onTap: onOpenMergeMedia,
                theme: theme,
                isPrimary: false,
              ),
              const SizedBox(height: 16),

              // Settings Card
              _buildMobileActionCard(
                title: l10n.tr('homeSettingsTitle'),
                subtitle: l10n.tr('homeSettingsSub'),
                buttonText: l10n.tr('screenSettings'),
                icon: Icons.tune_rounded,
                iconColor: const Color(0xFFA855F7),
                onTap: onOpenSettings,
                theme: theme,
                isPrimary: false,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileActionCard({
    required String title,
    required String subtitle,
    required String buttonText,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
    required ThemeData theme,
    required bool isPrimary,
  }) {
    return Card(
      elevation: isPrimary ? 3 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor, size: 28),
                  ),
                  const SizedBox(width: 14),
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
                        const SizedBox(height: 2),
                        SizedBox(
                          height: 34,
                          child: Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: Text(buttonText),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
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
