import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/soundpad_audio.dart';

class SoundpadApiException implements Exception {
  const SoundpadApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SoundpadApiService {
  const SoundpadApiService({
    this.port = 1209,
    this.defaultTimeout = const Duration(seconds: 2),
  });

  final int port;
  final Duration defaultTimeout;

  Uri _uri(String host, String path, [Map<String, dynamic>? query]) {
    final queryString = query?.map((key, value) => MapEntry(key, '$value'));
    return Uri.http('$host:$port', path, queryString);
  }

  Future<bool> isHealthy(String host, {Duration? timeout}) async {
    try {
      final response = await http
          .get(_uri(host, '/health'))
          .timeout(timeout ?? defaultTimeout);
      if (response.statusCode != 200) {
        return false;
      }
      final dynamic body = jsonDecode(response.body);
      return body is Map<String, dynamic> && body['status'] == 'ok';
    } catch (_) {
      return false;
    }
  }

  Future<List<SoundpadAudio>> listSounds(
    String host, {
    Duration? timeout,
  }) async {
    final response = await http
        .get(_uri(host, '/list'))
        .timeout(timeout ?? defaultTimeout);

    if (response.statusCode != 200) {
      throw SoundpadApiException(
        'Failed to list audios (HTTP ${response.statusCode}).',
      );
    }

    final dynamic body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw const SoundpadApiException('Invalid list response.');
    }

    final dynamic soundsRaw = body['sounds'];
    if (soundsRaw is! List) {
      return const [];
    }

    return soundsRaw
        .whereType<Map<String, dynamic>>()
        .map(SoundpadAudio.fromJson)
        .where((audio) => audio.index >= 0)
        .toList(growable: false);
  }

  Future<void> playSound(String host, int index, {Duration? timeout}) async {
    final response = await http
        .post(
          _uri(host, '/play'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'index': index}),
        )
        .timeout(timeout ?? defaultTimeout);

    _throwIfRequestFailed(response, 'Failed to play audio');
  }

  Future<void> pauseSound(String host, {Duration? timeout}) async {
    final response = await http
        .post(_uri(host, '/pause'))
        .timeout(timeout ?? defaultTimeout);

    _throwIfRequestFailed(response, 'Failed to pause audio');
  }

  Future<void> stopSound(String host, {Duration? timeout}) async {
    final response = await http
        .post(_uri(host, '/stop'))
        .timeout(timeout ?? defaultTimeout);

    _throwIfRequestFailed(response, 'Failed to stop audio');
  }

  Future<void> uploadAudio(
    String host, {
    required String fileName,
    required List<int> bytes,
    Duration? timeout,
  }) async {
    final request = http.MultipartRequest('POST', _uri(host, '/upload'));
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: fileName),
    );

    final streamed = await request.send().timeout(timeout ?? defaultTimeout);
    final response = await http.Response.fromStream(streamed);

    _throwIfRequestFailed(response, 'Failed to upload audio');
  }

  Future<void> deleteAudio(
    String host, {
    required int index,
    Duration? timeout,
  }) async {
    final response = await http
        .post(
          _uri(host, '/delete'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'index': index}),
        )
        .timeout(timeout ?? defaultTimeout);

    _throwIfRequestFailed(response, 'Failed to delete audio');
  }

  void _throwIfRequestFailed(http.Response response, String fallbackPrefix) {
    if (response.statusCode == 200) {
      return;
    }

    String message = '$fallbackPrefix (HTTP ${response.statusCode}).';
    try {
      final dynamic body = jsonDecode(response.body);
      if (body is Map<String, dynamic> && body['message'] != null) {
        message = '${body['message']}';
      }
    } catch (_) {
      // keep fallback message
    }

    throw SoundpadApiException(message);
  }
}
