import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';

class ConnectionHeader extends StatefulWidget {
  const ConnectionHeader({
    super.key,
    required this.status,
    required this.host,
    required this.discoveredCount,
    required this.isBusy,
    required this.isPlaybackBusy,
    required this.isUploadBusy,
    required this.lastError,
    required this.isDarkMode,
    required this.onReconnect,
    required this.onAddAudio,
    required this.onPause,
    required this.onStop,
    required this.onToggleTheme,
  });

  final String status;
  final String? host;
  final int discoveredCount;
  final bool isBusy;
  final bool isPlaybackBusy;
  final bool isUploadBusy;
  final String? lastError;
  final bool isDarkMode;
  final VoidCallback onReconnect;
  final VoidCallback onAddAudio;
  final VoidCallback onPause;
  final VoidCallback onStop;
  final VoidCallback onToggleTheme;

  @override
  State<ConnectionHeader> createState() => _ConnectionHeaderState();
}

class _ConnectionHeaderState extends State<ConnectionHeader> {
  bool _isCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    final Color badgeColor;
    if (widget.host != null) {
      badgeColor = const Color(0xFF16A34A);
    } else if (widget.isBusy) {
      badgeColor = const Color(0xFFF59E0B);
    } else {
      badgeColor = const Color(0xFFDC2626);
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Soundpad Deck',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: badgeColor),
                    const SizedBox(width: 8),
                    Text(
                      widget.host != null
                          ? l10n.statusOnline
                          : widget.isBusy
                          ? l10n.statusSearching
                          : l10n.statusOffline,
                      style: TextStyle(
                        color: badgeColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: _isCollapsed ? l10n.tooltipExpand : l10n.tooltipCollapse,
                onPressed: () {
                  setState(() {
                    _isCollapsed = !_isCollapsed;
                  });
                },
                icon: Icon(
                  _isCollapsed
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_up,
                ),
              ),
            ],
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: _isCollapsed
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  widget.status,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.instancesFound(widget.discoveredCount),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (widget.lastError != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.lastError!,
                      style: TextStyle(color: colorScheme.onErrorContainer),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: widget.isBusy ? null : widget.onReconnect,
                        icon: const Icon(Icons.refresh),
                        label: Text(l10n.reconnect),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: (widget.host == null || widget.isUploadBusy)
                            ? null
                            : widget.onAddAudio,
                        icon: widget.isUploadBusy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.library_music),
                        label: Text(l10n.addAudio),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed:
                            (widget.host == null || widget.isPlaybackBusy)
                            ? null
                            : widget.onPause,
                        icon: const Icon(Icons.pause),
                        label: Text(l10n.pause),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed:
                            (widget.host == null || widget.isPlaybackBusy)
                            ? null
                            : widget.onStop,
                        icon: const Icon(Icons.stop),
                        label: Text(l10n.stop),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: widget.onToggleTheme,
                        icon: Icon(
                          widget.isDarkMode
                              ? Icons.light_mode
                              : Icons.dark_mode,
                        ),
                        label: Text(
                          widget.isDarkMode ? l10n.lightTheme : l10n.darkTheme,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
