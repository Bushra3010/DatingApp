import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// Picks a photo from the device and returns its bytes, or null if the
/// person cancelled. A top-level variable (not a class) so tests can swap in
/// a fake without touching platform channels — production code always calls
/// through [pickPhotoBytes] rather than constructing [ImagePicker] directly.
PhotoPicker pickPhotoBytes = _pickFromGallery;

typedef PhotoPicker = Future<Uint8List?> Function();

Future<Uint8List?> _pickFromGallery() async {
  final file = await ImagePicker()
      .pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1600);
  if (file == null) return null;
  return file.readAsBytes();
}
