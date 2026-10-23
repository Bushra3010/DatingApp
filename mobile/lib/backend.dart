import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Talks to Supabase for the signed-in member's own account, profile row and
/// photos. Discovery, likes and chat still run on the in-memory demo data.
///
/// The app runs without one (tests, or Supabase unreachable) and then keeps
/// everything in memory, as the preview always did.
class ProfileBackend {
  ProfileBackend(this.client);
  final SupabaseClient client;

  static const _bucket = 'photos';

  User? get user => client.auth.currentUser;
  bool get signedIn => user != null;

  Future<void> signUp(String email, String password) async {
    final res = await client.auth.signUp(email: email, password: password);
    // With email confirmation on, Supabase creates the user but no session.
    if (res.session == null) {
      throw const AuthException(
          'Check your inbox to confirm your email, then log in.');
    }
  }

  Future<void> logIn(String email, String password) =>
      client.auth.signInWithPassword(email: email, password: password);

  Future<void> logOut() => client.auth.signOut();

  Future<Map<String, dynamic>?> loadProfile() =>
      client.from('profiles').select().eq('id', user!.id).maybeSingle();

  Future<void> saveProfile(Map<String, dynamic> row) =>
      client.from('profiles').upsert({
        ...row,
        'id': user!.id,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

  /// Uploads into the member's own folder and returns the storage path.
  Future<String> uploadPhoto(Uint8List bytes) async {
    final (ext, mime) = _imageType(bytes);
    final path = '${user!.id}/${DateTime.now().microsecondsSinceEpoch}.$ext';
    await client.storage.from(_bucket).uploadBinary(path, bytes,
        fileOptions: FileOptions(contentType: mime));
    return path;
  }

  Future<Uint8List> downloadPhoto(String path) =>
      client.storage.from(_bucket).download(path);

  Future<void> deletePhoto(String path) =>
      client.storage.from(_bucket).remove([path]);

  /// Sniffs the file signature; picked photos don't carry a reliable name.
  static (String, String) _imageType(Uint8List b) {
    bool at(int i, List<int> sig) =>
        b.length >= i + sig.length &&
        [for (var j = 0; j < sig.length; j++) b[i + j]].join(',') ==
            sig.join(',');
    if (at(0, [0x89, 0x50, 0x4E, 0x47])) return ('png', 'image/png');
    if (at(0, [0x47, 0x49, 0x46])) return ('gif', 'image/gif');
    if (at(0, [0x52, 0x49, 0x46, 0x46]) && at(8, [0x57, 0x45, 0x42, 0x50])) {
      return ('webp', 'image/webp');
    }
    if (at(4, [0x66, 0x74, 0x79, 0x70])) return ('heic', 'image/heic');
    return ('jpg', 'image/jpeg');
  }
}
