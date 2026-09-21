import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

class MobileSplashAboutScreen extends StatelessWidget {
  final VoidCallback onContinue;

  const MobileSplashAboutScreen({
    super.key,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      // App Icon
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Image.asset(
                            'assets/icon/app_icon.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: isDark ? const Color(0xFF282B30) : Colors.white,
                              child: const Icon(
                                Icons.swap_horiz_rounded,
                                size: 48,
                                color: Color(0xFF38BDF8),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        l10n.tr('appName'),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.tr('appTagline'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Feature List Tiles
                      _buildFeatureTile(
                        icon: Icons.video_collection_rounded,
                        iconColor: const Color(0xFF38BDF8),
                        title: 'MP3 ➔ MP4',
                        desc: l10n.tr('aboutFeature1'),
                        theme: theme,
                      ),
                      const SizedBox(height: 12),
                      _buildFeatureTile(
                        icon: Icons.audiotrack_rounded,
                        iconColor: const Color(0xFF10B981),
                        title: 'MP4 ➔ MP3',
                        desc: l10n.tr('aboutFeature2'),
                        theme: theme,
                      ),
                      const SizedBox(height: 12),
                      _buildFeatureTile(
                        icon: Icons.photo_filter_rounded,
                        iconColor: const Color(0xFFF59E0B),
                        title: l10n.tr('screenCoverEditor'),
                        desc: l10n.tr('aboutFeature3'),
                        theme: theme,
                      ),
                      const SizedBox(height: 12),
                      _buildFeatureTile(
                        icon: Icons.queue_music_rounded,
                        iconColor: const Color(0xFFA855F7),
                        title: l10n.tr('screenProgress'),
                        desc: l10n.tr('aboutFeature4'),
                        theme: theme,
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onContinue,
                  icon: const Icon(Icons.arrow_forward_rounded),
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

  Widget _buildFeatureTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String desc,
    required ThemeData theme,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: theme.textTheme.bodySmall?.copyWith(
                      height: 1.4,
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
