class SoundpadAudio {
  const SoundpadAudio({
    required this.index,
    required this.name,
    this.imageBase64,
  });

  final int index;
  final String name;
  final String? imageBase64;

  factory SoundpadAudio.fromJson(Map<String, dynamic> json) {
    final dynamic indexRaw = json['index'];
    final dynamic nameRaw = json['name'];

    return SoundpadAudio(
      index: indexRaw is int ? indexRaw : int.tryParse('$indexRaw') ?? -1,
      name: '$nameRaw'.trim().isEmpty ? 'Unnamed audio' : '$nameRaw',
    );
  }

  SoundpadAudio copyWith({
    int? index,
    String? name,
    String? imageBase64,
    bool clearImage = false,
  }) {
    return SoundpadAudio(
      index: index ?? this.index,
      name: name ?? this.name,
      imageBase64: clearImage ? null : imageBase64 ?? this.imageBase64,
    );
  }
}
