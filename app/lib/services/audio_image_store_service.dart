import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AudioImageStoreService {
  const AudioImageStoreService();

  static const String _storageKey = 'soundpad_deck_audio_images_v1';

  Future<Map<int, String>> loadHostImages(String host) async {
    final rawMap = await _loadRawMap();
    final result = <int, String>{};

    for (final entry in rawMap.entries) {
      final parts = entry.key.split('#');
      if (parts.length != 2 || parts.first != host) {
        continue;
      }
      final index = int.tryParse(parts.last);
      if (index != null) {
        result[index] = entry.value;
      }
    }

    return result;
  }

  Future<void> setImage(String host, int index, String imageBase64) async {
    final rawMap = await _loadRawMap();
    rawMap['$host#$index'] = imageBase64;
    await _saveRawMap(rawMap);
  }

  Future<void> removeImage(String host, int index) async {
    final rawMap = await _loadRawMap();
    rawMap.remove('$host#$index');
    await _saveRawMap(rawMap);
  }

  Future<Map<String, String>> _loadRawMap() async {
    final prefs = await SharedPreferences.getInstance();
    final rawJson = prefs.getString(_storageKey);
    if (rawJson == null || rawJson.isEmpty) {
      return <String, String>{};
    }

    final dynamic decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) {
      return <String, String>{};
    }

    return decoded.map((key, value) => MapEntry('$key', '$value'));
  }

  Future<void> _saveRawMap(Map<String, String> rawMap) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(rawMap));
  }
}
