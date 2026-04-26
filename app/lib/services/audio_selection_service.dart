import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

class PickedAudioFile {
  const PickedAudioFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

class AudioSelectionService {
  const AudioSelectionService();

  Future<PickedAudioFile?> pickAudio() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'mp3',
        'wav',
        'ogg',
        'flac',
        'm4a',
        'aac',
        'opus',
        'wma',
      ],
      allowMultiple: false,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      return null;
    }

    final name = file.name.trim().isEmpty ? 'uploaded_audio.bin' : file.name;
    return PickedAudioFile(name: name, bytes: bytes);
  }
}
