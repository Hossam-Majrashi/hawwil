import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/app_localizations.dart';
import '../../services/ffmpeg_service.dart';

class DesktopFfmpegSetupScreen extends StatefulWidget {
  final VoidCallback onFfmpegFound;

  const DesktopFfmpegSetupScreen({
    super.key,
    required this.onFfmpegFound,
  });

  @override
  State<DesktopFfmpegSetupScreen> createState() => _DesktopFfmpegSetupScreenState();
}

class _DesktopFfmpegSetupScreenState extends State<DesktopFfmpegSetupScreen> {
  bool _isChecking = false;
  String? _statusMessage;

  Future<void> _checkAgain() async {
    setState(() {
      _isChecking = true;
      _statusMessage = null;
    });

    FFmpegService.resetFFmpegCache();
    final available = await FFmpegService.checkDesktopFFmpeg();

    setState(() {
      _isChecking = false;
    });

    if (available) {
      widget.onFfmpegFound();
    } else {
      setState(() {
        _statusMessage = 'FFmpeg still not found on PATH. Please verify installation.';
      });
    }
  }

  void _copyCommand(String cmd) {
    Clipboard.setData(ClipboardData(text: cmd));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied: $cmd'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(36.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.amber,
                            size: 36,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.tr('ffmpegSetupTitle'),
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                l10n.tr('ffmpegSetupMessage'),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Commands by Distribution / OS:',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildCommandTile(
                      label: l10n.tr('ffmpegInstallUbuntu'),
                      command: 'sudo apt update && sudo apt install -y ffmpeg',
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),
                    _buildCommandTile(
                      label: l10n.tr('ffmpegInstallFedora'),
                      command: 'sudo dnf install -y ffmpeg',
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),
                    _buildCommandTile(
                      label: l10n.tr('ffmpegInstallArch'),
                      command: 'sudo pacman -S --needed ffmpeg',
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),
                    _buildCommandTile(
                      label: l10n.tr('ffmpegInstallMac'),
                      command: 'brew install ffmpeg',
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),
                    _buildCommandTile(
                      label: l10n.tr('ffmpegInstallWindows'),
                      command: 'winget install Gyan.FFmpeg',
                      isDark: isDark,
                    ),
                    const SizedBox(height: 30),
                    if (_statusMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Text(
                          _statusMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ElevatedButton.icon(
                      onPressed: _isChecking ? null : _checkAgain,
                      icon: _isChecking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded),
                      label: Text(l10n.tr('recheckFfmpeg')),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
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

  Widget _buildCommandTile({
    required String label,
    required String command,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2024) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF373B43) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  command,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy Command',
            icon: const Icon(Icons.copy_rounded, size: 18),
            onPressed: () => _copyCommand(command),
          ),
        ],
      ),
    );
  }
}
