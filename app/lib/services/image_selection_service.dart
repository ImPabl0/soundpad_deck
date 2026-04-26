import 'dart:convert';

import 'package:file_picker/file_picker.dart';

class ImageSelectionService {
  const ImageSelectionService();

  Future<String?> pickImageAsBase64() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final bytes = result.files.single.bytes;
    if (bytes == null || bytes.isEmpty) {
      return null;
    }

    return base64Encode(bytes);
  }
}
