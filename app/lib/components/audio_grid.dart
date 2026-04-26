import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/soundpad_audio.dart';
import 'audio_tile.dart';

class AudioGrid extends StatelessWidget {
  const AudioGrid({
    super.key,
    required this.audios,
    required this.isLoading,
    required this.playingIndex,
    required this.onPlay,
    required this.onEdit,
  });

  final List<SoundpadAudio> audios;
  final bool isLoading;
  final int? playingIndex;
  final ValueChanged<SoundpadAudio> onPlay;
  final void Function(SoundpadAudio audio, AudioEditAction action) onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (audios.isEmpty) {
      return Center(child: Text(l10n.noAudioAvailable));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _crossAxisCount(constraints.maxWidth),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: audios.length,
          itemBuilder: (context, index) {
            final audio = audios[index];
            return AudioTile(
              audio: audio,
              isPlaying: playingIndex == audio.index,
              onPlay: () => onPlay(audio),
              onEditAction: (action) => onEdit(audio, action),
            );
          },
        );
      },
    );
  }

  int _crossAxisCount(double width) {
    if (width >= 1300) {
      return 6;
    }
    if (width >= 1000) {
      return 5;
    }
    if (width >= 780) {
      return 4;
    }
    if (width >= 560) {
      return 3;
    }
    return 2;
  }
}
