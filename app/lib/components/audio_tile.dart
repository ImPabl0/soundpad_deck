import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/soundpad_audio.dart';

enum AudioEditAction { changeImage, removeImage, deleteAudio }

class AudioTile extends StatelessWidget {
  const AudioTile({
    super.key,
    required this.audio,
    required this.isPlaying,
    required this.onPlay,
    required this.onEditAction,
  });

  final SoundpadAudio audio;
  final bool isPlaying;
  final VoidCallback onPlay;
  final ValueChanged<AudioEditAction> onEditAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Material(
      color: isDark ? const Color(0xFF0B1220) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onPlay,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isPlaying
                  ? colorScheme.primary
                  : isDark
                  ? const Color(0xFF334155)
                  : const Color(0xFFE2E8F0),
              width: isPlaying ? 1.6 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _Artwork(imageBase64: audio.imageBase64)),
                const SizedBox(height: 10),
                Text(
                  audio.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('#${audio.index}'),
                    ),
                    const Spacer(),
                    PopupMenuButton<AudioEditAction>(
                      tooltip: l10n.editImage,
                      onSelected: onEditAction,
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: AudioEditAction.changeImage,
                          child: Text(l10n.addOrChangeImage),
                        ),
                        if (audio.imageBase64 != null)
                          PopupMenuItem(
                            value: AudioEditAction.removeImage,
                            child: Text(l10n.removeImage),
                          ),
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: AudioEditAction.deleteAudio,
                          child: Text(
                            l10n.deleteAudio,
                            style: TextStyle(color: colorScheme.error),
                          ),
                        ),
                      ],
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.edit_square, size: 20),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({required this.imageBase64});

  final String? imageBase64;

  @override
  Widget build(BuildContext context) {
    final bytes = _safeDecodeImage(imageBase64);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.memory(
          bytes,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _DefaultArtwork(isDark: isDark),
        ),
      );
    }

    return _DefaultArtwork(isDark: isDark);
  }

  Uint8List? _safeDecodeImage(String? source) {
    if (source == null || source.isEmpty) {
      return null;
    }

    try {
      return base64Decode(source);
    } catch (_) {
      return null;
    }
  }
}

class _DefaultArtwork extends StatelessWidget {
  const _DefaultArtwork({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF1E293B), Color(0xFF334155)]
              : const [Color(0xFFE2E8F0), Color(0xFFCBD5E1)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.music_note_rounded,
              size: 48,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
            ),
            const SizedBox(height: 4),
            Text(
              '♪',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? const Color(0xFFCBD5E1)
                    : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
