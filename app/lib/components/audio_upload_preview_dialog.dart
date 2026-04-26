import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../services/audio_selection_service.dart';

class AudioUploadPreviewDialog extends StatefulWidget {
  const AudioUploadPreviewDialog({super.key, required this.file});

  final PickedAudioFile file;

  @override
  State<AudioUploadPreviewDialog> createState() =>
      _AudioUploadPreviewDialogState();
}

class _AudioUploadPreviewDialogState extends State<AudioUploadPreviewDialog> {
  final AudioPlayer _player = AudioPlayer();

  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<PlayerState>? _stateSubscription;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPreparing = false;
  bool _isPlaying = false;
  bool _hasStarted = false;

  @override
  void initState() {
    super.initState();

    _positionSubscription = _player.onPositionChanged.listen((value) {
      if (!mounted) {
        return;
      }
      setState(() {
        _position = value;
      });
    });

    _durationSubscription = _player.onDurationChanged.listen((value) {
      if (!mounted) {
        return;
      }
      setState(() {
        _duration = value;
      });
    });

    _stateSubscription = _player.onPlayerStateChanged.listen((state) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isPlaying = state == PlayerState.playing;
      });
    });
  }

  @override
  void dispose() {
    unawaited(_player.dispose());
    unawaited(_positionSubscription?.cancel());
    unawaited(_durationSubscription?.cancel());
    unawaited(_stateSubscription?.cancel());
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    if (_isPreparing) {
      return;
    }

    if (_isPlaying) {
      await _player.pause();
      return;
    }

    if (_duration > Duration.zero && _position >= _duration) {
      await _player.seek(Duration.zero);
    }

    if (!_hasStarted) {
      setState(() {
        _isPreparing = true;
      });

      try {
        await _player.play(BytesSource(widget.file.bytes));
        _hasStarted = true;
      } finally {
        if (mounted) {
          setState(() {
            _isPreparing = false;
          });
        }
      }

      return;
    }

    await _player.resume();
  }

  Future<void> _seekTo(double millis) async {
    final value = millis.round();
    await _player.seek(Duration(milliseconds: value));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final maxMillis = _duration.inMilliseconds > 0
        ? _duration.inMilliseconds.toDouble()
        : 1.0;
    final currentMillis = _position.inMilliseconds.toDouble().clamp(
      0.0,
      maxMillis,
    );

    return AlertDialog(
      title: Text(l10n.audioPreviewTitle),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.file.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 14),
            Slider(
              value: currentMillis,
              max: maxMillis,
              onChanged: _duration > Duration.zero ? _seekTo : null,
            ),
            Row(
              children: [
                Text(_formatDuration(_position)),
                const Spacer(),
                Text(_formatDuration(_duration)),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _togglePlayback,
              icon: _isPreparing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
              label: Text(_isPlaying ? l10n.pausePreview : l10n.playPreview),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.add),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
