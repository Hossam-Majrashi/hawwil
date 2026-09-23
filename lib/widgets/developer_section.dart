import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';

class DeveloperSection extends StatelessWidget {
  const DeveloperSection({super.key});

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not launch $urlString: $e');
    }
  }

  Widget _buildContactItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2024) : const Color(0xFFF3F2F6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF2E3238) : const Color(0xFFE2E0E6),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: primaryColor, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFFA2A5AD) : const Color(0xFF686E77),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFCDCCCA) : const Color(0xFF262523),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.open_in_new_rounded,
              size: 16,
              color: isDark ? const Color(0xFF686E77) : const Color(0xFFA2A5AD),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, right: 4.0, bottom: 8.0),
          child: Text(
            l10n.developer,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark
                  ? const Color(0xFFA2A5AD)
                  : const Color(0xFF686E77),
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'حسام حسن مجرشي',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: isDark ? const Color(0xFFCDCCCA) : const Color(0xFF262523),
                  ),
                ),
                const SizedBox(height: 16),
                _buildContactItem(
                  context,
                  icon: Icons.alternate_email_rounded,
                  label: l10n.email,
                  value: 'Hossam.Majrashi@gmail.com',
                  onTap: () => _launchUrl('mailto:Hossam.Majrashi@gmail.com'),
                ),
                const SizedBox(height: 16),
                _buildContactItem(
                  context,
                  icon: Icons.public_rounded,
                  label: l10n.website,
                  value: 'hossam-majrashi.github.io/Works/',
                  onTap: () => _launchUrl(
                    'https://hossam-majrashi.github.io/Works/',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
