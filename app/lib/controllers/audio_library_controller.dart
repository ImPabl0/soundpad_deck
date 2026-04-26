import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/soundpad_audio.dart';
import '../services/audio_selection_service.dart';
import '../services/audio_image_store_service.dart';
import '../services/image_selection_service.dart';
import '../services/network_discovery_service.dart';
import '../services/soundpad_api_service.dart';

class AudioLibraryController extends ChangeNotifier {
  AudioLibraryController({
    required SoundpadApiService apiService,
    required NetworkDiscoveryService discoveryService,
    required AudioImageStoreService imageStoreService,
    required AudioSelectionService audioSelectionService,
    required ImageSelectionService imageSelectionService,
    this.enableAutoRefresh = true,
  }) : _apiService = apiService,
       _discoveryService = discoveryService,
       _imageStoreService = imageStoreService,
       _audioSelectionService = audioSelectionService,
       _imageSelectionService = imageSelectionService;

  final SoundpadApiService _apiService;
  final NetworkDiscoveryService _discoveryService;
  final AudioImageStoreService _imageStoreService;
  final AudioSelectionService _audioSelectionService;
  final ImageSelectionService _imageSelectionService;
  final bool enableAutoRefresh;

  Timer? _refreshTimer;
  bool _initialized = false;

  bool isBootstrapping = true;
  bool isDiscovering = false;
  bool isRefreshing = false;
  bool isPlaybackActionInProgress = false;
  bool isUploadInProgress = false;

  String connectionStatus = 'Disconnected';
  String? connectedHost;
  List<String> discoveredHosts = const [];
  List<SoundpadAudio> audios = const [];

  String? lastError;
  int? playingIndex;

  String? get playingAudioName {
    final index = playingIndex;
    if (index == null) {
      return null;
    }

    for (final audio in audios) {
      if (audio.index == index) {
        return audio.name;
      }
    }

    return null;
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _initialized = true;
    await reconnect();

    if (enableAutoRefresh) {
      _refreshTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => unawaited(refreshSounds(silent: true)),
      );
    }
  }

  Future<void> reconnect() async {
    isDiscovering = true;
    isRefreshing = false;
    lastError = null;
    connectionStatus = 'Searching for API on the network...';
    notifyListeners();

    try {
      final hosts = await _discoveryService.discoverHosts();
      discoveredHosts = hosts;

      if (hosts.isEmpty) {
        connectedHost = null;
        audios = const [];
        connectionStatus = 'No instance found';
        return;
      }

      final previousHost = connectedHost;
      connectedHost = hosts.contains(previousHost) ? previousHost : hosts.first;
      connectionStatus = 'Connected to $connectedHost';
      await refreshSounds();
    } catch (error) {
      connectedHost = null;
      audios = const [];
      connectionStatus = 'Discovery failed';
      lastError = '$error';
    } finally {
      isBootstrapping = false;
      isDiscovering = false;
      notifyListeners();
    }
  }

  Future<void> refreshSounds({bool silent = false}) async {
    final host = connectedHost;
    if (host == null) {
      return;
    }

    if (!silent) {
      isRefreshing = true;
      notifyListeners();
    }

    try {
      final fetched = await _apiService.listSounds(host);
      final images = await _imageStoreService.loadHostImages(host);

      audios = fetched
          .map((audio) => audio.copyWith(imageBase64: images[audio.index]))
          .toList(growable: false);
      connectionStatus = 'Connected to $host';
      lastError = null;
    } catch (error) {
      lastError = '$error';
      connectionStatus = 'Unstable connection on $host';
    } finally {
      if (!silent) {
        isRefreshing = false;
      }
      notifyListeners();
    }
  }

  Future<void> playAudio(SoundpadAudio audio) async {
    final host = connectedHost;
    if (host == null) {
      return;
    }

    isPlaybackActionInProgress = true;
    playingIndex = audio.index;
    notifyListeners();

    try {
      await _apiService.playSound(host, audio.index);
      lastError = null;
      connectionStatus = 'Playing: ${audio.name}';
    } catch (error) {
      lastError = '$error';
      connectionStatus = 'Failed to play audio';
    } finally {
      isPlaybackActionInProgress = false;
      notifyListeners();
    }
  }

  Future<void> pausePlayback() async {
    final host = connectedHost;
    if (host == null) {
      return;
    }

    isPlaybackActionInProgress = true;
    notifyListeners();

    try {
      await _apiService.pauseSound(host);
      lastError = null;
      connectionStatus = 'Audio paused';
    } catch (error) {
      lastError = '$error';
      connectionStatus = 'Failed to pause audio';
    } finally {
      isPlaybackActionInProgress = false;
      notifyListeners();
    }
  }

  Future<void> resumePlayback() async {
    final host = connectedHost;
    final index = playingIndex;
    if (host == null || index == null) {
      return;
    }

    isPlaybackActionInProgress = true;
    notifyListeners();

    try {
      await _apiService.playSound(host, index);
      final playingName = playingAudioName ?? 'Audio #$index';
      lastError = null;
      connectionStatus = 'Playing: $playingName';
    } catch (error) {
      lastError = '$error';
      connectionStatus = 'Failed to resume audio';
    } finally {
      isPlaybackActionInProgress = false;
      notifyListeners();
    }
  }

  Future<void> stopPlayback() async {
    final host = connectedHost;
    if (host == null) {
      return;
    }

    isPlaybackActionInProgress = true;
    notifyListeners();

    try {
      await _apiService.stopSound(host);
      playingIndex = null;
      lastError = null;
      connectionStatus = 'Playback stopped';
    } catch (error) {
      lastError = '$error';
      connectionStatus = 'Failed to stop audio';
    } finally {
      isPlaybackActionInProgress = false;
      notifyListeners();
    }
  }

  Future<void> addAudioToSoundpadDeck() async {
    final pickedAudio = await _audioSelectionService.pickAudio();
    if (pickedAudio == null) {
      return;
    }

    await uploadSelectedAudio(pickedAudio);
  }

  Future<PickedAudioFile?> pickAudioForUpload() {
    return _audioSelectionService.pickAudio();
  }

  Future<void> uploadSelectedAudio(PickedAudioFile pickedAudio) async {
    final host = connectedHost;
    if (host == null) {
      return;
    }

    isUploadInProgress = true;
    lastError = null;
    connectionStatus = 'Uploading audio to Soundpad Deck...';
    notifyListeners();

    try {
      await _apiService.uploadAudio(
        host,
        fileName: pickedAudio.name,
        bytes: pickedAudio.bytes,
      );
      connectionStatus = 'Audio added: ${pickedAudio.name}';
      await refreshSounds(silent: true);
    } catch (error) {
      lastError = '$error';
      connectionStatus = 'Failed to add audio';
    } finally {
      isUploadInProgress = false;
      notifyListeners();
    }
  }

  Future<void> deleteAudioFromSoundpadDeck(SoundpadAudio audio) async {
    final host = connectedHost;
    if (host == null) {
      return;
    }

    lastError = null;
    connectionStatus = 'Deleting audio: ${audio.name}';
    notifyListeners();

    try {
      await _apiService.deleteAudio(host, index: audio.index);
      await _imageStoreService.removeImage(host, audio.index);
      connectionStatus = 'Audio deleted: ${audio.name}';
      await refreshSounds(silent: true);
    } catch (error) {
      lastError = '$error';
      connectionStatus = 'Failed to delete audio';
    } finally {
      notifyListeners();
    }
  }

  Future<void> addOrChangeImage(SoundpadAudio audio) async {
    final host = connectedHost;
    if (host == null) {
      return;
    }

    final imageBase64 = await _imageSelectionService.pickImageAsBase64();
    if (imageBase64 == null) {
      return;
    }

    await _imageStoreService.setImage(host, audio.index, imageBase64);
    _replaceAudioImage(audio.index, imageBase64);
  }

  Future<void> removeImage(SoundpadAudio audio) async {
    final host = connectedHost;
    if (host == null) {
      return;
    }

    await _imageStoreService.removeImage(host, audio.index);
    _replaceAudioImage(audio.index, null);
  }

  void _replaceAudioImage(int audioIndex, String? imageBase64) {
    audios = audios
        .map(
          (audio) => audio.index == audioIndex
              ? audio.copyWith(
                  imageBase64: imageBase64,
                  clearImage: imageBase64 == null,
                )
              : audio,
        )
        .toList(growable: false);
    notifyListeners();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
