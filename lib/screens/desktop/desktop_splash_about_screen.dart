import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

class DesktopSplashAboutScreen extends StatelessWidget {
  final VoidCallback onContinue;

  const DesktopSplashAboutScreen({
    super.key,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;

              return ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Brand Header
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Image.asset(
                          'assets/icon/app_icon.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: isDark ? const Color(0xFF282B30) : Colors.white,
                            child: const Icon(
                              Icons.swap_horiz_rounded,
                              size: 64,
                              color: Color(0xFF38BDF8),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.tr('appName'),
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.tr('appTagline'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Text(
                        l10n.tr('appDescription'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.6,
                          color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Feature Grid
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildFeatureCard(
                              icon: Icons.video_collection_rounded,
                              iconColor: const Color(0xFF38BDF8),
                              title: 'MP3 ➔ MP4',
                              description: l10n.tr('aboutFeature1'),
                              theme: theme,
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildFeatureCard(
                              icon: Icons.audiotrack_rounded,
                              iconColor: const Color(0xFF10B981),
                              title: 'MP4 ➔ MP3',
                              description: l10n.tr('aboutFeature2'),
                              theme: theme,
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildFeatureCard(
                              icon: Icons.photo_filter_rounded,
                              iconColor: const Color(0xFFF59E0B),
                              title: l10n.tr('screenCoverEditor'),
                              description: l10n.tr('aboutFeature3'),
                              theme: theme,
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildFeatureCard(
                              icon: Icons.queue_music_rounded,
                              iconColor: const Color(0xFFA855F7),
                              title: l10n.tr('screenProgress'),
                              description: l10n.tr('aboutFeature4'),
                              theme: theme,
                              isDark: isDark,
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          _buildFeatureCard(
                            icon: Icons.video_collection_rounded,
                            iconColor: const Color(0xFF38BDF8),
                            title: 'MP3 ➔ MP4',
                            description: l10n.tr('aboutFeature1'),
                            theme: theme,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 12),
                          _buildFeatureCard(
                            icon: Icons.audiotrack_rounded,
                            iconColor: const Color(0xFF10B981),
                            title: 'MP4 ➔ MP3',
                            description: l10n.tr('aboutFeature2'),
                            theme: theme,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 12),
                          _buildFeatureCard(
                            icon: Icons.photo_filter_rounded,
                            iconColor: const Color(0xFFF59E0B),
                            title: l10n.tr('screenCoverEditor'),
                            description: l10n.tr('aboutFeature3'),
                            theme: theme,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 12),
                          _buildFeatureCard(
                            icon: Icons.queue_music_rounded,
                            iconColor: const Color(0xFFA855F7),
                            title: l10n.tr('screenProgress'),
                            description: l10n.tr('aboutFeature4'),
                            theme: theme,
                            isDark: isDark,
                          ),
                        ],
                      ),
                    const SizedBox(height: 40),

                    // Action Button
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 260),
                      child: ElevatedButton.icon(
                        onPressed: onContinue,
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: Text(
                          l10n.tr('getStarted'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required ThemeData theme,
    required bool isDark,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: theme.textTheme.bodySmall?.copyWith(
                height: 1.5,
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
