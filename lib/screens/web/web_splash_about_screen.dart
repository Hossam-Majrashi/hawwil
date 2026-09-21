import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

class WebSplashAboutScreen extends StatelessWidget {
  final VoidCallback onContinue;

  const WebSplashAboutScreen({
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
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              children: [
                // Web Platform Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  margin: const EdgeInsets.only(bottom: 32),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Colors.blueAccent),
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

                // Logo & Header
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 100,
                      height: 100,
                      color: isDark ? const Color(0xFF282B30) : Colors.white,
                      child: const Icon(
                        Icons.swap_horiz_rounded,
                        size: 56,
                        color: Color(0xFF38BDF8),
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
                const SizedBox(height: 8),
                Text(
                  l10n.tr('appTagline'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 36),

                // Feature Highlights Cards
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildWebFeatureCard(
                      icon: Icons.video_collection_rounded,
                      color: const Color(0xFF38BDF8),
                      title: 'MP3 ➔ MP4',
                      desc: l10n.tr('aboutFeature1'),
                      theme: theme,
                    ),
                    _buildWebFeatureCard(
                      icon: Icons.audiotrack_rounded,
                      color: const Color(0xFF10B981),
                      title: 'MP4 ➔ MP3',
                      desc: l10n.tr('aboutFeature2'),
                      theme: theme,
                    ),
                    _buildWebFeatureCard(
                      icon: Icons.photo_filter_rounded,
                      color: const Color(0xFFF59E0B),
                      title: l10n.tr('screenCoverEditor'),
                      desc: l10n.tr('aboutFeature3'),
                      theme: theme,
                    ),
                    _buildWebFeatureCard(
                      icon: Icons.queue_music_rounded,
                      color: const Color(0xFFA855F7),
                      title: l10n.tr('screenProgress'),
                      desc: l10n.tr('aboutFeature4'),
                      theme: theme,
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 220),
                  child: ElevatedButton.icon(
                    onPressed: onContinue,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: Text(
                      l10n.tr('getStarted'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
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
    );
  }

  Widget _buildWebFeatureCard({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
    required ThemeData theme,
  }) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                desc,
                style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
