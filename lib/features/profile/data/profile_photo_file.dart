import 'dart:typed_data';

class ProfilePhotoFile {
  final Uint8List bytes;
  final String filename;

  const ProfilePhotoFile({
    required this.bytes,
    this.filename = 'profile.jpg',
  });
}
