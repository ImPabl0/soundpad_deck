import 'dart:async';

import 'package:flutter/material.dart';

import '../components/audio_grid.dart';
import '../components/audio_tile.dart';
import '../components/audio_upload_preview_dialog.dart';
import '../components/connection_header.dart';
import '../controllers/audio_library_controller.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/soundpad_audio.dart';

class AudioLibraryPage extends StatefulWidget {
  const AudioLibraryPage({
    super.key,
    required this.controller,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  final AudioLibraryController controller;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  @override
  State<AudioLibraryPage> createState() => _AudioLibraryPageState();
}

class _AudioLibraryPageState extends State<AudioLibraryPage> {
  static const double _floatingButtonSize = 56;
  static const Size _mediaControlSize = Size(232, 156);

  Offset _floatingButtonOffset = const Offset(16, 280);
  Offset _mediaControlOffset = const Offset(16, 352);
  bool _isMediaControlVisible = false;

  @override
  void initState() {
    super.initState();
    unawaited(widget.controller.initialize());
  }

  Offset _clampOffset(Offset input, Size area, Size child) {
    final maxX = (area.width - child.width).clamp(0.0, double.infinity);
    final maxY = (area.height - child.height).clamp(0.0, double.infinity);

    return Offset(input.dx.clamp(0.0, maxX), input.dy.clamp(0.0, maxY));
  }

  void _toggleMediaControl(Size bounds) {
    setState(() {
      _isMediaControlVisible = !_isMediaControlVisible;
      if (_isMediaControlVisible) {
        _mediaControlOffset = _clampOffset(
          _floatingButtonOffset.translate(0, _floatingButtonSize + 12),
          bounds,
          _mediaControlSize,
        );
      }
    });
  }

  void _onDragFloatingButton(DragUpdateDetails details, Size bounds) {
    setState(() {
      _floatingButtonOffset = _clampOffset(
        _floatingButtonOffset + details.delta,
        bounds,
        const Size(_floatingButtonSize, _floatingButtonSize),
      );
    });
  }

  void _onDragMediaControl(DragUpdateDetails details, Size bounds) {
    setState(() {
      _mediaControlOffset = _clampOffset(
        _mediaControlOffset + details.delta,
        bounds,
        _mediaControlSize,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(toolbarHeight: 12),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bounds = Size(constraints.maxWidth, constraints.maxHeight);
            final floatingButtonOffset = _clampOffset(
              _floatingButtonOffset,
              bounds,
              const Size(_floatingButtonSize, _floatingButtonSize),
            );
            final mediaControlOffset = _clampOffset(
              _mediaControlOffset,
              bounds,
              _mediaControlSize,
            );

            return Stack(
              children: [
                Column(
                  children: [
                    _HeaderSection(
                      controller: widget.controller,
                      isDarkMode: widget.isDarkMode,
                      onToggleTheme: widget.onToggleTheme,
                    ),
                    Expanded(
                      child: _AudioGridSection(controller: widget.controller),
                    ),
                  ],
                ),
                if (_isMediaControlVisible)
                  Positioned(
                    left: mediaControlOffset.dx,
                    top: mediaControlOffset.dy,
                    child: _FloatingMediaControl(
                      controller: widget.controller,
                      onClose: () {
                        setState(() {
                          _isMediaControlVisible = false;
                        });
                      },
                      onDragUpdate: (details) =>
                          _onDragMediaControl(details, bounds),
                    ),
                  ),
                Positioned(
                  left: floatingButtonOffset.dx,
                  top: floatingButtonOffset.dy,
                  child: GestureDetector(
                    onPanUpdate: (details) =>
                        _onDragFloatingButton(details, bounds),
                    child: FloatingActionButton(
                      heroTag: 'media_control_fab',
                      tooltip: _isMediaControlVisible
                            ? l10n.hideMediaControl
                            : l10n.showMediaControl,
                      onPressed: () => _toggleMediaControl(bounds),
                      child: Icon(
                        _isMediaControlVisible
                            ? Icons.close_rounded
                            : Icons.play_circle_fill_rounded,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FloatingMediaControl extends StatelessWidget {
  const _FloatingMediaControl({
    required this.controller,
    required this.onClose,
    required this.onDragUpdate,
  });

  final AudioLibraryController controller;
  final VoidCallback onClose;
  final GestureDragUpdateCallback onDragUpdate;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return GestureDetector(
      onPanUpdate: onDragUpdate,
      child: Material(
        color: colorScheme.surfaceContainer,
        elevation: 12,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: _AudioLibraryPageState._mediaControlSize.width,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                final isBusy = controller.isPlaybackActionInProgress;
                final isConnected = controller.connectedHost != null;
                final canPlay =
                    isConnected && controller.playingIndex != null && !isBusy;
                final canPause = isConnected && !isBusy;
                final playingName = controller.playingAudioName;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.drag_indicator_rounded,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.mediaControlTitle,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.close,
                          onPressed: onClose,
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    Text(
                      playingName == null
                          ? l10n.selectAudioToEnablePlay
                          : l10n.currentTrack(playingName),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: canPlay
                                ? () => unawaited(controller.resumePlayback())
                                : null,
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: Text(l10n.play),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: canPause
                                ? () => unawaited(controller.pausePlayback())
                                : null,
                            icon: const Icon(Icons.pause_rounded),
                            label: Text(l10n.pause),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderSection extends StatefulWidget {
  const _HeaderSection({
    required this.controller,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  final AudioLibraryController controller;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  @override
  State<_HeaderSection> createState() => _HeaderSectionState();
}

class _HeaderSectionState extends State<_HeaderSection> {
  late String _status;
  late String? _host;
  late int _discoveredCount;
  late bool _isBusy;
  late bool _isPlaybackBusy;
  late bool _isUploadBusy;
  late String? _lastError;

  @override
  void initState() {
    super.initState();
    _syncFromController(widget.controller);
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant _HeaderSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      _syncFromController(widget.controller);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) {
      return;
    }

    setState(() {
      _syncFromController(widget.controller);
    });
  }

  void _syncFromController(AudioLibraryController controller) {
    _status = controller.connectionStatus;
    _host = controller.connectedHost;
    _discoveredCount = controller.discoveredHosts.length;
    _isBusy = controller.isDiscovering;
    _isPlaybackBusy = controller.isPlaybackActionInProgress;
    _isUploadBusy = controller.isUploadInProgress;
    _lastError = controller.lastError;
  }

  @override
  Widget build(BuildContext context) {
    return ConnectionHeader(
      status: _status,
      host: _host,
      discoveredCount: _discoveredCount,
      isBusy: _isBusy,
      isPlaybackBusy: _isPlaybackBusy,
      isUploadBusy: _isUploadBusy,
      lastError: _lastError,
      isDarkMode: widget.isDarkMode,
      onReconnect: widget.controller.reconnect,
      onAddAudio: () => unawaited(_pickPreviewAndUploadAudio()),
      onPause: () => unawaited(widget.controller.pausePlayback()),
      onStop: () => unawaited(widget.controller.stopPlayback()),
      onToggleTheme: widget.onToggleTheme,
    );
  }

  Future<void> _pickPreviewAndUploadAudio() async {
    final selected = await widget.controller.pickAudioForUpload();
    if (selected == null || !mounted) {
      return;
    }

    final shouldUpload = await showDialog<bool>(
      context: context,
      builder: (_) => AudioUploadPreviewDialog(file: selected),
    );

    if (shouldUpload == true) {
      await widget.controller.uploadSelectedAudio(selected);
    }
  }
}

class _AudioGridSection extends StatefulWidget {
  const _AudioGridSection({required this.controller});

  final AudioLibraryController controller;

  @override
  State<_AudioGridSection> createState() => _AudioGridSectionState();
}

class _AudioGridSectionState extends State<_AudioGridSection> {
  late List<SoundpadAudio> _audios;
  late bool _isLoading;
  late int? _playingIndex;

  @override
  void initState() {
    super.initState();
    _syncFromController(widget.controller);
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant _AudioGridSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      _syncFromController(widget.controller);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) {
      return;
    }

    final nextAudios = widget.controller.audios;
    final nextIsLoading =
        widget.controller.isBootstrapping || widget.controller.isRefreshing;
    final nextPlayingIndex = widget.controller.playingIndex;

    final listChanged = _hasAudioContentChanged(_audios, nextAudios);
    final loadingChanged = _isLoading != nextIsLoading;
    final playingChanged = _playingIndex != nextPlayingIndex;

    if (listChanged || loadingChanged || playingChanged) {
      setState(() {
        _audios = nextAudios;
        _isLoading = nextIsLoading;
        _playingIndex = nextPlayingIndex;
      });
    }
  }

  void _syncFromController(AudioLibraryController controller) {
    _audios = controller.audios;
    _isLoading = controller.isBootstrapping || controller.isRefreshing;
    _playingIndex = controller.playingIndex;
  }

  bool _hasAudioContentChanged(
    List<SoundpadAudio> current,
    List<SoundpadAudio> next,
  ) {
    if (identical(current, next)) {
      return false;
    }
    if (current.length != next.length) {
      return true;
    }

    for (int i = 0; i < current.length; i++) {
      final left = current[i];
      final right = next[i];
      if (left.index != right.index ||
          left.name != right.name ||
          left.imageBase64 != right.imageBase64) {
        return true;
      }
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return AudioGrid(
      audios: _audios,
      isLoading: _isLoading,
      playingIndex: _playingIndex,
      onPlay: widget.controller.playAudio,
      onEdit: (audio, action) {
        if (action == AudioEditAction.changeImage) {
          unawaited(widget.controller.addOrChangeImage(audio));
        } else if (action == AudioEditAction.removeImage) {
          unawaited(widget.controller.removeImage(audio));
        } else {
          unawaited(_confirmAndDeleteAudio(audio));
        }
      },
    );
  }

  Future<void> _confirmAndDeleteAudio(SoundpadAudio audio) async {
    final l10n = AppLocalizations.of(context);

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.deleteAudioTitle),
          content: Text(l10n.deleteAudioConfirmation(audio.name)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.delete),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      await widget.controller.deleteAudioFromSoundpadDeck(audio);
    }
  }
}
